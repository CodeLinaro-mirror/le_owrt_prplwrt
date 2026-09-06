#!/usr/bin/env python3
"""Conservative persistent-build planning and per-job evidence."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def git(directory, *args):
    return subprocess.check_output(['git', '-C', str(directory), *args], text=True).strip()


def load(path, default=None):
    return json.loads(Path(path).read_text()) if Path(path).exists() else default


def write(path, value):
    dest = Path(path)
    temp = dest.with_suffix('.new')
    temp.write_text(json.dumps(value, separators=(',', ':')) + '\n')
    temp.replace(dest)


def config(path):
    return dict(re.findall(r'^(CONFIG_\w+)=(.*)$', Path(path).read_text(), re.M))


def recipe(path):
    if not re.fullmatch(r'[A-Za-z0-9_+./-]+', path) or '..' in Path(path).parts:
        raise ValueError('unsupported package path')
    p = Path(path)
    if not p.is_file() or p.name == 'Makefile' or p.suffix in ('.h', '.hpp', '.mk'):
        raise ValueError('removed recipe, recipe definition, or shared input')
    for parent in p.parents:
        if parent == Path('.'):
            break
        mf = parent / 'Makefile'
        if mf.is_file():
            text = mf.read_text()
            if not re.search(r'include\s+\$\(TOPDIR\)/rules\.mk', text):
                continue
            if 'BuildPackage' not in text or any(x in text for x in ('Build/InstallDev', 'HostBuild', 'KernelPackage')):
                raise ValueError('dependency closure is not established')
            target = str(parent)
            if target.startswith('feeds/'):
                feed = parent.parts[1]
                links = [q for q in Path('package/feeds', feed).glob('*')
                         if q.is_symlink() and q.resolve() == parent.resolve()]
                require(len(links) == 1, 'unselected or ambiguous feed recipe')
                target = str(links[0])
            if not target.startswith('package/'):
                raise ValueError('not a package recipe')
            return target
    raise ValueError('missing package recipe')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def plan():
    try:
        state = load('.persistent-success.json')
        manifest = load('logs/incremental-plan.json')
        require(isinstance(state, dict) and isinstance(state.get('feed_revisions'), dict), 'invalid successful state')
        require(not Path('.genconfig-state/incremental-plan.failed').exists(), 'generator incomplete')
        require(manifest and manifest['schema'] == 1 and (manifest['phase'] == 'setup-complete'), 'unsupported manifest')
        require(not manifest['requires_full_rebuild'], 'reuse proof missing or incompatible')
        require(manifest['root']['old_sha'] == state['sha'], 'reuse proof missing or incompatible')
        require(manifest['root']['new_sha'] == os.environ['CI_COMMIT_SHA'], 'reuse proof missing or incompatible')
        old, new = config('.persistent-config'), config('.config')
        for key in old.keys() | new.keys():
            if old.get(key) != new.get(key):
                # Only additions of leaf package selections are accepted here.
                require(key.startswith('CONFIG_PACKAGE_') and key not in old and (new.get(key) in ('y', 'm')), 'reuse proof missing or incompatible')
        targets = set()
        root = manifest['root']['changed_paths']
        require(isinstance(root, list), 'reuse proof missing or incompatible')
        require(root == git('.', 'diff', '--name-only', '--no-renames', state['sha'], os.environ['CI_COMMIT_SHA']).splitlines(), 'root diff mismatch')
        require(git('.', 'rev-parse', 'HEAD') == os.environ['CI_COMMIT_SHA'], 'root checkout mismatch')
        root = sorted(set(root + manifest['root']['dirty_paths']))
        for path in root:
            if path.startswith('package/'):
                targets.add(recipe(path))
            elif path.startswith('target/linux/'):
                raise ValueError('kernel consumer closure requires fresh build')
            elif path.startswith('profiles/') and path.endswith('.yml'):
                pass
            else:
                raise ValueError('shared or unclassified root input: ' + path)
        for feed in manifest['feeds']:
            require(not feed['requires_full_rebuild'] and isinstance(feed['changed_paths'], list), 'reuse proof missing or incompatible')
            require(state['feed_revisions'].get(feed['name']) == feed['old']['sha'], 'reuse proof missing or incompatible')
            require(re.fullmatch('[A-Za-z0-9_-]+', feed['name']), 'invalid feed name')
            directory = Path('feeds') / feed['name']
            require(git(directory, 'rev-parse', 'HEAD') == feed['new']['sha'], 'feed checkout mismatch')
            require(feed['changed_paths'] == git(directory, 'diff', '--name-only', '--no-renames', feed['old']['sha'], feed['new']['sha']).splitlines(), 'feed diff mismatch')
            for path in feed['changed_paths']:
                targets.add(recipe('feeds/' + feed['name'] + '/' + path))
        print('packages')
        print('\n'.join(sorted(targets)))
    except (AssertionError, KeyError, TypeError, ValueError, OSError, AttributeError, subprocess.CalledProcessError) as exc:
        print('fresh')
        print('Reuse rejected: ' + str(exc), file=sys.stderr)


def evidence(status):
    root = Path('.')
    feeds = {}
    for p in Path('feeds').glob('*'):
        if (p / '.git').exists():
            try:
                feeds[p.name] = git(p, 'rev-parse', 'HEAD')
            except subprocess.CalledProcessError:
                feeds[p.name] = None
    cfg = hashlib.sha256(Path('.config').read_bytes()).hexdigest() if Path('.config').exists() else None
    env = os.environ
    provenance = dict(sha=env['CI_COMMIT_SHA'], feed_revisions=feeds, config_sha256=cfg,
                      builder_digest=env['PRPLOS_BUILDER_IMAGE_DIGEST'], tree_key=env['BUILD_TREE_KEY'],
                      clean_build=env.get('BUILD_CLEAN') == '1', clean_reason=env.get('BUILD_CLEAN_REASON'),
                      profile=env['CI_BUILD_PROFILE'], build_ccache=int(env.get('BUILD_CCACHE', '1')))
    write('logs/build-provenance.json', provenance)
    def counters(path):
        result = {}
        for line in Path(path).read_text().splitlines() if Path(path).exists() else []:
            fields = line.split()
            if len(fields) == 2 and fields[1].isdigit():
                result[fields[0]] = int(fields[1])
        return result
    ccache_enabled = env.get('BUILD_CCACHE', '1') == '1' and env.get('CLEAN_NO_CCACHE', '0') != '1'
    calls = counters('logs/ccache-job.txt') if ccache_enabled else {}
    names = ('direct_cache_hit', 'preprocessed_cache_hit', 'cache_miss')
    delta = [calls[n] for n in names] if all(n in calls for n in names) else []
    usable = len(delta) == 3 and min(delta) >= 0 and ccache_enabled
    timings = dict(line.split() for line in Path('logs/build-timers.txt').read_text().splitlines())
    profile = env['CI_BUILD_PROFILE']
    target = 'Freedom' if profile == 'qca_ipq95xx prpl cellular security thread' else profile.split()[0]
    write('logs/build-metrics.json', dict(schema_version=1, job_id=int(env['CI_JOB_ID']),
          scenario=env.get('BUILD_SCENARIO', 'persistent'), target=target, profile=profile,
          status='metrics-pending', wall_s=None,
          job_elapsed_s=int(env.get('BUILD_JOB_ELAPSED', '0')),
          parent_sha=env.get('BUILD_PARENT_SHA') or None, runner=env.get('CI_RUNNER_DESCRIPTION', 'unknown'),
          make_jobs=int(env.get('BUILD_MAKE_JOBS', '1')), repetition=None,
          tree_reused=env.get('BUILD_TREE_REUSED') == '1', ccache_enabled=ccache_enabled,
          ccache_uncacheable=calls.get('uncacheable') if usable else None,
          clean_actions=([env.get('BUILD_CLEAN_REASON') or 'fresh'] if env.get('BUILD_CLEAN') == '1' else
                         Path('logs/clean-plan.txt').read_text().splitlines()[1:] if Path('logs/clean-plan.txt').exists() else []),
          compile_world_s=int(timings['compile-world']) if 'compile-world' in timings else None,
          ccache_hits=sum(delta[:2]) if usable else None, ccache_misses=delta[2] if usable else None,
          tree_bytes=None, timers_s={k: int(v) for k, v in timings.items()}, **provenance_without_profile(provenance)))
    if status != 0:
        write('.incomplete', dict(sha=env['CI_COMMIT_SHA'], status=status))


def provenance_without_profile(value):
    return {k: v for k, v in value.items() if k not in ('profile', 'clean_reason', 'build_ccache')}


def baseline():
    try:
        state = load('.persistent-success.json')
        if not isinstance(state, dict) or not isinstance(state.get('feed_revisions'), dict):
            return ''
        sha = state['sha']
        return sha if re.fullmatch(r'[a-f0-9]{40,64}', sha) else ''
    except (OSError, ValueError, TypeError, KeyError):
        return ''


if __name__ == '__main__':
    if sys.argv[1] == 'plan':
        plan()
    elif sys.argv[1] == 'commit-success':
        write('.persistent-success.json', load('logs/build-provenance.json'))
        Path('.persistent-config').write_bytes(Path('.config').read_bytes())
        Path('.incomplete').unlink(missing_ok=True)
    elif sys.argv[1] == 'baseline':
        print(baseline())
    else:
        evidence(int(sys.argv[2]))
