$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$stage = Join-Path $root "distribution\TotalIgnore-Vencord-1.15.9-Windows"
$archive = Join-Path $root "dist\TotalIgnore-Vencord-1.15.9-Windows.zip"

if (Test-Path -LiteralPath $stage) {
    Remove-Item -LiteralPath $stage -Recurse -Force
}
if (Test-Path -LiteralPath $archive) {
    Remove-Item -LiteralPath $archive -Force
}

function Copy-PackageTree([string]$SourcePath, [string]$DestinationPath) {
    New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $SourcePath -Force) {
        if ($item.PSIsContainer) {
            if ($item.Name -in @("node_modules", ".git", ".turbo", "settings")) {
                continue
            }
            Copy-PackageTree -SourcePath $item.FullName -DestinationPath (Join-Path $DestinationPath $item.Name)
        } elseif ($item.Extension -ne ".map" -and $item.Name -notin @("settings.json", "quickCss.css")) {
            Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $DestinationPath $item.Name)
        }
    }
}

try {
    New-Item -ItemType Directory -Path $stage, (Join-Path $stage "dist") | Out-Null

    foreach ($item in @(
        @{ Source = "distribution\README.md"; Name = "README-DISTRIBUTION.md" },
        @{ Source = "distribution\Install-TotalIgnore.bat"; Name = "Install-TotalIgnore.bat" },
        @{ Source = "distribution\Uninstall-TotalIgnore.bat"; Name = "Uninstall-TotalIgnore.bat" }
    )) {
        Copy-Item -LiteralPath (Join-Path $root $item.Source) -Destination (Join-Path $stage $item.Name)
    }

    $sourceRoot = Join-Path $stage "source"
    New-Item -ItemType Directory -Path $sourceRoot | Out-Null
    foreach ($file in @(
        "LICENSE", "README.md", "package.json", "pnpm-lock.yaml", "pnpm-workspace.yaml",
        "tsconfig.json", "eslint.config.mjs", ".editorconfig", ".gitattributes"
    )) {
        $path = Join-Path $root $file
        if (Test-Path -LiteralPath $path) {
            Copy-Item -LiteralPath $path -Destination (Join-Path $sourceRoot $file)
        }
    }

    foreach ($directory in @("src", "scripts", "packages", "patches", "themes", "browser")) {
        $path = Join-Path $root $directory
        if (Test-Path -LiteralPath $path) {
            Copy-PackageTree -SourcePath $path -DestinationPath (Join-Path $sourceRoot $directory)
        }
    }

    $distRoot = Join-Path $root "dist"
    foreach ($file in Get-ChildItem -LiteralPath $distRoot -Recurse -File) {
        if ($file.Extension -eq ".map" -or $file.Name -eq "etag.txt") {
            continue
        }

        $relative = $file.FullName.Substring($distRoot.Length).TrimStart("\")
        if ($relative -match "^(TotalIgnore-(Vencord-|Setup-|GitHub-Source-and-Release)|TotalIgnore-Publication-Repo|setup-payload|setup-assets)") {
            continue
        }

        $target = Join-Path (Join-Path $stage "dist") $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
    }

    Compress-Archive -Path $stage -DestinationPath $archive -CompressionLevel Optimal
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)
    try {
        $names = @($zip.Entries | ForEach-Object FullName)
        $required = @(
            "TotalIgnore-Vencord-1.15.9-Windows/README-DISTRIBUTION.md",
            "TotalIgnore-Vencord-1.15.9-Windows/Install-TotalIgnore.bat",
            "TotalIgnore-Vencord-1.15.9-Windows/Uninstall-TotalIgnore.bat",
            "TotalIgnore-Vencord-1.15.9-Windows/dist/Installer/VencordInstallerCli.exe",
            "TotalIgnore-Vencord-1.15.9-Windows/dist/vencordDesktopRenderer.js",
            "TotalIgnore-Vencord-1.15.9-Windows/source/src/plugins/totalIgnore/index.tsx"
        )
        $missing = @($required | Where-Object { $_ -notin $names })
        if ($missing.Count) {
            throw "Missing required bundle files: $($missing -join ', ')"
        }

        $unsafe = @($names | Where-Object {
            $_ -match "/node_modules/|\.map$|etag\.txt$|(^|/)settings\.json$|(^|/)quickCss\.css$|\.git/|TotalIgnore-Publication-Repo"
        })
        if ($unsafe.Count) {
            throw "Unexpected or private files in bundle: $($unsafe -join ', ')"
        }

        $entry = $zip.GetEntry("TotalIgnore-Vencord-1.15.9-Windows/README-DISTRIBUTION.md")
        $reader = [IO.StreamReader]::new($entry.Open())
        try {
            $readme = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
        if (!$readme.Contains("TotalIgnore-Setup-1.1.11.exe")) {
            throw "Bundle instructions do not link to the GUI setup"
        }
    } finally {
        $zip.Dispose()
    }

    Write-Output "Created: $archive"
    Write-Output "Size: $((Get-Item -LiteralPath $archive).Length) bytes"
    Write-Output "SHA-256: $((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash)"
} finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
