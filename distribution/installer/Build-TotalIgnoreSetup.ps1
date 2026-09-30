$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$releaseZip = Join-Path $root "dist\TotalIgnore-Vencord-1.15.9-Windows.zip"
$payloadRoot = Join-Path $root "dist\setup-payload"
$assetRoot = Join-Path $root "dist\setup-assets"
$payload = Join-Path $payloadRoot "TotalIgnore-Vencord-1.15.9-Windows"
$output = Join-Path $root "dist\TotalIgnore-Setup-1.1.12.exe"
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
        $iconPath = Join-Path $assetRoot "TotalIgnore.ico"
        $iconSizes = @(16, 24, 32, 48, 64, 128, 256)
        $iconFrames = [System.Collections.Generic.List[byte[]]]::new()
        foreach ($size in $iconSizes) {
            $frame = [System.Drawing.Bitmap]::new(
                $size,
                $size,
                [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
            )
            try {
                $frameGraphics = [System.Drawing.Graphics]::FromImage($frame)
                try {
                    $frameGraphics.Clear([System.Drawing.Color]::Transparent)
                    $frameGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $frameGraphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $frameGraphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $frameGraphics.DrawImage($original, 0, 0, $size, $size)

                    $rectangle = [System.Drawing.Rectangle]::new(0, 0, $size, $size)
                    $bitmapData = $frame.LockBits(
                        $rectangle,
                        [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
                    )
                    $frameStream = [System.IO.MemoryStream]::new()
                    $frameWriter = [System.IO.BinaryWriter]::new($frameStream)
                    try {
                        $andMaskStride = [int]([Math]::Ceiling($size / 32.0) * 4)
                        $pixelDataLength = $size * $size * 4
                        $maskDataLength = $andMaskStride * $size

                        $frameWriter.Write([UInt32]40)
                        $frameWriter.Write([Int32]$size)
                        $frameWriter.Write([Int32]($size * 2))
                        $frameWriter.Write([UInt16]1)
                        $frameWriter.Write([UInt16]32)
                        $frameWriter.Write([UInt32]0)
                        $frameWriter.Write([UInt32]($pixelDataLength + $maskDataLength))
                        $frameWriter.Write([Int32]0)
                        $frameWriter.Write([Int32]0)
                        $frameWriter.Write([UInt32]0)
                        $frameWriter.Write([UInt32]0)

                        $row = [byte[]]::new($size * 4)
                        for ($y = $size - 1; $y -ge 0; $y--) {
                            $rowAddress = [IntPtr]::Add($bitmapData.Scan0, $y * $bitmapData.Stride)
                            [System.Runtime.InteropServices.Marshal]::Copy($rowAddress, $row, 0, $row.Length)
                            $frameWriter.Write($row)
                        }

                        $frameWriter.Write([byte[]]::new($maskDataLength))
                        $frameWriter.Flush()
                        $iconFrames.Add($frameStream.ToArray())
                    } finally {
                        $frameWriter.Dispose()
                        $frameStream.Dispose()
                        $frame.UnlockBits($bitmapData)
                    }
                } finally {
                    $frameGraphics.Dispose()
                }
            } finally {
                $frame.Dispose()
            }
        }

        $iconStream = [System.IO.File]::Create($iconPath)
        $writer = [System.IO.BinaryWriter]::new($iconStream)
        try {
            $writer.Write([UInt16]0)
            $writer.Write([UInt16]1)
            $writer.Write([UInt16]$iconFrames.Count)

            $imageOffset = 6 + (16 * $iconFrames.Count)
            for ($index = 0; $index -lt $iconFrames.Count; $index++) {
                $size = $iconSizes[$index]
                $frameBytes = $iconFrames[$index]
                $dimension = if ($size -eq 256) { [byte]0 } else { [byte]$size }
                $writer.Write($dimension)
                $writer.Write($dimension)
                $writer.Write([byte]0)
                $writer.Write([byte]0)
                $writer.Write([UInt16]1)
                $writer.Write([UInt16]32)
                $writer.Write([UInt32]$frameBytes.Length)
                $writer.Write([UInt32]$imageOffset)
                $imageOffset += $frameBytes.Length
            }

            foreach ($frameBytes in $iconFrames) {
                $writer.Write($frameBytes)
            }
        } finally {
            $writer.Dispose()
            $iconStream.Dispose()
        }

        $iconBytes = [System.IO.File]::ReadAllBytes($iconPath)
        $expectedIconBytes = 6 + (16 * $iconSizes.Count) + (($iconFrames | ForEach-Object Length | Measure-Object -Sum).Sum)
        if ($iconBytes.Length -ne $expectedIconBytes) {
            throw "Generated icon has an invalid length: $($iconBytes.Length)"
        }
        if ([BitConverter]::ToUInt16($iconBytes, 0) -ne 0 -or
            [BitConverter]::ToUInt16($iconBytes, 2) -ne 1 -or
            [BitConverter]::ToUInt16($iconBytes, 4) -ne $iconSizes.Count) {
            throw "Generated icon header is invalid"
        }
        for ($index = 0; $index -lt $iconSizes.Count; $index++) {
            $entryOffset = 6 + (16 * $index)
            $expectedDimension = if ($iconSizes[$index] -eq 256) { 0 } else { $iconSizes[$index] }
            if ($iconBytes[$entryOffset] -ne $expectedDimension -or
                $iconBytes[$entryOffset + 1] -ne $expectedDimension) {
                throw "Generated icon frame $index has invalid dimensions"
            }

            $frameOffset = [BitConverter]::ToUInt32($iconBytes, $entryOffset + 12)
            $headerSize = [BitConverter]::ToUInt32($iconBytes, $frameOffset)
            $frameWidth = [BitConverter]::ToInt32($iconBytes, $frameOffset + 4)
            $frameHeight = [BitConverter]::ToInt32($iconBytes, $frameOffset + 8)
            if ($headerSize -ne 40 -or
                $frameWidth -ne $iconSizes[$index] -or
                $frameHeight -ne ($iconSizes[$index] * 2)) {
                throw "Generated icon frame $index has invalid bitmap data"
            }
        }

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
