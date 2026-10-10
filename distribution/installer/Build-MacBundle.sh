#!/bin/bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "$0")/../.." && pwd)"
vencord_root="${1:?Pass the path to the Vencord checkout}"
version="$(node -e 'console.log(require(process.argv[1]).version)' "$vencord_root/package.json")"
stage_root="$(mktemp -d "${TMPDIR:-/tmp}/blockplus-macos.XXXXXX")"
stage="$stage_root/BLOCK++++-Vencord-$version-macOS"
archive="$repo_root/dist/BLOCK++++-Vencord-$version-macOS.zip"

cleanup() {
    rm -rf "$stage_root"
}
trap cleanup EXIT

mkdir -p "$stage/dist" "$stage/source" "$repo_root/dist"
cp "$repo_root/README.md" "$stage/README.md"
cp "$repo_root/distribution/Install-BLOCK++++.command" "$stage/"
cp "$repo_root/distribution/Uninstall-BLOCK++++.command" "$stage/"
chmod +x "$stage/Install-BLOCK++++.command" "$stage/Uninstall-BLOCK++++.command"

for file in LICENSE README.md package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.json eslint.config.mjs .editorconfig .gitattributes; do
    if [[ -f "$vencord_root/$file" ]]; then
        cp "$vencord_root/$file" "$stage/source/"
    fi
done

for directory in src scripts packages patches themes browser; do
    if [[ -d "$vencord_root/$directory" ]]; then
        mkdir -p "$stage/source/$directory"
        rsync -a \
            --exclude='node_modules/' \
            --exclude='.git/' \
            --exclude='.turbo/' \
            --exclude='settings/' \
            --exclude='*.map' \
            --exclude='settings.json' \
            --exclude='quickCss.css' \
            "$vencord_root/$directory/" "$stage/source/$directory/"
    fi
done

mkdir -p "$stage/source/src/plugins/totalIgnore"
rsync -a \
    --exclude='*.map' \
    "$repo_root/src/plugins/totalIgnore/" "$stage/source/src/plugins/totalIgnore/"

if [[ ! -x "$vencord_root/dist/Installer/VencordInstallerCli-darwin" ]]; then
    echo "The macOS Vencord installer is missing or not executable." >&2
    exit 1
fi

rsync -a \
    --exclude='*-unpacked/' \
    --exclude='setup-payload/' \
    --exclude='setup-assets/' \
    --exclude='TotalIgnore-Vencord-*-macOS.zip' \
    --exclude='TotalIgnore-Vencord-*-Windows.zip' \
    --exclude='TotalIgnore-Setup-*.exe' \
    --exclude='*.map' \
    --exclude='etag.txt' \
    --exclude='settings/' \
    --exclude='settings.json' \
    --exclude='quickCss.css' \
    "$vencord_root/dist/" "$stage/dist/"

for required in \
    "$stage/README.md" \
    "$stage/Install-BLOCK++++.command" \
    "$stage/Uninstall-BLOCK++++.command" \
    "$stage/dist/Installer/VencordInstallerCli-darwin" \
    "$stage/dist/vencordDesktopRenderer.js" \
    "$stage/source/src/plugins/totalIgnore/index.tsx" \
    "$stage/source/LICENSE"; do
    if [[ ! -f "$required" ]]; then
        echo "Release package is incomplete; missing: $required" >&2
        exit 1
    fi
done

rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$stage" "$archive"
echo "Created: $archive"
echo "Size: $(wc -c < "$archive" | tr -d ' ') bytes"
shasum -a 256 "$archive"
