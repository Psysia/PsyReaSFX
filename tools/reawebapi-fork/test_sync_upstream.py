import hashlib
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

from sync_upstream import checked_asset, inspect_bundle, main, source_contracts, sync_source, valid_tag, web_contract


class MirrorIntegrity(unittest.TestCase):
    def test_only_version_tags_are_accepted(self):
        self.assertEqual(valid_tag("v0.3.9.32"), "v0.3.9.32")
        for tag in ("main", "../v1", "v1.2.3;anything", "v1.2.3-dev"):
            with self.assertRaises(ValueError):
                valid_tag(tag)

    def test_asset_url_and_hash_must_match_release(self):
        asset = {"name": "runtime.zip", "digest": "sha256:" + "a" * 64,
                 "browser_download_url": "https://github.com/a/b/releases/download/v1.2.3/runtime.zip"}
        release = {"tag_name": "v1.2.3", "assets": [asset]}
        self.assertEqual(checked_asset(release, "runtime.zip", "a/b"), asset)
        asset["browser_download_url"] = "https://example.com/runtime.zip"
        with self.assertRaises(ValueError):
            checked_asset(release, "runtime.zip", "a/b")

    def test_web_contract_allows_capability_setup(self):
        # v0.3.9.44+ adds browser/isolation setup without changing contract 1.
        source = '''Json Runtime::web_runtime(const Session& session) const {
          Json browser = {{"crossOriginIsolated", nullptr}};
          browser.update(session.browser_report);
          const bool required = session.app->resources && session.app->resources->isolation_required();
          const auto active = browser.at("crossOriginIsolated");
          Json supported = active == true ? Json(true) : Json();
#ifdef _WIN32
          supported = true;
#endif
          if (session.isolation_error == "CROSS_ORIGIN_ISOLATION_UNSUPPORTED") supported = false;
          return {{"contract", 1}, {"crossOriginIsolation", {{"requested", required ? "required" : "off"},
            {"supported", supported}, {"active", active}}}, {"browser", browser}};
        }'''
        self.assertEqual(web_contract(source), 1)
        self.assertEqual(web_contract(source.replace('{"contract", 1}', '{"contract", 7}')), 7)

    def test_web_contract_ignores_comments_and_quoted_braces(self):
        source = '''Json Runtime::web_runtime(const Session& session) const {
          // } return {{"contract", 99}};
          /* { return {{"contract", 98}}; */
          const char* text = "} return {";
          const char brace = '}';
          return {{"contract", 1}};
        }
        Json other() { return {{"contract", 97}}; }'''
        self.assertEqual(web_contract(source), 1)

    def test_web_contract_rejects_ambiguous_or_changed_declarations(self):
        signature = "Json Runtime::web_runtime(const Session& session) const {"
        for body in (
            'Json unused = {{"contract", 1}}; return unused;',
            'if (flag) return {{"contract", 1}};',
            'if (flag) { return {{"contract", 1}}; }',
            'if (flag) return {{"contract", 1}}; return {{"contract", 2}};',
            'auto fn = [] { return {{"contract", 1}}; }; return fn();',
            'return {{"contract", CONTRACT}};',
            'return {{"contract", 1 + 1}};',
            'return {{"contract", "1"}};',
            'return {{"other", 1}};',
            'return {};',
            'return {{"contract", 1}}; side_effect();',
            '#ifdef FEATURE\nreturn {{"contract", 1}};\n#endif\n',
        ):
            with self.subTest(body=body), self.assertRaises(ValueError):
                web_contract(signature + body + '} Json other() { return {{"contract", 9}}; }')
        valid = signature + 'return {{"contract", 1}}; }'
        for source in (valid + valid, valid[:-1], 'Json other() { return {{"contract", 1}}; }',
                       signature + 'auto s = R"(})"; return {{"contract", 1}}; }'):
            with self.subTest(source=source), self.assertRaises(ValueError):
                web_contract(source)

    def test_bundle_and_source_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive_path = Path(temporary) / "bundle.zip"
            binary = b"MZfixture"
            with zipfile.ZipFile(archive_path, "w") as archive:
                archive.writestr("UserPlugins/reaper_reawebapi-x64.dll", binary)
                for name in ("COPYING", "COPYING.LESSER", "LICENSE.md", "THIRD_PARTY.md"):
                    archive.writestr("ReaWebAPI/" + name, "license")
            self.assertEqual(inspect_bundle(archive_path, hashlib.sha256(binary).hexdigest()), binary)
            with self.assertRaises(ValueError):
                inspect_bundle(archive_path, "0" * 64)
            commit = "a" * 40
            source = Path(temporary) / "source.zip"
            with zipfile.ZipFile(source, "w") as archive:
                prefix = f"ReaWebAPI-{commit}/src/"
                archive.writestr(prefix + "core/core.cpp", '{"protocol", 1}, {"runtime", {{"contract", 2}}}')
                archive.writestr(prefix + "core/core.hpp", "inline constexpr size_t host_message_limit = 1024 * 1024;")
                archive.writestr(prefix + "runtime/runtime.cpp", 'Json Runtime::web_runtime(const Session& session) const { return {{"contract", 1}}; }')
            self.assertEqual(source_contracts(source, commit), {"protocol": 1, "runtime": 2, "web": 1, "max_message_bytes": 1048576})
            with self.assertRaises(KeyError):
                source_contracts(source, "b" * 40)


class SyncPolicy(unittest.TestCase):
    def test_source_sync_uses_only_fast_forward_main(self):
        with patch("sync_upstream.run", side_effect=["", "", "old", "new", "", ""]) as command:
            sync_source(Path("."))
        self.assertEqual(command.call_args_list[-2].args[:3], ("git", "merge-base", "--is-ancestor"))
        self.assertEqual(command.call_args_list[-1].args,
                         ("git", "push", "origin", "refs/remotes/upstream/main:refs/heads/main"))

    def test_workflow_permission_defers_but_other_failures_do_not(self):
        permission = RuntimeError("git push failed: refusing to allow a GitHub App to create or update workflow "
                                  ".github/workflows/build.yml without `workflows` permission")
        for problem, defer, allowed in (
            (permission, True, True), (permission, False, False),
            (RuntimeError("git push failed: permission to repository denied"), True, False),
            (RuntimeError("git merge-base failed: branches diverged"), True, False),
        ):
            args = ["sync"] + (["--defer-workflow-permission"] if defer else [])
            with self.subTest(problem=problem, defer=defer), patch("sys.argv", args), \
                    patch.dict(os.environ, GITHUB_REPOSITORY="Psysia/ReaWebAPI"), \
                    patch("sync_upstream.verify_origin"), patch("sync_upstream.sync_source", side_effect=problem), \
                    patch("sync_upstream.mirror_release") as mirror, patch("sync_upstream.report") as summary:
                if allowed:
                    main()
                    summary.assert_called_once()
                else:
                    with self.assertRaises(RuntimeError):
                        main()
                    summary.assert_not_called()
                mirror.assert_not_called()


if __name__ == "__main__":
    unittest.main()
