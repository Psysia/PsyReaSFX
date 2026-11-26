import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from reawebapi_schedule_gate import inspect, main, metadata


class MirrorReadinessTests(unittest.TestCase):
    def setUp(self):
        self.release = {'tag_name': 'v0.3.9.47', 'draft': False,
                        'assets': [{'name': name, 'digest': 'sha256:' + 'a' * 64} for name in
                                   ('ReaWebAPI-windows-x64-v0.3.9.47.zip', 'reaper_reawebapi-x64.dll',
                                    'ReaWebAPI-source.zip', 'mirror-manifest.json')]}
        self.mirror = copy.deepcopy(self.release)
        self.behind = False

    def get(self, path, optional=False):
        if path.endswith('/releases/latest'):
            return self.release
        if '/releases/tags/' in path:
            self.assertTrue(optional)
            return self.mirror
        if '/commits/' in path:
            return {'sha': ('b' if self.behind and path == 'Psysia/ReaWebAPI/commits/main' else 'a') * 40}
        raise AssertionError(path)

    def test_pending_release_and_recovery(self):
        ready_mirror = self.mirror
        self.mirror = None
        state = inspect(self.get)
        self.assertFalse(state['ready'])
        self.assertEqual(state['tag'], 'v0.3.9.47')
        self.assertEqual(state['commit'], 'a' * 40)
        self.mirror = ready_mirror
        self.assertTrue(inspect(self.get)['ready'])

    def test_draft_and_source_lag_wait(self):
        self.mirror['draft'] = True
        self.assertFalse(inspect(self.get)['ready'])
        self.mirror['draft'] = False
        self.behind = True
        self.assertFalse(inspect(self.get)['ready'])

    def test_integrity_errors_raise(self):
        self.mirror['assets'][0]['digest'] = 'sha256:' + 'b' * 64
        with self.assertRaisesRegex(ValueError, 'differs'):
            inspect(self.get)
        self.mirror = copy.deepcopy(self.release)
        self.mirror['assets'].pop()
        with self.assertRaisesRegex(ValueError, 'incomplete'):
            inspect(self.get)

    def test_only_404_is_optional(self):
        for status in (401, 403, 429, 500, 404):
            error = HTTPError('https://api.github.com/test', status, 'test', {}, None)
            with patch('reawebapi_schedule_gate.urlopen', side_effect=error):
                if status == 404:
                    self.assertIsNone(metadata('test', optional=True))
                else:
                    with self.assertRaises(HTTPError):
                        metadata('test', optional=True)

    def test_workflow_outputs_capture_tag_and_immutable_commit(self):
        for ready in (True, False):
            if not ready:
                self.mirror = None
            with self.subTest(ready=ready), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                with patch.dict(os.environ, GITHUB_OUTPUT=str(root / 'output'), GITHUB_STEP_SUMMARY=str(root / 'summary')):
                    with patch('sys.argv', ['gate', '--state', str(root / 'state.json')]), \
                            patch('reawebapi_schedule_gate.inspect', return_value=inspect(self.get)):
                        main()
                output = dict(line.split('=', 1) for line in (root / 'output').read_text().splitlines())
                self.assertEqual(output, dict(tag='v0.3.9.47', commit='a' * 40, source='a' * 40, ready=str(ready).lower()))
                self.assertEqual(json.loads((root / 'state.json').read_text())['ready'], ready)
                if not ready:
                    self.assertIn('validation is deferred', (root / 'summary').read_text(encoding='utf-8'))

    def test_workflow_keeps_required_validation_and_defers_only_latest_runtime(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/development-webview.yml').read_text(encoding='utf-8')
        self.assertIn("if: github.event_name != 'schedule' || needs.readiness.outputs.ready == 'true'", workflow)
        self.assertIn("Build the pinned runtime while the mirror is waiting", workflow)
        self.assertIn("-MirroredTag $env:MIRRORED_TAG -MirroredCommit $env:MIRRORED_COMMIT", workflow)
        self.assertNotIn("continue-on-error", workflow)
        for check in ("Test-WebViewPackage.ps1", "Browser regression failed.", "Record pinned package verification",
                      "Record successful validation"):
            self.assertIn(check, workflow)


if __name__ == '__main__':
    unittest.main()
