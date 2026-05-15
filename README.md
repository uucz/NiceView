# Nice View

一款神奇的看图软件，可以方便的查看和下载一些很nice的图片。

当前 fork 补齐了 iOS / AltStore 安装链，并加入：

- iOS 保存到系统相册
- 方向筛选、分类筛选、标签发现和标签预览
- 完整标签浏览、图集列表和同图集继续浏览
- 独立收藏缓存，收藏不会被浏览历史上限淘汰
- 浏览历史、收藏视图、默认偏好和缓存数据管理
- iOS haptic、App icon 与 launch screen 注入

## Android

打 `v*` 标签后，GitHub Actions 会构建 split-per-ABI release APK，并将以下资产上传到对应 GitHub Release：

- `niceview-vX.Y.Z-android-arm64-v8a.apk`：大多数现代 Android 设备使用。
- `niceview-vX.Y.Z-android-armeabi-v7a.apk`：较老的 32 位 ARM 设备使用。
- `niceview-vX.Y.Z-android-x86_64.apk`：模拟器或少量 x86_64 设备使用。

workflow 同时保留 `nice-view-release-apk` Actions artifact，便于从单次 CI 运行中下载原始构建产物。

## iOS / AltStore

本 fork 增加了 iOS 未签名 IPA 与 AltStore Classic 源的自动发布流程。打 `v*` 标签后，GitHub Actions 会：

1. 在 macOS runner 上临时生成 Flutter iOS 工程。
2. 构建 `build/ios/niceview-unsigned.ipa`。
3. 生成 AltStore 源文件 `source.json`。
4. 将 IPA 与 `source.json` 上传到 GitHub Release。
5. 将 `source.json` 发布到 GitHub Pages。

AltStore 源地址：

```text
https://uucz.github.io/NiceView/source.json
```

安装步骤：

1. 在 iOS 设备上安装 AltStore。
2. 打开 AltStore，进入 `Browse` -> `Sources`。
3. 点击左上角 `+`。
4. 粘贴源地址 `https://uucz.github.io/NiceView/source.json`。
5. 在源中找到 `Nice View` 并安装。

首次发布前需要在仓库 `Settings` -> `Pages` 中确认使用 GitHub Actions 部署。

本地或 CI 构建未签名 IPA：

```bash
scripts/build_unsigned_ios_ipa.sh 0.4.0 1
```

## 友情链接

- [Linux.do](https://linux.do) - Nice View 认可 Linux.do 真诚分享、友善交流的社区氛围，也感谢它为开发者与创作者提供高质量讨论空间。
