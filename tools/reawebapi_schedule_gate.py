#!/usr/bin/env python3
"""Resolve the upstream release and check the fork before candidate tests."""
import argparse
import json
import os
from pathlib import Path
import re
from urllib.error import HTTPError
from urllib.request import Request, urlopen

UPSTREAM = 'zaibuyidao/ReaWebAPI'
FORK = 'Psysia/ReaWebAPI'


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


def inspect(get=metadata):
    release = get(UPSTREAM + '/releases/latest')
    tag = release['tag_name']
    if not re.fullmatch(r'v\d+(?:\.\d+){2,3}', tag) or release['draft']:
        raise ValueError('Unexpected upstream release')
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
        if fork_head != source:
            source = get(UPSTREAM + '/commits/main')['sha']
            if not re.fullmatch(r'[a-f0-9]{40}', source):
                raise ValueError('Invalid upstream source commit')
        ready = fork_head == source
        reason = 'mirror ready' if ready else 'fork source has not caught up'
    return dict(tag=tag, commit=commit, source=source, ready=ready, reason=reason)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state', type=Path, required=True)
    args = parser.parse_args()
    state = inspect()
    args.state.write_text(json.dumps(state), encoding='utf-8')
    summary = (f"Runtime {state['tag']}: {'READY' if state['ready'] else 'WAITING'}. {state['reason']}. "
               + ('Candidate validation follows.' if state['ready'] else 'Latest runtime validation is deferred.'))
    localized = '接下来验证上游版本。' if state['ready'] else '等待镜像后验证最新运行时。'
    print(summary)
    with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as out:
        out.write(summary + ' / ' + localized + '\n')
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as out:
        for key in ('tag', 'commit', 'source', 'ready'):
            value = str(state[key]).lower()
            out.write(f'{key}={value}\n')


if __name__ == '__main__':
    main()
