#!/bin/bash
#
# awesome-claude-skills セットアップスクリプト
# 対応OS: WSL2, Linux, macOS
#

set -e

SKILLS_DIR="${HOME}/.claude/skills"
AWESOME_REPO="https://github.com/anthropics/awesome-claude-skills.git"
AWESOME_DIR="${SKILLS_DIR}/awesome-claude-skills"

echo "=== awesome-claude-skills セットアップ ==="
echo ""

# スキルディレクトリ作成
if [ ! -d "$SKILLS_DIR" ]; then
    echo "Creating skills directory: $SKILLS_DIR"
    mkdir -p "$SKILLS_DIR"
fi

cd "$SKILLS_DIR"

# リポジトリクローン
if [ ! -d "$AWESOME_DIR" ]; then
    echo "Cloning awesome-claude-skills..."
    git clone "$AWESOME_REPO"
else
    echo "awesome-claude-skills already exists. Updating..."
    cd "$AWESOME_DIR"
    git pull origin main
    cd "$SKILLS_DIR"
fi

# シンボリックリンク作成
echo ""
echo "Creating symbolic links..."

created=0
skipped=0

for skill in awesome-claude-skills/*/; do
    skill_name=$(basename "$skill")

    # 隠しディレクトリや特殊ディレクトリをスキップ
    if [[ "$skill_name" == .* ]]; then
        continue
    fi

    if [ -e "$skill_name" ]; then
        echo "  [SKIP] $skill_name (already exists)"
        ((skipped++))
    else
        ln -s "awesome-claude-skills/$skill_name" "$skill_name"
        echo "  [OK]   $skill_name"
        ((created++))
    fi
done

echo ""
echo "=== 完了 ==="
echo "作成したリンク: $created"
echo "スキップ: $skipped"
echo ""
echo "インストールされたスキル:"
ls -la "$SKILLS_DIR" | grep "^l" | awk '{print "  " $9 " -> " $11}'
