from __future__ import annotations

import unittest
from pathlib import Path


class IosTemplateTest(unittest.TestCase):
    def setUp(self) -> None:
        root = Path(__file__).resolve().parents[1]
        self.template = (
            root / "templates" / "ios" / "AppDelegate.swift"
        ).read_text(encoding="utf-8")
        self.launch_template = (
            root / "templates" / "ios" / "LaunchScreen.storyboard"
        ).read_text(encoding="utf-8")
        self.build_script = (root / "build_unsigned_ios_ipa.sh").read_text(
            encoding="utf-8"
        )

    def test_download_channel_uses_registrar_and_is_retained(self) -> None:
        self.assertIn('registrar(forPlugin: "NiceViewDownloadsPlugin")', self.template)
        self.assertIn("private var downloadsChannel: FlutterMethodChannel?", self.template)
        self.assertIn("downloadsChannel = channel", self.template)

    def test_photo_save_uses_original_temp_file_url(self) -> None:
        self.assertIn("typedBytes.data.write(to: tempURL", self.template)
        self.assertIn(
            "PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tempURL)",
            self.template,
        )
        self.assertIn("FileManager.default.removeItem(at: tempURL)", self.template)

    def test_launch_screen_and_icon_assets_are_injected(self) -> None:
        self.assertIn('text="Nice View"', self.launch_template)
        self.assertIn("UILaunchStoryboardName", self.build_script)
        self.assertIn("LaunchScreen.storyboard", self.build_script)
        self.assertIn("AppIcon.appiconset", self.build_script)
        self.assertIn("Icon-App-1024x1024@1x.png", self.build_script)


if __name__ == "__main__":
    unittest.main()
