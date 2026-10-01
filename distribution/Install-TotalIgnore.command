#!/bin/bash
set -euo pipefail

bundle_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
installer="$bundle_dir/dist/Installer/VencordInstallerCli-darwin"

if [[ ! -x "$installer" ]]; then
    echo "Could not find the bundled macOS Vencord installer:"
    echo "$installer"
    exit 1
fi

echo "Quit Discord completely, then press Return to continue (or Ctrl+C to cancel)."
read -r

if ! VENCORD_USER_DATA_DIR="$bundle_dir" VENCORD_DEV_INSTALL=1 "$installer" -install -branch stable; then
    echo
    echo "Installation failed. Check the installer output above."
    exit 1
fi

echo
echo "TotalIgnore by Dr. Avinash Mandre is installed."
echo "Start Discord and enable TotalIgnore in User Settings > Vencord > Plugins."
