#!/usr/bin/env python3
"""Read-only schedule gate. Deferred is not a package/browser acceptance result."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen

UPSTREAM = 'zaibuyidao/ReaWebAPI'
FORK = 'Psysia/ReaWebAPI'
GRACE_HOURS = 2


def metadata(path, optional=False):
    headers = {'User-Agent': 'PsyReaSFX-schedule-gate', 'Accept': 'application/vnd.github+json'}
    token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    try:
        with urlopen(Request('https://api.github.com/repos/' + path, headers=headers), timeout=60) as response:
            return json.load(response)
    except HTTPError as error:
        if optional and error.code == 404:
            return None
        raise  # Auth, rate limits, outages and malformed responses are not mirror lag.


def inspect(get=metadata, now=None):
    release = get(UPSTREAM + '/releases/latest')
    tag = release['tag_name']
    if not re.fullmatch(r'v\d+(?:\.\d+){2,3}', tag) or release['draft']:
        raise ValueError('Unexpected upstream release')
    published = datetime.fromisoformat(release['published_at'].replace('Z', '+00:00'))
    age = ((now or datetime.now(timezone.utc)) - published).total_seconds()
    commit = get(UPSTREAM + '/commits/' + tag)['sha']
    source = get(UPSTREAM + '/commits/main')['sha']
    if not all(re.fullmatch(r'[a-f0-9]{40}', sha) for sha in (commit, source)):
        raise ValueError('Invalid upstream source commit')
    mirror = get(FORK + '/releases/tags/' + tag, optional=True)
    ready, reason = False, 'mirror release is missing or still draft'
    if mirror and not mirror['draft']:
        if mirror['tag_name'] != tag:
            raise ValueError('Unexpected mirror release tag')
        for name in (f'ReaWebAPI-windows-x64-{tag}.zip', 'reaper_reawebapi-x64.dll'):
            original = [a for a in release['assets'] if a['name'] == name]
            copied = [a for a in mirror['assets'] if a['name'] == name]
            if len(original) != 1 or not re.fullmatch(r'sha256:[a-f0-9]{64}', original[0].get('digest') or ''):
                raise ValueError('Upstream asset is not ready: ' + name)
            if len(copied) != 1 or copied[0].get('digest') != original[0]['digest']:
                raise ValueError('Published fork asset differs from upstream: ' + name)
        for name in ('ReaWebAPI-source.zip', 'mirror-manifest.json'):
            if sum(a['name'] == name for a in mirror['assets']) != 1:
                raise ValueError('Published mirror is incomplete: ' + name)
        if get(FORK + '/commits/' + tag)['sha'] != commit:
            raise ValueError('Fork tag does not match upstream')
        fork_head = get(FORK + '/commits/main')['sha']
        if not re.fullmatch(r'[a-f0-9]{40}', fork_head):
            raise ValueError('Invalid fork source commit')
        ready = fork_head == source or fork_head == get(UPSTREAM + '/commits/main')['sha']
        reason = 'mirror ready' if ready else 'fork source has not caught up'
    # Publication age does not measure how long a later main-branch sync lags.
    # Do not reuse an old tag's age to raise a new source-lag alert.
    missing_release = not mirror or mirror['draft']
    return dict(tag=tag, ready=ready, overdue=missing_release and age >= GRACE_HOURS * 3600, reason=reason)


def decision(state, alerted):
    if state['ready']:
        return 'ready'
    return 'alert' if state['overdue'] and not alerted else 'deferred'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state', type=Path, required=True)
    parser.add_argument('--decide', action='store_true')
    parser.add_argument('--alerted', choices=('true', 'false'), default='false')
    parser.add_argument('--marker', type=Path)
    args = parser.parse_args()
    if not args.decide:
        state = inspect()
        args.state.write_text(json.dumps(state), encoding='utf-8')
        outputs = {'tag': state['tag']}
    else:
        state = json.loads(args.state.read_text(encoding='utf-8'))
        result = decision(state, args.alerted == 'true')
        outputs = {'ready': str(result == 'ready').lower(), 'alert': str(result == 'alert').lower()}
        summary = (f"Runtime {state['tag']}: {result.upper()}. {state['reason']}. "
                   + ('Readiness only; package/browser validation follows.' if result == 'ready' else
                      'Package/browser validation NOT RUN; no acceptance or success marker recorded.'))
        print(summary)
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as out:
            out.write(summary + '\n')
        if result == 'alert':
            args.marker.mkdir(parents=True, exist_ok=True)
            (args.marker / 'alert.json').write_text(json.dumps(state), encoding='utf-8')
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as out:
        for key, value in outputs.items():
            out.write(f'{key}={value}\n')


if __name__ == '__main__':
    main()
