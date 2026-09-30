# TotalIgnore by Dr. Avinash Mandre — Windows installer

Created and published by **Dr. Avinash Mandre**.

This is an independently built installer for a Windows desktop bundle based on
Vencord 1.15.9, with the TotalIgnore plugin included. It is not an official
Discord or Vencord installer.

## Install

1. Download and run **TotalIgnore-Setup-1.1.0.exe** from the GitHub release.
2. Follow the setup wizard. It installs to your Windows user profile and does
   not need administrator privileges.
3. Close Discord if prompted and allow setup to patch Discord Stable.
4. Start Discord. Open **User Settings → Vencord → Plugins**, enable
   **TotalIgnore**, and use **Ignore user** from a person's context menu or add
   their ID in the plugin settings.

The setup includes the full Vencord build, TotalIgnore plugin, installer
payload, source snapshot, and license notices. Vencord stores settings in the
current Windows user's Vencord data directory (normally
`%APPDATA%\Vencord`); personal settings and ignored-user IDs are not included
in the download.

For the ZIP-only fallback, extract `TotalIgnore-Vencord-1.15.9-Windows.zip`,
close Discord, and run **Install-TotalIgnore.bat** in the extracted folder.

Ignored voice members, call tiles, and their screen-share tiles are hidden from
the local UI. Local mute is stored through Discord's voice settings so it also
applies to new connections; unignoring restores the user's previous local mute
state.

To uninstall, use **Installed apps** in Windows and select **TotalIgnore by
Dr. Avinash Mandre**. This also removes Vencord from Discord Stable; your
Vencord settings are kept.

An unsigned-community-build warning may appear in Windows SmartScreen. Only
run installers downloaded from this project's official GitHub release page;
verify its SHA-256 checksum there before installing.

The ZIP version, manual instructions, plugin source, and standalone installer
build script are also available in this repository.

## Important

- This build is intended for Windows desktop Discord. It may stop working
  after Discord changes its UI or client internals.
- TotalIgnore is local, best-effort filtering. Discord still sends voice and
  presence data to the client; this does not make a user invisible to Discord
  or other participants.
- The archive does not include anyone's Discord account settings, ignored-user
  IDs, tokens, or local client data. Each recipient configures their own list.
- The bundle is distributed under the repository's GPL-3.0-or-later license.
  Preserve the included `LICENSE` and generated legal notices when
  redistributing it.
