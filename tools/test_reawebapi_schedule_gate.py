import copy
from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from reawebapi_schedule_gate import decision, inspect, metadata


class ScheduleGateTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 16, 12, tzinfo=timezone.utc)
        self.release = {'tag_name': 'v0.3.9.47', 'draft': False, 'published_at': '2026-11-16T08:00:00Z',
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

    def state(self):
        return inspect(self.get, self.now)

    def test_ready_and_recovery_ignore_old_alert(self):
        for alerted in (False, True):
            self.assertEqual(decision(self.state(), alerted), 'ready')

    def test_waiting_grace_then_alert_then_duplicate(self):
        self.mirror = None
        self.release['published_at'] = '2026-11-16T11:00:00Z'
        self.assertEqual(decision(self.state(), False), 'deferred')
        self.release['published_at'] = '2026-11-16T10:00:00Z'
        self.assertEqual(decision(self.state(), False), 'alert')
        self.assertEqual(decision(self.state(), True), 'deferred')

    def test_new_tag_has_independent_alert_key(self):
        self.mirror = None
        markers = {self.state()['tag']}
        self.release['tag_name'] = 'v0.3.9.48'
        state = self.state()
        self.assertEqual(decision(state, state['tag'] in markers), 'alert')

    def test_draft_and_source_lag_defer(self):
        self.mirror['draft'] = True
        self.assertFalse(self.state()['ready'])
        self.mirror['draft'] = False
        self.behind = True
        self.assertFalse(self.state()['ready'])
        self.assertEqual(decision(self.state(), False), 'deferred')
        self.assertEqual(decision(self.state(), True), 'deferred')

    def test_integrity_errors_are_not_deduplicated(self):
        for alerted in (False, True):
            self.mirror = copy.deepcopy(self.release)
            self.mirror['assets'][0]['digest'] = 'sha256:' + 'b' * 64
            with self.assertRaisesRegex(ValueError, 'differs'):
                decision(self.state(), alerted)
            self.mirror = copy.deepcopy(self.release)
            self.mirror['assets'].pop()
            with self.assertRaisesRegex(ValueError, 'incomplete'):
                decision(self.state(), alerted)

    def test_only_404_is_optional(self):
        for status in (401, 403, 429, 500, 404):
            error = HTTPError('https://api.github.com/test', status, 'test', {}, None)
            with patch('reawebapi_schedule_gate.urlopen', side_effect=error):
                if status == 404:
                    self.assertIsNone(metadata('test', optional=True))
                else:
                    with self.assertRaises(HTTPError):
                        metadata('test', optional=True)

    def test_cli_saves_alert_before_workflow_failure_and_never_acceptance(self):
        import json
        import os
        from reawebapi_schedule_gate import main
        self.mirror = None
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            state = root / 'state.json'
            state.write_text(json.dumps(self.state()))
            with patch.dict(os.environ, GITHUB_OUTPUT=str(root / 'output'), GITHUB_STEP_SUMMARY=str(root / 'summary')):
                with patch('sys.argv', ['gate', '--decide', '--state', str(state), '--marker', str(root / 'marker')]):
                    main()
            self.assertIn('ready=false', (root / 'output').read_text())
            self.assertIn('alert=true', (root / 'output').read_text())
            self.assertTrue((root / 'marker/alert.json').is_file())
            self.assertIn('NOT RUN', (root / 'summary').read_text())

    def test_workflow_preserves_verification_and_failure_paths(self):
        workflow = (Path(__file__).resolve().parents[1] / '.github/workflows/development-webview.yml').read_text()
        self.assertLess(workflow.index('Save per-version alert marker'), workflow.index('Report first persistent'))
        self.assertIn("if: github.event_name != 'schedule' || needs.readiness.outputs.ready == 'true'", workflow)
        self.assertNotIn('continue-on-error', workflow)
        for check in ('Test-WebViewPackage.ps1', 'Browser regression failed.', '-ReadOnlySync', 'Record successful validation'):
            self.assertIn(check, workflow)


if __name__ == '__main__':
    unittest.main()
