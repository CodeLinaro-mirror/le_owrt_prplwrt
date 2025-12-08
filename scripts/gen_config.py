#!/usr/bin/env python3

import yaml
from pathlib import Path
from shutil import rmtree
import io
import re
import sys
from subprocess import run
from os import getenv
from typing import Set

sys.stdout = io.TextIOWrapper(open(sys.stdout.fileno(), "wb", 0), write_through=True)
profile_folders = getenv("GENCONFIG_PROFILE_DIRS", "./profiles")


def run_cmd(cmd: list):
    if getenv("GENCONFIG_VERBOSE"):
        print('run_cmd: "' + " ".join(cmd) + '"')
    return run(cmd)


def die(*messages: str) -> None:
    """Prints each message on a new line and exits the program."""
    for message in messages:
        print(message)
    quit(1)


def usage(code: int = 0):
    """Print script usage

    Args:
        code (int): exit code
    """
    print(
        f"""Usage: {sys.argv[0]} <profile> [options...]

    clean           Cleanup feeds related parts in the tree and exit.
    list            List available profiles"""
    )
    quit(code)


def load_yaml(fname: str, profile: dict, seen: Set[str]):

    if fname in seen:
        return (profile, seen)

    # Allow profile overriding by searching in reverse order
    for folder in profile_folders.split(':')[::-1]:
        profile_file = (Path(folder) / fname).with_suffix(".yml")

        if not profile_file.is_file():
            continue
        includes = []
        new = yaml.safe_load(profile_file.read_text())
        for n in new:
            if n in {"target", "subtarget", "external_target"}:
                if profile.get(n):
                    die(f"Duplicate tag found {n}")
                profile.update({n: new.get(n)})
            elif n in {"description"}:
                profile["description"].append(new.get(n))
            elif n in {"packages"}:
                profile["packages"].extend(new.get(n))
            elif n in {"profiles"}:
                profile["profiles"].extend(new.get(n))
            elif n in {"diffconfig"}:
                profile["diffconfig"] += new.get(n)
            elif n in {"feeds"}:
                for f in new.get(n):
                    if f.get("name", "") == "" or f.get("uri", "") == "":
                        die(f"Found bad feed {f}")
                    profile["feeds"][f.get("name")] = f
            elif n in {"additional_packages"}:
                for f in new.get(n):
                    if not f.get("feed") or not f.get("packages"):
                        die(f"Found bad additional_packages {f}")
                profile["additional_packages"].extend(new.get(n))
            elif n in {"include"}:
                includes = new.get(n)
            elif n in {"packages_remove"}:
                profile["packages_remove"].extend(new.get(n))

        seen.add(fname);

        for inc in includes:
            (profile, seen) = load_yaml(inc, profile, seen)

        return (profile, seen)

    if not profile_file.is_file():
        die(f"Profile {fname} not found")

def load_yaml_list(fnames: [str], profile: dict):
    seen = set()
    for fn in fnames:
        (profile, seen) = load_yaml(fn, profile, seen)
    return profile

def extract_sha1_from_revision(revision: str) -> str:
    """
    Validates the given revision string and extracts the SHA-1 hash.

    A valid revision can be:

     1. A full 40-character Git SHA-1 hash.
     2. A human readable reference like Git tag followed by '@' and a full 40-character Git SHA-1 hash.

    :param revision: The revision string to validate and extract the SHA-1 hash from.
    :return: The extracted SHA-1 hash if valid, otherwise None.
    """

    full_sha1_pattern = r"^[a-f0-9]{40}$"
    tag_full_sha1_pattern = r"^[^@]+@([a-f0-9]{40})$"

    if re.match(full_sha1_pattern, revision):
        return revision
    elif re.match(tag_full_sha1_pattern, revision):
        return re.match(tag_full_sha1_pattern, revision).group(1)
    else:
        return None


def handle_feed_revision(profile_feed: dict, feeds: list):
    method = profile_feed.get("method", "src-git")
    f = f'{method},{profile_feed["name"]},{profile_feed["uri"]}'

    if method.startswith('src-git'):
        revision = profile_feed.get("revision")
        if not revision:
            die(f"Please specify `revision` for the following feed: {profile_feed}")

        sha1 = extract_sha1_from_revision(revision)
        if not sha1:
            die(
                f"Invalid feed revision {revision} in {profile_feed} feed, valid `revision` is:",
                " 1. A full 40-character Git SHA-1 hash.",
                " 2. A human readable reference like Git tag followed by '@' and a full 40-character Git SHA-1 hash.",
            )
        f += f'^{sha1}'

    feeds.append(f)


