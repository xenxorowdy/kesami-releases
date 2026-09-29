# Kesami for macOS

Kesami is a meeting assistant that transcribes and summarizes your meetings.

**Requires a Mac with Apple Silicon (M1 or newer).** There is no Intel build yet.

## Install with one command (recommended)

Open **Terminal** and paste:

```
curl -fsSL https://raw.githubusercontent.com/xenxorowdy/kesami-releases/main/install.sh | bash
```

This downloads the latest release, checks it isn't corrupted, and installs it in
**Applications**. It will only ask for your password if your Applications folder
needs admin permission. If Kesami is already installed, it replaces it safely
and restores the old version if anything goes wrong. Quit Kesami first.

You can [read the script](install.sh) before running it.

## Install manually

1. Download `Kesami-<version>-arm64.dmg` from the
   [latest release](https://github.com/xenxorowdy/kesami-releases/releases/latest).
2. Open it and drag **Kesami** into **Applications**.

## "Apple could not verify Kesami"

Kesami is free and is not signed or notarized by Apple (that requires a paid
Apple Developer membership). Because of that, macOS may block the first launch,
especially after a browser download. Installing with the command above usually
avoids the prompt, but that isn't guaranteed.

If you trust Kesami and see the warning:

1. Open **System Settings → Privacy & Security**.
2. Scroll down to the message about Kesami and click **Open Anyway**.
3. Confirm with your password or Touch ID.

You only need to do this once per version. Don't turn off Gatekeeper or System
Integrity Protection to run Kesami; neither is needed.

## Permissions

On first use Kesami asks for **Microphone** and **Screen & System Audio
Recording** access so it can hear both sides of the meeting. You can change
these at any time in System Settings → Privacy & Security.

## Uninstall

Drag **Kesami** from Applications to the Trash.
