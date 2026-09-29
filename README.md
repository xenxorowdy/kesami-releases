# Kesami for macOS

Kesami is a meeting assistant that transcribes and summarizes your meetings.

## Download

**[Download the latest version](https://github.com/xenxorowdy/kesami-releases/releases/latest)** — grab `Kesami-<version>-arm64.dmg`.

Requires a Mac with Apple Silicon (M1 or newer).

## Install

1. Open the `.dmg` and drag **Kesami** into **Applications**.
2. The first time, macOS may say Kesami can't be opened because Apple can't verify it. To allow it, either:
   - open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, or
   - run this once in Terminal:

     ```
     xattr -dr com.apple.quarantine /Applications/Kesami.app
     ```
3. Open Kesami and allow microphone and screen & system audio access when asked.