if "list" in sys.argv:
    for folder in profile_folders.split(':')[::-1]:
        print(f"Profiles in {folder}")

        print("\n".join(map(lambda p: str(p.stem), Path(folder).glob("*.yml"))))
    quit(0)

if "help" in sys.argv:
    usage()

if len(sys.argv) < 2:
    usage(1)

rmtree("./tmp", ignore_errors=True)
rmtree("./package/feeds/", ignore_errors=True)
rmtree("./feeds", ignore_errors=True)
rmtree("./tmp", ignore_errors=True)
if Path("./feeds.conf").is_file():
    Path("./feeds.conf").unlink()
if Path("./.config").is_file():
    Path("./.config").unlink()

if "clean" in sys.argv:
    print("Tree is now clean")
    quit(0)

profile = {
    "additional_packages": [],
    "description": [],
    "diffconfig": "",
    "feeds": {},
    "packages": [],
    "profiles": [],
    "packages_remove": [],
}

profile = load_yaml_list(sys.argv[1:], profile)


if getenv("GENCONFIG_VERBOSE"):
    print(yaml.dump(profile))

for d in profile.get("description"):
    print(d)

feeds_conf = Path("feeds.conf")
if feeds_conf.is_file():
    feeds_conf.unlink()

feeds = []

for p in profile.get("feeds", []):
    try:
        profile_feeds = profile["feeds"].get(p)
        handle_feed_revision(profile_feeds, feeds)
    except:
        print(f"Badly configured feed: {profile_feeds}")
        quit(1)

with open("feeds.conf.default", "r") as default_feeds:
    for line in default_feeds:
        feed = line.rstrip()
        print(f"Adding default feed '{feed}'")
        feeds.append(feed.replace(" ", ","))

if run_cmd(["./scripts/feeds", "setup", *feeds]).returncode:
    die(f"Error setting up feeds")

if run_cmd(["./scripts/feeds", "update"]).returncode:
    die(f"Error updating feeds")

for p in profile.get("feeds", []):
    f = profile["feeds"].get(p)
    if run_cmd(
        ["./scripts/feeds", "install", "-a", "-f", "-p", f.get("name")]
    ).returncode:
        die(f"Error installing {feed}")

for ap in profile.get("additional_packages"):
    feed = ap["feed"]
    # "install -f -p feed package" will override only base package and would not override package from other feed without uninstall
    run_cmd(["./scripts/feeds", "uninstall", *ap["packages"]])
    if run_cmd(
        ["./scripts/feeds", "install", "-f", "-p", feed, *ap["packages"]]
    ).returncode:
        packages_install = " ".join(ap["packages"])
        die(f"Error installing additional packages {packages_install} from {feed} feed")

if profile.get("external_target", False):
    if run_cmd(["./scripts/feeds", "install", "-f", profile["target"]]).returncode:
        die(f"Error installing external target {profile['target']}")

config_output = f"""CONFIG_TARGET_{profile["target"]}=y
CONFIG_TARGET_{profile["target"]}_{profile["subtarget"]}=y\n"""
profiles = profile.get("profiles")
if len(profiles) > 1:
    config_output += f"CONFIG_TARGET_MULTI_PROFILE=y\n"
    for p in profiles:
        config_output += f"""CONFIG_TARGET_DEVICE_{profile["target"]}_{profile["subtarget"]}_DEVICE_{p}=y\n"""
else:
    config_output += f"""CONFIG_TARGET_{profile["target"]}_{profile["subtarget"]}_DEVICE_{profiles[0]}=y\n"""

for package in profile.get("packages", []):
    print(f"Add package to .config: {package}")
    config_output += f"CONFIG_PACKAGE_{package}=y\n"

for ap in profile.get("additional_packages"):
    for package in ap["packages"]:
        print(f"Add additional package to .config: {package}")
        config_output += f"CONFIG_PACKAGE_{package}=y\n"

config_output += f"{profile.get('diffconfig', '')}"

for package in profile.get("packages_remove", []):
    print(f"Remove package from .config: {package}")
    config_output += f"# CONFIG_PACKAGE_{package} is not set\n"

Path(".config").write_text(config_output)
print("Configuration written to .config")

if getenv("GENCONFIG_VERBOSE"):
    print(config_output)

rmtree("./tmp", ignore_errors=True)
print("Running make defconfig")
if run_cmd(["make", "defconfig"]).returncode:
    die(f"Error running make defconfig")
