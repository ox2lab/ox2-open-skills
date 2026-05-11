#!/bin/sh
set -eu

REPO_URL="https://github.com/ox2lab/ox2-open-skills.git"
INSTALL_ROOT="$(pwd)"
TARGET_DIR="$INSTALL_ROOT/.agents/skills"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$TARGET_DIR"

git clone --filter=blob:none --no-checkout "$REPO_URL" "$TMP_DIR/repo"

cd "$TMP_DIR/repo"

BRANCH="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's#refs/remotes/origin/##')"

git sparse-checkout init --cone

if [ "$#" -eq 0 ]; then
  GROUP_DIRS="$(git ls-tree -d --name-only "origin/$BRANCH" | grep -v '^\.github$')"
else
  GROUP_DIRS="$*"
fi

git sparse-checkout set $GROUP_DIRS
git checkout "$BRANCH"

for GROUP_DIR in $GROUP_DIRS; do
  if [ ! -d "$GROUP_DIR" ]; then
    echo "Error: '$GROUP_DIR' 그룹 폴더를 찾을 수 없습니다."
    exit 1
  fi

  for SKILL_DIR in "$GROUP_DIR"/*; do
    if [ -d "$SKILL_DIR" ]; then
      SKILL_NAME="$(basename "$SKILL_DIR")"

      rm -rf "$TARGET_DIR/$SKILL_NAME"
      mkdir -p "$TARGET_DIR/$SKILL_NAME"

      rsync -a "$SKILL_DIR/" "$TARGET_DIR/$SKILL_NAME/"
      echo "Installed: $SKILL_NAME"
    fi
  done
done

echo "Installed to $TARGET_DIR"
