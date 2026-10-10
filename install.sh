#!/usr/bin/env bash
# Install eastack skills: each one linked into .agents/skills, where T3 Code
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

# Register hooks/eastack-mode.py as a UserPromptSubmit hook, replacing an
# earlier registration so a moved clone leaves no stale path behind.
python3 - "$BASE/.claude/settings.json" "python3 \"$ROOT/hooks/eastack-mode.py\"" <<'PY'
import json
import sys
from pathlib import Path

path, command = Path(sys.argv[1]), sys.argv[2]
settings = json.loads(path.read_text()) if path.exists() else {}
groups = settings.setdefault("hooks", {}).setdefault("UserPromptSubmit", [])
for group in groups:
    group["hooks"] = [h for h in group.get("hooks", []) if not h.get("command", "").endswith('hooks/eastack-mode.py"')]
groups[:] = [group for group in groups if group["hooks"]]
groups.append({"hooks": [{"type": "command", "command": command}]})
path.write_text(json.dumps(settings, indent=2, ensure_ascii=False) + "\n")
print(f"registered the eastack-mode hook in {path}")
PY
