# Kazumi personal fork

This fork adds a 0.1x–16.0x playback-speed range, a text-subtitle processing overlay,
Windows/Android CI artifacts, and a reviewable upstream synchronization workflow.

## Playback speed

- Playback menu > speed > slider: 0.1x–16.0x, 0.1x increments.
- Keyboard X / Z: increase / decrease by 0.1x.
- Settings > player: default speed and long-press speed support up to 16x.
- At rates above 8x, smooth video and high-fidelity audio are **not guaranteed**.
  The player continues to synchronize text-subtitle cues with the actual playback position.

## Subtitle processing

In the player, open **More > 字幕转换 / 翻译**:

- **原始字幕**: keep upstream native display.
- **繁体转简体（本地）**: offline text conversion via the pure Dart `pinyin` library.
- **翻译为简体中文（联网）**: supply your own LibreTranslate-compatible
  `https://HOST/translate` endpoint and optional API key. Target language `zh`.
  The translation result is additionally converted to simplified Chinese.

Important restrictions:

- Only text subtitle cues available from media-kit are supported.
- Burned-in subtitle pixels and subtitle text inside third-party WebViews cannot be modified by this overlay.
- This does not perform OCR or speech recognition.
- Network translation is asynchronous. Original cues appear while requests are in flight,
  and stale requests are canceled when the cue changes. At extreme playback rates,
  external translation may be too slow: pretranslated local subtitles are preferable.
- Subtitle text is transmitted to your configured translation server.
- API keys are stored in the existing local Hive settings, **not encrypted**.
  Avoid placing important credentials here on a shared machine.

## Build

The `Fork Build (Windows + Android)` workflow runs on feature branches,
main updates, pull requests, or manually from GitHub Actions.

Artifacts:

- `kazumi-fork-windows`: ZIP containing the Windows EXE and all required DLLs.
- `kazumi-fork-android-arm64`: Android ARM64 APK.

The Android application ID is `com.junfenzhang1.kazumifork`, separate from
the official Kazumi. Existing official-app data does **not** automatically
migrate to the fork. Ensure exports/backups are saved before changing apps.

### Persistent Android signing

To allow later APK builds to install over earlier builds without uninstalling,
generate a private upload keystore and configure **repository Actions secrets**:

1. `ANDROID_KEYSTORE_BASE64`: base64 of the full keystore file.
2. `ANDROID_STORE_PASSWORD`: keystore password.
3. `ANDROID_KEY_PASSWORD`: key password.
4. `ANDROID_KEY_ALIAS`: key alias.

For example, generate a key on your own computer using JDK's `keytool`:

```powershell
keytool -genkeypair -v -keystore kazumi-fork.jks -alias kazumi-fork -keyalg RSA -keysize 3072 -validity 36500
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path .\kazumi-fork.jks)))
```

Copy the printed base64 string to the appropriate GitHub secret; **never**
commit the keystore or its password. Store a separate safe backup. If you
lose the signing key, subsequent APK builds cannot upgrade the existing package.

Without the four secrets, CI builds a **debug-signed** release APK for testing;
signatures may change across CI runners, so upgrades are not guaranteed.

## Upstream sync

The `Propose upstream updates` workflow runs weekly and can be triggered
manually. It merges `Predidit/Kazumi:main` into a separate branch
`bot/upstream-sync` and opens a PR into your fork's `main`.

Review the PR, test Windows and Android, then merge it. Merge conflicts are
reported by the workflow and require manual resolution. No unattended changes
are applied to `main`.

Repository Settings > Actions > General must allow the Actions token to
create pull requests and grant the workflow the required write permissions.
On new forks, you may also need to enable GitHub Actions explicitly.

## App updates

The in-app update API now points at this fork's GitHub Releases rather than
the official Kazumi project. By default automatic update checks are disabled
in new fork installations until you have published a release.

To distribute updates through the app, publish numeric release tags
(e.g. `2.4.5`) corresponding to an incremented `pubspec.yaml` version, and
attach matching `windows*.zip` and `android*.apk` artifacts.

**The current CI workflow uploads Actions artifacts, not GitHub Releases.**
Release publishing and version bumps remain a separate, explicit step.
