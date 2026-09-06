"""State capture for gen_config --incremental; never decides build cleans."""

import difflib
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile


def command(args, optional=False, capture=False):
    result = subprocess.run(args, stdout=subprocess.PIPE if capture else None, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    if result.returncode:
        if optional:
            return None
        raise RuntimeError(f"Command failed: {args}")
    return os.fsdecode(result.stdout) if capture else ""


def git(path, *args, optional=False):
    return command(["git", "-C", str(path), *args], optional=optional, capture=True)


def paths_diff(path, old, new):
    if old is None or new is None:
        return None
    if old == new:
        return []
    value = git(path, "diff", "--no-renames", "--name-only", "-z", old, new, "--", optional=True)
    return value.rstrip("\0").split("\0") if value else ([] if value == "" else None)


def feed_snapshot():
    if not Path("feeds.conf").exists():
        return {}
    result = {}
    for line in command(["./scripts/feeds", "list", "-s", "-d", "\t"], capture=True).splitlines():
        name, method, sha, source = line.split("\t", 3)
        if not re.fullmatch(r"\w+", name, flags=re.ASCII):
            raise RuntimeError(f"Invalid feed name: {name}")
        result[name] = {"method": method, "source": source, "sha": sha if re.fullmatch(r"[0-9a-f]{40}", sha) else None}
    return result


def remove(path):
    path = Path(path)
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.exists():
        shutil.rmtree(path)


def refresh_metadata():
    # Only scan products; preserve tmp downloads, locks and staging work.
    remove("tmp/info")
    for pattern in (".packageinfo*", ".targetinfo*", ".config-*.in"):
        for path in Path("tmp").glob(pattern):
            remove(path)


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", prefix=path.name + ".", dir=path.parent, delete=False) as output:
        temporary = Path(output.name)
        output.write(json.dumps(value, indent=2, sort_keys=True) + "\n")
        output.flush()
        os.fsync(output.fileno())
    temporary.replace(path)
    directory = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(directory)
    finally:
        os.close(directory)


class IncrementalSetup:
    def __init__(self):
        self.plan_file = Path("logs/incremental-plan.json")
        self.state_file = Path(".genconfig-state/genconfig-state.json")
        self.plan_file.unlink(missing_ok=True)  # An old success must not survive failure.
        self.failed_file = Path(".genconfig-state/incremental-plan.failed")
        if self.failed_file.exists():
            raise RuntimeError("Previous setup incomplete; discard this copy and use a fresh tree")
        atomic_json(self.failed_file, {"in_progress": True})
        self.previous = json.loads(self.state_file.read_text()) if self.state_file.exists() else {}
        self.old_config = Path(".config").read_text() if Path(".config").exists() else ""
        self.old_feeds = feed_snapshot()
        self.old_root = os.getenv("GENCONFIG_BASE_REV") or self.previous.get("root")
        self.new_root = git(".", "rev-parse", "HEAD").strip()
        self.root_paths = paths_diff(".", self.old_root, self.new_root)
        records = iter(git(".", "status", "--porcelain", "-uall", "-z").split("\0"))
        dirty = set()
        for record in records:
            if record:
                dirty.add(record[3:])
                if "R" in record[:2] or "C" in record[:2]:
                    dirty.add(next(records))
        # Only the exact CI mirror rewrite is exempt, not arbitrary local edits.
        default = Path("feeds.conf.default")
        original = git(".", "show", "HEAD:feeds.conf.default", optional=True)
        if original is not None and default.exists() and default.read_text() == re.sub(
                r"git.openwrt.org/(feed|project)", "github.com/openwrt", original):
            dirty.discard("feeds.conf.default")
        self.dirty_paths = sorted(dirty)
        dirty_directories = any(Path(p).is_dir() and not Path(p).is_symlink() for p in dirty)
        digest = hashlib.sha256()
        for name in self.dirty_paths:
            path = Path(name)
            digest.update(os.fsencode(name))
            digest.update(os.fsencode(os.readlink(path)) if path.is_symlink() else
                          path.read_bytes() if path.is_file() else b"directory" if path.is_dir() else b"deleted")
        self.dirty_digest = digest.hexdigest()
        self.unverified = not self.previous or dirty_directories
        self.metadata_changed = self.unverified or (self.previous.get("root") != self.new_root or
                                 self.previous.get("dirty_digest") != self.dirty_digest)
        # Adopt known legacy methods before feeds.conf is replaced. The updater
        # independently checks the actual origin URL and replaces dirty Git trees.
        for name, old in self.old_feeds.items():
            directory = Path("feeds") / f"{name}.tmp"
            if directory.is_dir():
                marker = directory / "incremental-method"
                if not marker.exists():
                    marker.write_text(old["method"] + "\n")
        Path(".config").unlink(missing_ok=True)
        command(["./scripts/feeds", "uninstall", "-a"])
        remove("target/linux/feeds")  # uninstall -a skips this directory.
        refresh_metadata()

    def update(self):
        desired = feed_snapshot()
        for name in self.old_feeds.keys() - desired.keys():
            print(f"Incremental feed {name}: removed from configuration")
            for suffix in ("", ".tmp", ".index", ".targetindex"):
                remove(Path("feeds") / (name + suffix))
        command(["./scripts/feeds", "update", "-k"])
        # Shared root make logic can change feed metadata without feed changes.
        if self.metadata_changed:
            command(["./scripts/feeds", "update", "-i"])

    def finish(self):
        new_feeds = feed_snapshot()
        feeds = []
        for name in sorted(self.old_feeds.keys() | new_feeds.keys()):
            old, new = self.old_feeds.get(name), new_feeds.get(name)
            changed = paths_diff(Path("feeds") / name, old and old["sha"], new and new["sha"])
            # Same SHA alone cannot prove equivalence for non-Git/method changes.
            incompatible = not old or not new or old["method"] != new["method"]
            if old and new:
                incompatible |= old["method"] not in ("src-git", "src-git-full")
                incompatible |= re.split(r"[;^]", old["source"])[0] != re.split(r"[;^]", new["source"])[0]
            if old and new and old["sha"] and new["sha"] and old["sha"] != new["sha"]:
                raw = git(Path("feeds") / name, "diff", "--raw", "--no-renames",
                          old["sha"], new["sha"], "--", optional=True)
                incompatible |= raw is None or bool(re.search(r"^:(?:160000 |[0-9]+ 160000 )", raw or "", re.M))
            reset_file = Path("feeds") / f"{name}.tmp/incremental-reset"
            reset_reason = reset_file.read_text().strip() if new and reset_file.exists() else None
            feeds.append({"reset_reason": reset_reason, "name": name, "old": old, "new": new, "changed_paths": changed,
                          "requires_full_rebuild": incompatible or changed is None})
        config = Path(".config").read_text()
        plan = {"schema": 1, "phase": "setup-complete", "root": {
                    "old_sha": self.old_root, "new_sha": self.new_root,
                    "changed_paths": self.root_paths, "dirty_paths": self.dirty_paths},
                "feeds": feeds, "config": {"old": self.old_config, "new": config,
                    "diff": list(difflib.unified_diff(self.old_config.splitlines(), config.splitlines(),
                                                     fromfile="previous.config", tofile="generated.config", lineterm=""))},
                "requires_full_rebuild": self.unverified or self.root_paths is None or any(f["requires_full_rebuild"] for f in feeds)}
        atomic_json(self.plan_file, plan)
        for name, feed in new_feeds.items():
            if feed["method"] in ("src-git", "src-git-full"):
                git(Path("feeds") / name, "update-ref", "-d", f"refs/genconfig/prev/{name}")
        atomic_json(self.state_file, {"root": self.new_root, "dirty_digest": self.dirty_digest})
        self.failed_file.unlink()
