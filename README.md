<p align="center">
 <img width=120px height=120px src="assets/icons/launcher/sorayomi_icon.png" alt="Tsumiru logo"/>
</p>

<h1 align="center">Tsumiru</h1>

<div align="center">

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS%20%7C%20Web-lightgrey)](https://github.com/aaronbamblett/tsumiru/releases)
[![License: MPL-2.0](https://img.shields.io/badge/license-MPL--2.0-blue)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/aaronbamblett/tsumiru?label=download)](https://github.com/aaronbamblett/tsumiru/releases/latest)

</div>

<p align="center">
A polished, native client for reading manga &amp; manhwa from a
<a href="https://github.com/Suwayomi/Suwayomi-Server">Suwayomi-Server</a> instance —
built for long webtoon binges on your phone.
</p>

> **Tsumiru** *(積みる)* — a play on *tsundoku* (積ん読), the art of letting unread
> books pile up. For everyone whose backlog grows faster than they can read it.

---

## What it is

Tsumiru is an enhanced fork of [Tachidesk-Sorayomi](https://github.com/Suwayomi/Tachidesk-Sorayomi),
the Flutter client for the self-hosted [Suwayomi-Server](https://github.com/Suwayomi/Suwayomi-Server)
manga server. It connects to a server you already run — it is a reader, not a server.

Runs on **Android, Linux, Windows, macOS, and Web**.

## What's different from upstream Sorayomi

This fork focuses on making it a great daily driver, especially for **webtoon / manhwa** reading:

- **Rebuilt webtoon reader** — seamless multi-chapter continuous scroll, with the
  backward-scroll "snap" fixed (pages reserve their measured height so a strip never
  collapses and yanks you backward).
- **Pinch-to-zoom that scrolls while zoomed.**
- **Authentication** — `simple_login` + `ui_login`, secure-storage credentials,
  proactive token refresh, authenticated GraphQL WebSocket subscriptions.
- **Library** — sort by last read, Last Chapter Date & Total Chapters sorts,
  Started/Bookmarked filters, a fixed tri-state filter, and a bulk-download presets menu.
- **UI fixes** — proper insets above the Android navigation bar, download-tile overflow fix.

## Download

Grab the latest build for your platform from the
[**Releases**](https://github.com/aaronbamblett/tsumiru/releases/latest) page
(Android APKs — universal + per-ABI — plus Linux, Windows, macOS, and Web).

**Android, with auto-updates:** add this repo to
[Obtainium](https://github.com/ImranR98/Obtainium) and it will install and keep
Tsumiru updated straight from GitHub Releases — no app store needed.

## Requirements

You need a running [Suwayomi-Server](https://github.com/Suwayomi/Suwayomi-Server)
that Tsumiru can reach. On first launch, point it at your server's address.

## Building

Flutter 3.32.4 / Dart 3.8.1 (pinned).

```bash
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter build apk            # or: linux / windows / macos / web
```

## Credits & license

Tsumiru stands on the work of the [Suwayomi](https://github.com/Suwayomi) project:
[Tachidesk-Sorayomi](https://github.com/Suwayomi/Tachidesk-Sorayomi) (the client this
forks) and [Suwayomi-Server](https://github.com/Suwayomi/Suwayomi-Server) (the server it
talks to). Huge thanks to those maintainers and contributors.

Licensed under the **Mozilla Public License 2.0** — see [LICENSE](LICENSE). As with the
upstream project, source files retain their MPL-2.0 headers.
