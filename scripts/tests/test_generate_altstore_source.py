from __future__ import annotations

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from generate_altstore_source import build_source


class GenerateAltStoreSourceTest(unittest.TestCase):
    def test_build_source_uses_github_release_and_pages_urls(self) -> None:
        metadata = {
            "source": {
                "name": "Nice View Source",
                "subtitle": "安装源",
                "description": "说明",
                "tintColor": "#D9A441",
                "featuredApps": ["com.ortlinde.niceview"],
            },
            "app": {
                "name": "Nice View",
                "bundleIdentifier": "com.ortlinde.niceview",
                "developerName": "uucz",
                "localizedDescription": "看图客户端",
                "iconURL": "icon.svg",
                "tintColor": "#D9A441",
                "category": "photo-video",
                "appPermissions": {"entitlements": [], "privacy": {}},
            },
        }

        source = build_source(
            metadata,
            repository="uucz/NiceView",
            version="0.2.1",
            build_version="7",
            release_tag="v0.2.1",
            release_date="2026-05-14T00:00:00Z",
            ipa_size=123,
            download_url=None,
            base_url=None,
            release_notes=None,
            min_os_version="12.0",
        )

        app = source["apps"][0]
        version = app["versions"][0]

        self.assertEqual(source["website"], "https://github.com/uucz/NiceView")
        self.assertEqual(
            app["iconURL"], "https://uucz.github.io/NiceView/icon.svg"
        )
        self.assertEqual(version["buildVersion"], "7")
        self.assertEqual(
            version["downloadURL"],
            "https://github.com/uucz/NiceView/releases/download/"
            "v0.2.1/niceview-unsigned.ipa",
        )
        self.assertEqual(version["size"], 123)
        self.assertEqual(app["appPermissions"], {"entitlements": [], "privacy": {}})

    def test_build_source_preserves_privacy_usage_descriptions(self) -> None:
        metadata = {
            "source": {
                "name": "Nice View Source",
                "featuredApps": ["com.ortlinde.niceview"],
            },
            "app": {
                "name": "Nice View",
                "bundleIdentifier": "com.ortlinde.niceview",
                "developerName": "uucz",
                "localizedDescription": "看图客户端",
                "iconURL": "icon.svg",
                "appPermissions": {
                    "entitlements": [],
                    "privacy": {
                        "NSPhotoLibraryAddUsageDescription": "保存图片到系统相册",
                    },
                },
            },
        }

        source = build_source(
            metadata,
            repository="uucz/NiceView",
            version="0.2.2",
            build_version="1",
            release_tag="v0.2.2",
            release_date="2026-05-14T00:00:00Z",
            ipa_size=456,
            download_url=None,
            base_url=None,
            release_notes=None,
            min_os_version="12.0",
        )

        privacy = source["apps"][0]["appPermissions"]["privacy"]

        self.assertEqual(
            privacy,
            {"NSPhotoLibraryAddUsageDescription": "保存图片到系统相册"},
        )


if __name__ == "__main__":
    unittest.main()
