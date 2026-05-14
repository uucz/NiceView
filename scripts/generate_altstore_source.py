#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def parse_repository(value: str) -> tuple[str, str]:
    parts = value.strip().split("/")
    if len(parts) != 2 or not all(parts):
        raise ValueError("repository 必须是 owner/name 格式")
    return parts[0], parts[1]


def github_pages_base_url(repository: str) -> str:
    owner, name = parse_repository(repository)
    return f"https://{owner}.github.io/{name}"


def absolute_asset_url(value: str | None, base_url: str) -> str | None:
    if not value:
        return None
    if value.startswith(("http://", "https://")):
        return value
    return f"{base_url.rstrip('/')}/{value.lstrip('/')}"


def default_release_tag(version: str) -> str:
    return version if version.startswith("v") else f"v{version}"


def build_source(
    metadata: dict[str, Any],
    *,
    repository: str,
    version: str,
    build_version: str,
    release_tag: str | None,
    release_date: str,
    ipa_size: int,
    download_url: str | None,
    base_url: str | None,
    release_notes: str | None,
    min_os_version: str,
) -> dict[str, Any]:
    source_meta = dict(metadata["source"])
    app_meta = dict(metadata["app"])
    base_url = base_url or github_pages_base_url(repository)
    release_tag = release_tag or default_release_tag(version)
    download_url = download_url or (
        f"https://github.com/{repository}/releases/download/"
        f"{release_tag}/niceview-unsigned.ipa"
    )

    app_icon_url = absolute_asset_url(app_meta.get("iconURL"), base_url)
    app_meta["iconURL"] = app_icon_url

    source_icon_url = absolute_asset_url(source_meta.get("iconURL"), base_url)
    if source_icon_url is None:
        source_icon_url = app_icon_url

    source: dict[str, Any] = {
        "name": source_meta["name"],
        "subtitle": source_meta.get("subtitle", ""),
        "description": source_meta.get("description", ""),
        "iconURL": source_icon_url,
        "website": f"https://github.com/{repository}",
        "tintColor": source_meta.get("tintColor", app_meta.get("tintColor")),
        "featuredApps": source_meta.get("featuredApps", []),
        "apps": [
            {
                "name": app_meta["name"],
                "bundleIdentifier": app_meta["bundleIdentifier"],
                "developerName": app_meta["developerName"],
                "subtitle": app_meta.get("subtitle", ""),
                "localizedDescription": app_meta["localizedDescription"],
                "iconURL": app_meta["iconURL"],
                "tintColor": app_meta.get("tintColor"),
                "category": app_meta.get("category", "photo-video"),
                "versions": [
                    {
                        "version": version,
                        "buildVersion": build_version,
                        "date": release_date,
                        "localizedDescription": release_notes
                        or f"Nice View {version} 的 AltStore 版本。",
                        "downloadURL": download_url,
                        "size": ipa_size,
                        "minOSVersion": min_os_version,
                    }
                ],
                "appPermissions": app_meta.get(
                    "appPermissions", {"entitlements": [], "privacy": {}}
                ),
            }
        ],
        "news": [
            {
                "title": f"Nice View {version}",
                "identifier": f"nice-view-{version}-{build_version}",
                "caption": "Nice View 已提供 AltStore 安装包。",
                "date": release_date,
                "tintColor": app_meta.get("tintColor"),
                "appID": app_meta["bundleIdentifier"],
            }
        ],
    }

    return source


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="生成 AltStore Classic source.json。"
    )
    parser.add_argument("--metadata", default="altstore/metadata.json")
    parser.add_argument("--repository", required=True, help="GitHub owner/name")
    parser.add_argument("--version", required=True)
    parser.add_argument("--build-version", required=True)
    parser.add_argument("--release-tag")
    parser.add_argument("--date", required=True, help="ISO 8601 发布时间")
    parser.add_argument("--ipa", required=True, help="未签名 IPA 路径")
    parser.add_argument("--download-url")
    parser.add_argument("--base-url")
    parser.add_argument("--release-notes")
    parser.add_argument("--min-os-version", default="12.0")
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    ipa_path = Path(args.ipa)
    if not ipa_path.is_file():
        raise SystemExit(f"未找到 IPA：{ipa_path}")

    with Path(args.metadata).open("r", encoding="utf-8") as file:
        metadata = json.load(file)

    source = build_source(
        metadata,
        repository=args.repository,
        version=args.version,
        build_version=args.build_version,
        release_tag=args.release_tag,
        release_date=args.date,
        ipa_size=ipa_path.stat().st_size,
        download_url=args.download_url,
        base_url=args.base_url,
        release_notes=args.release_notes,
        min_os_version=args.min_os_version,
    )

    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(source, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
