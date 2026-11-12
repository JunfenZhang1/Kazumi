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

## Local AI translation (Ollama / LM Studio)

**Status:** Implemented as an optional, text-only, OpenAI-compatible
`/v1/chat/completions` client in this branch. Requires a user-run local
model server. Translation is performed **per live subtitle cue**; full-episode
pretranslation and a persisted on-disk subtitle cache are **not implemented**.

1. Install Ollama on your Windows PC: https://ollama.com/download/windows
2. Download a multilingual model:

   ```powershell
   ollama pull qwen2.5:3b
   ollama list
   ```

   The `qwen2.5:3b` model is around 1.9 GB in Ollama's published model
   catalog. Smaller `qwen2.5:1.5b` trades translation quality for lower
   memory use and potentially faster inference.
3. In Kazumi, open **播放器 → 更多 → 字幕转换 / 翻译**:
   - Mode: **本地 AI（Ollama / LM Studio）**
   - Endpoint: `http://127.0.0.1:11434/v1/chat/completions`
   - Model: `qwen2.5:3b`
4. The model translates the text-subtitle cues that Kazumi's media-kit player
   exposes. Original subtitles remain visible during inference or if the
   request fails. Results are cached **in memory** (max 400 items).

### Access from Android over your LAN (not Android offline inference)

- `127.0.0.1` on Android is the **phone**, not the Windows PC.
- If desired, configure the Windows Ollama service to bind to your PC's
  LAN address and allow inbound TCP 11434 from **trusted local devices only**.
  Ollama's `OLLAMA_HOST` environment variable controls listening.
- In Kazumi Android set `http://YOUR_PC_LAN_IP:11434/v1/chat/completions`.
- No remote cloud service is required, but the phone needs LAN connectivity
  and the PC/model server must be running.
- HTTP on a local LAN is unencrypted. Never expose Ollama directly to the
  public Internet without strong access controls and TLS.

**True Android on-device translation** would need a separate integration
(such as Google ML Kit's mobile translation engine or an embedded
llama.cpp runtime). That is **not part of this PR**.

### Performance notes

High-rate playback at 8x–16x gives a language model very little time to
translate each cue. For reliable high-rate *translated* subtitles, the next
feature should be **pretranslate the entire SRT/VTT subtitle track and cache
its timestamps/translations before playback**. The current local AI feature
does not claim to solve that problem.

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
