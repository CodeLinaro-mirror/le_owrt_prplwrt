#!/usr/bin/env python3
"""Best-effort weekly memory baseline storage in GitLab's generic registry."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import quote


def warning(message):
    print(f'WARNING: memory-footprint registry: {message}', file=sys.stderr)


def key(value):
    """Reversible filename encoding; preserve ordinary branch and board names."""
    if not value:
        raise ValueError('empty registry key')
    return ''.join(chr(byte) if chr(byte).isascii() and
                   (chr(byte).isalnum() or chr(byte) in '.-')
                   else f'_{byte:02x}' for byte in value.encode())


def weekly_package():
    # n8n weekly commits use ci-weekly/<base branch>/YYYY-MM-DD.
    branch = os.environ.get('CI_COMMIT_BRANCH', '')
    if not branch.startswith('ci-weekly/'):
        return None
    base, separator, date = branch[len('ci-weekly/'):].rpartition('/')
    if not separator or not re.fullmatch(r'\d{4}-\d{2}-\d{2}', date):
        raise ValueError('expected ci-weekly/<base branch>/YYYY-MM-DD')
    return 'memory-footprint-' + key(base)


class Registry:
    def __init__(self, project, token, header='JOB-TOKEN'):
        if not token:
            raise ValueError(f'missing {header} credential')
        self.url = (os.environ['CI_API_V4_URL'].rstrip('/') + '/projects/' +
                    quote(project, safe='') + '/packages')
        self.header = f'{header}: {token}'

    def request(self, path, *args):
        # Do not print the command: it contains a token. Bound every request.
        result = subprocess.run(
            ['curl', '--fail', '--silent', '--show-error', '--connect-timeout',
             '10', '--max-time', '30', '--header', self.header, *args,
             self.url + path], capture_output=True)
        if result.returncode:
            raise RuntimeError(f'registry request failed (curl {result.returncode})')
        return result.stdout

    def file_path(self, package, version, filename):
        return '/generic/' + '/'.join(quote(value, safe='')
                                     for value in (package, version, filename))


def push(output, board, suite):
    package = weekly_package()
    if package is None:
        return
    version = os.environ['CI_PIPELINE_ID']
    if not version.isdecimal():
        raise ValueError('CI_PIPELINE_ID must be numeric')
    registry = Registry(os.environ['CI_PROJECT_ID'], os.environ.get('CI_JOB_TOKEN'))
    # Scope the summary too: jobs in one pipeline share a package version.
    files = ['boot.txt.gz', 'final.txt.gz', 'summary.json']
    for filename in files:
        if not (output / filename).is_file():
            raise ValueError(f'cannot upload incomplete baseline: missing {filename}')
    for filename in files:
        path = registry.file_path(package, version, f'{key(board)}-{key(suite)}-{filename}')
        registry.request(path, '--upload-file', str(output / filename))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['push'])
    parser.add_argument('output', type=Path)
    parser.add_argument('board')
    parser.add_argument('suite')
    args = parser.parse_args()
    try:
        push(args.output, args.board, args.suite)
    except (OSError, ValueError, KeyError, RuntimeError) as error:
        warning(str(error))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
