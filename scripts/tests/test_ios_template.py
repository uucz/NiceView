from __future__ import annotations

import unittest
from pathlib import Path


class IosTemplateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.template = (
            Path(__file__).resolve().parents[1]
            / "templates"
            / "ios"
            / "AppDelegate.swift"
        ).read_text(encoding="utf-8")

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


if __name__ == "__main__":
    unittest.main()
