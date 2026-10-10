# BLOCK++

Created and published by **Dr. Avinash Mandre**.

BLOCK++ is a Vencord plugin that locally filters selected Discord users
from supported message, voice-member, call-tile, and screen-share UI surfaces.
It can also locally mute blocked users in voice. This is a best-effort client
modification; Discord still delivers presence and voice information to the
client, and this does not hide a user from Discord or other participants.

## Easy installation on Windows

Exit Discord completely, including from the system tray, then download
`BLOCK++-Setup-1.1.20.exe` from the
[latest GitHub release](https://github.com/SEGORUNDESTRUCTIBLE/TotalIgnore/releases/latest)
and follow the wizard. Setup checks that Discord is closed before changing
files. It installs the complete Vencord build and BLOCK++ plugin into
Discord Stable, without administrator privileges.
If patching fails, the setup error dialog includes diagnostic output to share
when asking for help.
If setup reports that Discord's newest app folder is incomplete, launch
Discord, let its update finish, exit Discord completely, and then rerun setup.
Repair or reinstall Discord first if it will not start.

Alternatively, use the ZIP bundle:

Download and extract `dist/BLOCK++-Vencord-1.15.9-Windows.zip`, close
Discord, and run `Install-BLOCK++.bat`. Start Discord and enable BLOCK++
in **User Settings → BLOCK++ Settings → Plugins**. The ZIP contains a
complete Vencord desktop build with the plugin included, its installer, install/uninstall
launchers, source snapshot, avatar, and applicable license notices.

Uninstall the GUI setup from **Installed apps** in Windows; uninstalling removes
Vencord from Discord Stable and keeps Vencord's settings.

## macOS

The v1.1.20 release includes Windows assets only; it does not include a
BLOCK++ macOS bundle.

Vencord is a prerequisite: BLOCK++ is a Vencord plugin, not a standalone
Discord extension. The all-in-one Windows bundle installs Vencord together
with BLOCK++. The setup wizard and ZIP are unofficial community builds.
Windows SmartScreen may warn that the executable is unsigned; only run a
release downloaded from this repository.

## Source

The plugin source and supplied creator avatar are in
`src/plugins/blockPlusPlus/`. To use the plugin in another Vencord checkout, copy
that directory to `src/plugins/blockPlusPlus/`, build Vencord, and install it
using Vencord's documented development workflow.

The ready-to-install Windows setup executable and ZIP are in `dist/`.

Build the GUI setup with Inno Setup 6 after building the standalone Vencord
bundle:

```powershell
.\distribution\installer\Build-BLOCK++Setup.ps1
```

## Credits and license

Created by **Dr. Avinash Mandre**. This project is based on Vencord and is
distributed under the repository's GPL-3.0-or-later license; see `LICENSE`
and the included generated legal notices.

This is an unofficial community build. Discord and Vencord are not affiliated
with or responsible for this plugin. Use only builds and installers from
sources you trust.
