import hashlib
from pathlib import Path
import tempfile
import unittest
import zipfile

from sync_upstream import checked_asset, inspect_bundle, source_contracts, valid_tag


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


if __name__ == "__main__":
    unittest.main()
