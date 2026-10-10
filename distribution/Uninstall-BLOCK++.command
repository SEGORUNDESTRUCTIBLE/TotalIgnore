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

if ! VENCORD_USER_DATA_DIR="$bundle_dir" VENCORD_DEV_INSTALL=1 "$installer" -uninstall -branch stable; then
    echo
    echo "Uninstallation failed. Check the installer output above."
    exit 1
fi

echo
echo "BLOCK++ by Dr. Avinash Mandre has been removed with Vencord from Discord Stable."
