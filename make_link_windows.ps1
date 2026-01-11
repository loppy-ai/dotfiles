# link-config.ps1
# dotfiles 直下で実行する想定:
#   PS> .\link-config.ps1
#
# dotfiles\.config\* (ディレクトリ/ファイル) -> %USERPROFILE%\.config\* へリンクを作成する
# - ディレクトリ: symlink -> junction (/J)
# - ファイル:     symlink -> hardlink (/H, 同一ドライブのみ)

[CmdletBinding()]
param(
    # 既存があっても作り直す（通常ディレクトリ/ファイルはバックアップに退避してから作り直す）
    [switch]$Force,

    # 変更を行わず、実行予定の内容だけ表示
    [switch]$DryRun,

    # 除外したい名前（例: @("README.md", "tmp")）
    [string[]]$Exclude = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Timestamp() {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Ensure-Directory([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        if ($DryRun) {
            Write-Host "[DRYRUN] mkdir: $Path"
        } else {
            New-Item -ItemType Directory -Path $Path | Out-Null
        }
    }
}

function Is-ReparsePoint([System.IO.FileSystemInfo]$Item) {
    return (($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Same-Volume([string]$PathA, [string]$PathB) {
    $rootA = [System.IO.Path]::GetPathRoot($PathA)
    $rootB = [System.IO.Path]::GetPathRoot($PathB)
    return ($rootA -and $rootB -and ($rootA.ToLowerInvariant() -eq $rootB.ToLowerInvariant()))
}

function Run-Cmd([string]$CommandLine) {
    if ($DryRun) {
        Write-Host "[DRYRUN] cmd /c $CommandLine"
        return 0
    }
    cmd /c $CommandLine | Out-Host
    return $LASTEXITCODE
}

function Try-Create-DirSymlink([string]$Link, [string]$Target) {
    # 1) PowerShell SymbolicLink
    try {
        if ($DryRun) {
            Write-Host "[DRYRUN] New-Item -ItemType SymbolicLink -Path `"$Link`" -Target `"$Target`""
            return $true
        }
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
        return $true
    } catch {
        # fallthrough
    }

    # 2) cmd mklink /D
    $cmd = 'mklink /D "{0}" "{1}"' -f $Link, $Target
    $exit = Run-Cmd $cmd
    return ($exit -eq 0)
}

function Try-Create-Junction([string]$Link, [string]$Target) {
    $cmd = 'mklink /J "{0}" "{1}"' -f $Link, $Target
    $exit = Run-Cmd $cmd
    return ($exit -eq 0)
}

function Try-Create-FileSymlink([string]$Link, [string]$Target) {
    # 1) PowerShell SymbolicLink
    try {
        if ($DryRun) {
            Write-Host "[DRYRUN] New-Item -ItemType SymbolicLink -Path `"$Link`" -Target `"$Target`""
            return $true
        }
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
        return $true
    } catch {
        # fallthrough
    }

    # 2) cmd mklink (ファイル symlink は /D を付けない)
    $cmd = 'mklink "{0}" "{1}"' -f $Link, $Target
    $exit = Run-Cmd $cmd
    return ($exit -eq 0)
}

function Try-Create-Hardlink([string]$Link, [string]$Target) {
    # ハードリンクは同一ボリューム必須
    if (-not (Same-Volume $Link $Target)) {
        return $false
    }
    $cmd = 'mklink /H "{0}" "{1}"' -f $Link, $Target
    $exit = Run-Cmd $cmd
    return ($exit -eq 0)
}

function Backup-Or-Remove-Existing([string]$Link) {
    if (-not (Test-Path -LiteralPath $Link)) {
        return
    }

    $item = Get-Item -LiteralPath $Link -Force
    $isRp = Is-ReparsePoint $item

    if ($isRp) {
        if (-not $Force) {
            Write-Host "SKIP (already link/junction): $Link"
            throw "SKIP"  # caller handles skip
        }
        Write-Host "REMOVE (existing link/junction): $Link"
        if (-not $DryRun) {
            Remove-Item -LiteralPath $Link -Force
        }
        return
    }

    # 通常ディレクトリ/ファイル
    if (-not $Force) {
        Write-Host "SKIP (exists as normal dir/file, use -Force to backup & relink): $Link"
        throw "SKIP"
    }

    $backup = "$Link.backup-$(Get-Timestamp)"
    Write-Host "BACKUP: $Link -> $backup"
    if (-not $DryRun) {
        Move-Item -LiteralPath $Link -Destination $backup
    }
}

function Ensure-Link([System.IO.FileSystemInfo]$SourceItem, [string]$LinkRoot) {
    $name = $SourceItem.Name
    if ($Exclude -contains $name) {
        Write-Host "SKIP (excluded): $name"
        return
    }

    $target = $SourceItem.FullName
    $link = Join-Path $LinkRoot $name

    try {
        Backup-Or-Remove-Existing -Link $link
    } catch {
        if ($_.Exception.Message -eq "SKIP") {
            return
        }
        throw
    }

    if ($SourceItem.PSIsContainer) {
        # Directory
        Write-Host "LINK (dir):  $link -> $target"

        $ok = Try-Create-DirSymlink -Link $link -Target $target
        if ($ok) {
            Write-Host "OK: directory symlink created"
            return
        }

        Write-Host "WARN: directory symlink failed. Trying junction (/J)..."
        $ok2 = Try-Create-Junction -Link $link -Target $target
        if (-not $ok2) {
            throw "Failed to create both directory symlink and junction for: $link"
        }

        Write-Host "OK: junction created"
        return
    }

    # File
    Write-Host "LINK (file): $link -> $target"

    $okf = Try-Create-FileSymlink -Link $link -Target $target
    if ($okf) {
        Write-Host "OK: file symlink created"
        return
    }

    Write-Host "WARN: file symlink failed. Trying hardlink (/H)..."
    $okh = Try-Create-Hardlink -Link $link -Target $target
    if (-not $okh) {
        throw @"
Failed to link file: $link
- Tried: file symlink (PowerShell / mklink)
- Tried: hardlink (/H) but failed (maybe different drive or permissions)

Fix options:
1) Enable Windows Developer Mode (recommended) OR run PowerShell as Administrator to allow symlink creation
2) Ensure dotfiles and home are on the same drive if you want hardlink fallback
"@
    }

    Write-Host "OK: hardlink created"
}

# ---- main ----

$DotfilesRoot   = (Resolve-Path -LiteralPath $PSScriptRoot).Path
$DotConfigRoot  = Join-Path $DotfilesRoot ".config"
$HomeConfigRoot = Join-Path $HOME ".config"

Write-Host "DotfilesRoot   : $DotfilesRoot"
Write-Host "DotConfigRoot  : $DotConfigRoot"
Write-Host "HomeConfigRoot : $HomeConfigRoot"
Write-Host ""

if (-not (Test-Path -LiteralPath $DotConfigRoot)) {
    throw "dotfiles 側に .config が見つかりません: $DotConfigRoot"
}

Ensure-Directory -Path $HomeConfigRoot

# dotfiles\.config 配下の直下要素（ディレクトリ + ファイル）を対象
$items =
    Get-ChildItem -LiteralPath $DotConfigRoot -Force |
    Where-Object { -not $_.PSIsContainer -or $_.PSIsContainer } |
    Sort-Object Name

if ($items.Count -eq 0) {
    Write-Host "No items found under: $DotConfigRoot"
    exit 0
}

foreach ($it in $items) {
    # ここでは「ファイル/ディレクトリ」以外（例えば特殊）も来る可能性があるのでガード
    if (-not ($it -is [System.IO.FileSystemInfo])) {
        continue
    }
    Ensure-Link -SourceItem $it -LinkRoot $HomeConfigRoot
}

Write-Host ""
Write-Host "Done."
Write-Host "Tips:"
Write-Host "  -DryRun : 実行内容だけ確認"
Write-Host "  -Force  : 既存が通常dir/fileでも backup して作り直す"
Write-Host "  -Exclude @('foo','bar') : 除外"