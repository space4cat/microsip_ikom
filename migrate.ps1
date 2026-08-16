$ErrorActionPreference = 'Stop'

# Directory of this script = portable MicroSIP folder
$root = Split-Path -Parent $MyInvocation.MyCommand.Definition
$portableIni = Join-Path $root 'microsip.ini'

# URL of the control numbers list (same as shipped microsip.ini)
$attentionUrl = 'http://10.100.0.6/microsip_webmn/list.php?token=1cuHYWykcErRbmGvGzARzQwLbsRANdRYEbZ8qGiI9B7Nj0zRNlHJqe4vtMISVk9x'

Write-Host '== MicroSIP portable: migrate settings =='
Write-Host ("Target folder: " + $root)

# --- 1. Locate installed MicroSIP.ini ---
# Possible locations (MicroSIP settings.cpp Init):
#   - installer mode: %APPDATA%\MicroSIP\MicroSIP.ini
#   - legacy:         %LOCALAPPDATA%\MicroSIP\MicroSIP.ini (moved to Roaming on run)
#   - portable:       MicroSIP.ini next to the exe (any folder)
#   - install dir:    registry HKCU\Software\MicroSIP / HKLM\Software\MicroSIP (default value)
$iniCandidates = @()

if ($env:APPDATA) {
    $iniCandidates += (Join-Path $env:APPDATA 'MicroSIP\MicroSIP.ini')
}
if ($env:LOCALAPPDATA) {
    $iniCandidates += (Join-Path $env:LOCALAPPDATA 'MicroSIP\MicroSIP.ini')
}

# install dir from registry (default value of the key)
foreach ($hive in 'HKCU:\Software\MicroSIP', 'HKLM:\Software\MicroSIP') {
    if (Test-Path -LiteralPath $hive) {
        $installPath = (Get-ItemProperty -LiteralPath $hive -ErrorAction SilentlyContinue).'(default)'
        if ($installPath) {
            $iniCandidates += (Join-Path $installPath 'MicroSIP.ini')
        }
    }
}

# common portable locations
if ($env:USERPROFILE) {
    $iniCandidates += (Join-Path $env:USERPROFILE 'Desktop\MicroSIP\microsip.ini')
    $iniCandidates += (Join-Path $env:USERPROFILE 'Documents\MicroSIP\microsip.ini')
}
if ($env:ProgramFiles) { $iniCandidates += (Join-Path $env:ProgramFiles 'MicroSIP\MicroSIP.ini') }
if (${env:ProgramFiles(x86)}) { $iniCandidates += (Join-Path ${env:ProgramFiles(x86)} 'MicroSIP\MicroSIP.ini') }

# other user profiles (Vista and later)
$profileRoot = if ($env:SystemDrive) { Join-Path $env:SystemDrive 'Users' } else { 'C:\Users' }
if (Test-Path -LiteralPath $profileRoot) {
    Get-ChildItem -LiteralPath $profileRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $iniCandidates += (Join-Path $_.FullName 'AppData\Roaming\MicroSIP\MicroSIP.ini')
        $iniCandidates += (Join-Path $_.FullName 'AppData\Local\MicroSIP\MicroSIP.ini')
    }
}

$installedIni = $iniCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

if ($installedIni) {
    Copy-Item -LiteralPath $installedIni -Destination $portableIni -Force
    Write-Host "[OK] Copied settings from: $installedIni"
} else {
    Write-Host '[!] Installed MicroSIP settings not found.' -ForegroundColor Yellow
    if (-not (Test-Path -LiteralPath $portableIni)) {
        Set-Content -LiteralPath $portableIni -Value "[Settings]`r`n" -Encoding Ascii
    }
}

if (-not (Test-Path -LiteralPath $portableIni)) {
    Write-Host '[X] No microsip.ini to patch. Aborting.' -ForegroundColor Red
    exit 1
}

# --- 2. Detect encoding and patch [Settings] ---
function Get-IniEncoding([string]$path, [ref]$startIndex) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $startIndex.Value = 2
        return (New-Object System.Text.UnicodeEncoding($false, $true))   # UTF-16 LE with BOM
    }
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $startIndex.Value = 3
        return (New-Object System.Text.UTF8Encoding($true))              # UTF-8 with BOM
    }
    $startIndex.Value = 0
    return (New-Object System.Text.UTF8Encoding($false))                 # ANSI/UTF-8 without BOM
}

