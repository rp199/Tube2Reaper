[CmdletBinding()]
param(
    [string]$ReaperResourcePath = $(Join-Path $env:APPDATA "REAPER"),
    [switch]$SkipHelpers
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Get-ReleaseAsset(
    [string]$Repository,
    [string]$AssetName,
    [string]$Destination
) {
    $headers = @{
        "Accept" = "application/vnd.github+json"
        "User-Agent" = "Tube2Reaper-Windows-Installer"
    }
    if ($env:GITHUB_TOKEN) {
        $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN"
    }
    $release = Invoke-RestMethod `
        -Uri "https://api.github.com/repos/$Repository/releases/latest" `
        -Headers $headers
    $asset = $release.assets |
        Where-Object { $_.name -eq $AssetName } |
        Select-Object -First 1
    if ($null -eq $asset) {
        throw "Could not find $AssetName in the latest $Repository release."
    }
    Write-Host "Downloading $AssetName..."
    $downloadHeaders = @{ "User-Agent" = "Tube2Reaper-Windows-Installer" }
    Invoke-WebRequest `
        -Uri $asset.browser_download_url `
        -Headers $downloadHeaders `
        -UseBasicParsing `
        -OutFile $Destination
    $digestProperty = $asset.PSObject.Properties["digest"]
    if ($null -ne $digestProperty -and $digestProperty.Value -match "^sha256:([0-9a-fA-F]{64})$") {
        $expectedHash = $Matches[1].ToLowerInvariant()
        $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            Remove-Item -LiteralPath $Destination -Force
            throw "Checksum verification failed for $AssetName."
        }
    }
}

function Copy-ProgramFiles([string]$SourceRoot, [string]$InstallRoot) {
    New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $InstallRoot "lua") | Out-Null

    $sourceFull = [IO.Path]::GetFullPath($SourceRoot).TrimEnd("\", "/")
    $installFull = [IO.Path]::GetFullPath($InstallRoot).TrimEnd("\", "/")
    if ([string]::Equals($sourceFull, $installFull, [StringComparison]::OrdinalIgnoreCase)) {
        return
    }

    Copy-Item (Join-Path $SourceRoot "Tube2Reaper.lua") $InstallRoot -Force
    Get-ChildItem (Join-Path $SourceRoot "lua") -Filter "*.lua" -File |
        Copy-Item -Destination (Join-Path $InstallRoot "lua") -Force
    foreach ($name in @("README.md", "LICENSE")) {
        $source = Join-Path $SourceRoot $name
        if (Test-Path -LiteralPath $source) {
            Copy-Item $source $InstallRoot -Force
        }
    }
}

function Test-Helper([string]$Path, [string[]]$Arguments) {
    $output = @(& $Path @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $output | Select-Object -First 1 | Write-Host
    if ($exitCode -ne 0) {
        throw "Helper validation failed: $Path"
    }
}

if ([string]::IsNullOrWhiteSpace($ReaperResourcePath)) {
    throw "REAPER's resource path could not be determined."
}

$sourceRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$installRoot = Join-Path $ReaperResourcePath "Scripts\Tube2Reaper"
$binRoot = Join-Path $installRoot "bin"

Write-Step "Installing Tube2Reaper"
Copy-ProgramFiles $sourceRoot $installRoot
New-Item -ItemType Directory -Force -Path $binRoot | Out-Null

if (-not $SkipHelpers) {
    $nativeArchitecture = if ($env:PROCESSOR_ARCHITEW6432) {
        $env:PROCESSOR_ARCHITEW6432
    } else {
        $env:PROCESSOR_ARCHITECTURE
    }
    if ($nativeArchitecture -eq "ARM64") {
        $ytDlpAsset = "yt-dlp_arm64.exe"
        $denoAsset = "deno-aarch64-pc-windows-msvc.zip"
        $ffmpegAsset = "ffmpeg-master-latest-winarm64-gpl.zip"
    } elseif ($nativeArchitecture -eq "AMD64") {
        $ytDlpAsset = "yt-dlp.exe"
        $denoAsset = "deno-x86_64-pc-windows-msvc.zip"
        $ffmpegAsset = "ffmpeg-master-latest-win64-gpl.zip"
    } else {
        throw "Unsupported Windows architecture: $nativeArchitecture. Use 64-bit Windows on x64 or ARM64."
    }

    $temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) `
        ("Tube2Reaper-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $temporaryRoot | Out-Null
    $stagedBin = Join-Path $temporaryRoot "bin"
    New-Item -ItemType Directory -Force -Path $stagedBin | Out-Null
    try {
        Write-Step "Downloading YouTube helpers for $nativeArchitecture"

        $ytDlpDownload = Join-Path $temporaryRoot $ytDlpAsset
        Get-ReleaseAsset "yt-dlp/yt-dlp" $ytDlpAsset $ytDlpDownload
        Copy-Item $ytDlpDownload (Join-Path $stagedBin "yt-dlp.exe") -Force

        $denoDownload = Join-Path $temporaryRoot $denoAsset
        $denoExpanded = Join-Path $temporaryRoot "deno"
        Get-ReleaseAsset "denoland/deno" $denoAsset $denoDownload
        Expand-Archive -LiteralPath $denoDownload -DestinationPath $denoExpanded -Force
        $denoProgram = Get-ChildItem $denoExpanded -Filter "deno.exe" -Recurse -File |
            Select-Object -First 1
        if ($null -eq $denoProgram) { throw "deno.exe was not found in $denoAsset." }
        Copy-Item $denoProgram.FullName (Join-Path $stagedBin "deno.exe") -Force

        $ffmpegDownload = Join-Path $temporaryRoot $ffmpegAsset
        $ffmpegExpanded = Join-Path $temporaryRoot "ffmpeg"
        Get-ReleaseAsset "BtbN/FFmpeg-Builds" $ffmpegAsset $ffmpegDownload
        Expand-Archive -LiteralPath $ffmpegDownload -DestinationPath $ffmpegExpanded -Force
        foreach ($programName in @("ffmpeg.exe", "ffprobe.exe")) {
            $program = Get-ChildItem $ffmpegExpanded -Filter $programName -Recurse -File |
                Select-Object -First 1
            if ($null -eq $program) { throw "$programName was not found in $ffmpegAsset." }
            Copy-Item $program.FullName (Join-Path $stagedBin $programName) -Force
        }

        Write-Step "Checking helpers"
        Test-Helper (Join-Path $stagedBin "yt-dlp.exe") @("--version")
        Test-Helper (Join-Path $stagedBin "deno.exe") @("--version")
        Test-Helper (Join-Path $stagedBin "ffmpeg.exe") @("-version")
        Get-ChildItem $stagedBin -File | Copy-Item -Destination $binRoot -Force
    } finally {
        if (Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }

}

Write-Host "`nTube2Reaper is installed at:" -ForegroundColor Green
Write-Host $installRoot
Write-Host "`nIn REAPER, open Actions > Show action list, choose Load ReaScript,"
Write-Host "and select Tube2Reaper.lua from that folder."
