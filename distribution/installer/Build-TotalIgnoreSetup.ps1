$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$releaseZip = Join-Path $root "dist\TotalIgnore-Vencord-1.15.9-Windows.zip"
$payloadRoot = Join-Path $root "dist\setup-payload"
$assetRoot = Join-Path $root "dist\setup-assets"
$payload = Join-Path $payloadRoot "TotalIgnore-Vencord-1.15.9-Windows"
$output = Join-Path $root "dist\TotalIgnore-Setup-1.1.0.exe"
$compiler = Join-Path $env:LOCALAPPDATA "Programs\Inno Setup 6\ISCC.exe"
$avatarPath = Join-Path $root "src\plugins\totalIgnore\avatar.png"

if (!(Test-Path -LiteralPath $releaseZip)) {
    throw "The current Windows release package is missing: $releaseZip"
}
if (!(Test-Path -LiteralPath $compiler)) {
    throw "Inno Setup compiler is missing: $compiler"
}
if (!(Test-Path -LiteralPath $avatarPath)) {
    throw "The publisher avatar is missing: $avatarPath"
}

$packageHash = (Get-FileHash -LiteralPath $releaseZip -Algorithm SHA256).Hash

foreach ($temporaryPath in @($payloadRoot, $assetRoot)) {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Recurse -Force
    }
}

try {
    New-Item -ItemType Directory -Path $payloadRoot, $assetRoot -Force | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($releaseZip, $payloadRoot)

    foreach ($requiredFile in @(
        "dist\Installer\VencordInstallerCli.exe",
        "dist\patcher.js",
        "dist\vencordDesktopRenderer.js",
        "source\src\plugins\totalIgnore\index.tsx",
        "source\src\plugins\totalIgnore\avatar.png",
        "source\LICENSE"
    )) {
        $path = Join-Path $payload $requiredFile
        if (!(Test-Path -LiteralPath $path)) {
            throw "Release payload is incomplete; missing $requiredFile"
        }
    }

    Add-Type -AssemblyName System.Drawing
    $original = [System.Drawing.Image]::FromFile($avatarPath)
    try {
        $avatar = [System.Drawing.Bitmap]::new(192, 192, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($avatar)
            try {
                $graphics.Clear([System.Drawing.Color]::Transparent)
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $scale = [Math]::Min(192.0 / $original.Width, 192.0 / $original.Height)
                $width = [int][Math]::Round($original.Width * $scale)
                $height = [int][Math]::Round($original.Height * $scale)
                $graphics.DrawImage($original, [int]((192 - $width) / 2), [int]((192 - $height) / 2), $width, $height)
            } finally {
                $graphics.Dispose()
            }

            $iconPath = Join-Path $assetRoot "TotalIgnore.ico"
            $iconStream = [System.IO.File]::Create($iconPath)
            try {
                $bitmap = [System.Drawing.Bitmap]::new($avatar, 256, 256)
                try {
                    $icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())
                    try {
                        $icon.Save($iconStream)
                    } finally {
                        $icon.Dispose()
                    }
                } finally {
                    $bitmap.Dispose()
                }
            } finally {
                $iconStream.Dispose()
            }

            $sidePath = Join-Path $assetRoot "WizardSide.bmp"
            $side = [System.Drawing.Bitmap]::new(164, 314, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            try {
                $sideGraphics = [System.Drawing.Graphics]::FromImage($side)
                try {
                    $sideGraphics.Clear([System.Drawing.Color]::FromArgb(14, 19, 35))
                    $sideGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $sideGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(21, 30, 54))
                    try {
                        $sideGraphics.FillEllipse($brush, -68, 26, 290, 290)
                    } finally {
                        $brush.Dispose()
                    }
                    $sideGraphics.DrawImage($avatar, 12, 92, 140, 140)
                    $font = [System.Drawing.Font]::new("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                    $creditBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
                    try {
                        $sideGraphics.DrawString("TOTALIGNORE", $font, $creditBrush, 16, 252)
                    } finally {
                        $creditBrush.Dispose()
                        $font.Dispose()
                    }
                    $smallFont = [System.Drawing.Font]::new("Segoe UI", 7, [System.Drawing.FontStyle]::Regular)
                    $mutedBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(184, 197, 220))
                    try {
                        $sideGraphics.DrawString("by Dr. Avinash Mandre", $smallFont, $mutedBrush, 16, 273)
                    } finally {
                        $mutedBrush.Dispose()
                        $smallFont.Dispose()
                    }
                } finally {
                    $sideGraphics.Dispose()
                }
                $side.Save($sidePath, [System.Drawing.Imaging.ImageFormat]::Bmp)
            } finally {
                $side.Dispose()
            }

            $smallPath = Join-Path $assetRoot "WizardSmall.bmp"
            $small = [System.Drawing.Bitmap]::new(55, 55, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            try {
                $smallGraphics = [System.Drawing.Graphics]::FromImage($small)
                try {
                    $smallGraphics.Clear([System.Drawing.Color]::FromArgb(14, 19, 35))
                    $smallGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
                    $smallGraphics.DrawImage($avatar, 2, 2, 51, 51)
                } finally {
                    $smallGraphics.Dispose()
                }
                $small.Save($smallPath, [System.Drawing.Imaging.ImageFormat]::Bmp)
            } finally {
                $small.Dispose()
            }
        } finally {
            $avatar.Dispose()
        }
    } finally {
        $original.Dispose()
    }

    & $compiler (Join-Path $PSScriptRoot "TotalIgnore.iss")
    if ($LASTEXITCODE -ne 0) {
        throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
    }

    if (!(Test-Path -LiteralPath $output)) {
        throw "Installer was not generated: $output"
    }

    Write-Output "Created: $output"
    Write-Output "Size: $((Get-Item -LiteralPath $output).Length) bytes"
    Write-Output "SHA-256: $((Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash)"
    Write-Output "Embedded Windows ZIP SHA-256: $packageHash"
} finally {
    foreach ($temporaryPath in @($payloadRoot, $assetRoot)) {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force
        }
    }
}
