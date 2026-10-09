#!/usr/bin/env bash
# Install eastack-t3 skills: each one linked into .agents/skills, where T3 Code
# and Codex read skills, and mirrored into .claude/skills for Claude Code.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="${HOME}"

if [[ "${1:-}" == "--project" ]]; then
  BASE="$(cd "${2:?usage: ./install.sh --project /path/to/repo}" && pwd)"
fi

mkdir -p "$BASE/.agents/skills" "$BASE/.claude/skills"
installed=0
skipped=0

# Point LINK at TARGET, replacing a symlink there and refusing anything else.
link() {
  local target="$1" link="$2"
  if [[ -L "$link" ]]; then
    rm "$link"
  elif [[ -e "$link" ]]; then
    printf 'skip %s (exists and is not a symlink)\n' "$link"
    skipped=$((skipped + 1))
    return 1
  fi
  ln -s "$target" "$link"
}

for skill in "$ROOT"/skills/*/; do
  name="$(basename "$skill")"
  link "$ROOT/skills/$name" "$BASE/.agents/skills/$name" || continue
  link "../../.agents/skills/$name" "$BASE/.claude/skills/$name" || continue
  installed=$((installed + 1))
done

printf 'linked %d skills into %s/.agents/skills and %s/.claude/skills' "$installed" "$BASE" "$BASE"
if [[ "$skipped" -gt 0 ]]; then
  printf ' (%d skipped)' "$skipped"
fi
printf '\n'
