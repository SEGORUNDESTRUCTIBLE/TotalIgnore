# TotalIgnore

Created and published by **Dr. Avinash Mandre**.

TotalIgnore is a Vencord plugin that locally filters selected Discord users
from supported message, voice-member, call-tile, and screen-share UI surfaces.
It can also locally mute ignored users in voice. This is a best-effort client
modification; Discord still delivers presence and voice information to the
client, and this does not hide a user from Discord or other participants.

## Easy installation on Windows

Download `TotalIgnore-Setup-1.1.0.exe` from the [latest GitHub release](https://github.com/SEGORUNDESTRUCTIBLE/TotalIgnore/releases/latest)
and follow the wizard. It installs the complete Vencord build and TotalIgnore
plugin into Discord Stable, without administrator privileges.

Alternatively, use the ZIP bundle:

Download and extract `dist/TotalIgnore-Vencord-1.15.9-Windows.zip`, close
Discord, and run `Install-TotalIgnore.bat`. Start Discord and enable TotalIgnore
in **User Settings → Vencord → Plugins**. The ZIP contains a complete Vencord
desktop build with the plugin included, its installer, install/uninstall
launchers, source snapshot, avatar, and applicable license notices.

Uninstall the GUI setup from **Installed apps** in Windows; uninstalling removes
Vencord from Discord Stable and keeps Vencord's settings.

Vencord is a prerequisite: TotalIgnore is a Vencord plugin, not a standalone
Discord extension. The all-in-one Windows bundle installs Vencord together
with TotalIgnore. The setup wizard and ZIP are unofficial community builds.
Windows SmartScreen may warn that the executable is unsigned; only run a
release downloaded from this repository.

## Source

The plugin source and supplied creator avatar are in
`src/plugins/totalIgnore/`. To use the plugin in another Vencord checkout, copy
that directory to `src/plugins/totalIgnore/`, build Vencord, and install it
using Vencord's documented development workflow.

The ready-to-install Windows setup executable and ZIP are in `dist/`.

Build the GUI setup with Inno Setup 6 after building the standalone Vencord
bundle:

```powershell
.\distribution\installer\Build-TotalIgnoreSetup.ps1
```

## Credits and license

Created by **Dr. Avinash Mandre**. This project is based on Vencord and is
distributed under the repository's GPL-3.0-or-later license; see `LICENSE`
and the included generated legal notices.

This is an unofficial community build. Discord and Vencord are not affiliated
with or responsible for this plugin. Use only builds and installers from
sources you trust.
