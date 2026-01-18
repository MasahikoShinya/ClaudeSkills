#Requires -RunAsAdministrator
#
# awesome-claude-skills セットアップスクリプト (Windows)
# 管理者権限で実行してください
#

$ErrorActionPreference = "Stop"

$SkillsDir = "$env:USERPROFILE\.claude\skills"
$AwesomeRepo = "https://github.com/anthropics/awesome-claude-skills.git"
$AwesomeDir = "$SkillsDir\awesome-claude-skills"

Write-Host "=== awesome-claude-skills セットアップ ===" -ForegroundColor Cyan
Write-Host ""

# スキルディレクトリ作成
if (-not (Test-Path $SkillsDir)) {
    Write-Host "Creating skills directory: $SkillsDir"
    New-Item -ItemType Directory -Force -Path $SkillsDir | Out-Null
}

Set-Location $SkillsDir

# リポジトリクローン
if (-not (Test-Path $AwesomeDir)) {
    Write-Host "Cloning awesome-claude-skills..."
    git clone $AwesomeRepo
} else {
    Write-Host "awesome-claude-skills already exists. Updating..."
    Set-Location $AwesomeDir
    git pull origin main
    Set-Location $SkillsDir
}

# シンボリックリンク作成
Write-Host ""
Write-Host "Creating symbolic links..."

$created = 0
$skipped = 0

Get-ChildItem -Path "awesome-claude-skills" -Directory | ForEach-Object {
    $skillName = $_.Name
    $targetPath = "awesome-claude-skills\$skillName"
    $linkPath = "$SkillsDir\$skillName"

    # 隠しディレクトリをスキップ
    if ($skillName.StartsWith(".")) {
        return
    }

    if (Test-Path $linkPath) {
        Write-Host "  [SKIP] $skillName (already exists)" -ForegroundColor Yellow
        $skipped++
    } else {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $targetPath | Out-Null
        Write-Host "  [OK]   $skillName" -ForegroundColor Green
        $created++
    }
}

Write-Host ""
Write-Host "=== 完了 ===" -ForegroundColor Cyan
Write-Host "作成したリンク: $created"
Write-Host "スキップ: $skipped"
Write-Host ""
Write-Host "インストールされたスキル:"
Get-ChildItem -Path $SkillsDir | Where-Object { $_.LinkType -eq "SymbolicLink" } | ForEach-Object {
    Write-Host "  $($_.Name) -> $($_.Target)"
}