$skip = 0
$encoding = Get-IniEncoding -path $portableIni -startIndex ([ref]$skip)
$raw = [System.IO.File]::ReadAllBytes($portableIni)
$text = $encoding.GetString($raw, $skip, $raw.Length - $skip)
$lines = [regex]::Split($text, "\r?\n")

$section = ''
$settingsStart = -1
$settingsEnd = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    $m = [regex]::Match($lines[$i], '^\s*\[([^\]]+)\]\s*$')
    if ($m.Success) {
        $section = $m.Groups[1].Value.Trim()
        if ($section -eq 'Settings' -and $settingsStart -lt 0) {
            $settingsStart = $i
        } elseif ($settingsStart -ge 0 -and $settingsEnd -lt 0) {
            $settingsEnd = $i
            break
        }
    }
}

$keys = @{
    'attentionNumbersUrl' = $attentionUrl
    'attentionNumbersRefresh' = '60'
}
$found = @{}
$lowerToOrig = @{}
foreach ($k in $keys.Keys) { $lowerToOrig[$k.ToLowerInvariant()] = $k }

if ($settingsStart -ge 0) {
    $rangeEnd = if ($settingsEnd -lt 0) { $lines.Count } else { $settingsEnd }
    for ($i = $settingsStart; $i -lt $rangeEnd; $i++) {
        foreach ($lk in $lowerToOrig.Keys) {
            $m = [regex]::Match($lines[$i], '^\s*' + [regex]::Escape($lk) + '\s*=')
            if ($m.Success) {
                $orig = $lowerToOrig[$lk]
                $lines[$i] = $orig + '=' + $keys[$orig]
                $found[$orig] = $true
            }
        }
    }
}

$result = New-Object System.Collections.Generic.List[string]
if ($settingsStart -ge 0) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $result.Add($lines[$i])
        if ($i -eq $settingsStart) {
            foreach ($k in $keys.Keys) {
                if (-not $found.ContainsKey($k)) {
                    $result.Add($k + '=' + $keys[$k])
                }
            }
        }
    }
} else {
    foreach ($line in $lines) { $result.Add($line) }
    $result.Add('[Settings]')
    foreach ($k in $keys.Keys) { $result.Add($k + '=' + $keys[$k]) }
}

$newText = ($result -join "`r`n") + "`r`n"
[System.IO.File]::WriteAllText($portableIni, $newText, $encoding)
Write-Host '[OK] microsip.ini patched: attentionNumbersUrl + attentionNumbersRefresh added, all accounts and settings preserved.'

# --- 3. Copy sound files (.wav) from the installed MicroSIP ---
$soundDirs = @()
if ($installedIni) {
    $soundDirs += (Split-Path -Parent $installedIni)
}
if ($env:LOCALAPPDATA) { $soundDirs += (Join-Path $env:LOCALAPPDATA 'MicroSIP') }
if ($env:ProgramFiles) { $soundDirs += (Join-Path $env:ProgramFiles 'MicroSIP') }
if (${env:ProgramFiles(x86)}) { $soundDirs += (Join-Path ${env:ProgramFiles(x86)} 'MicroSIP') }
if ($env:ProgramW6432) { $soundDirs += (Join-Path $env:ProgramW6432 'MicroSIP') }

$copied = 0
$seen = @{}
foreach ($d in $soundDirs) {
    if (-not $d -or $seen.ContainsKey($d.ToLowerInvariant())) { continue }
    $seen[$d.ToLowerInvariant()] = $true
    if (Test-Path -LiteralPath $d) {
        $wavs = Get-ChildItem -LiteralPath $d -Filter *.wav -File -ErrorAction SilentlyContinue
        foreach ($w in $wavs) {
            Copy-Item -LiteralPath $w.FullName -Destination (Join-Path $root $w.Name) -Force
            $copied++
        }
        if ($wavs) {
            Write-Host ("[OK] Sounds copied from: " + $d)
            break
        }
    }
}
if ($copied -eq 0) {
    Write-Host '[!] No sound files found to copy.' -ForegroundColor Yellow
}

Write-Host 'Done.'
