#!/usr/bin/env python3
"""Keep eastack-mode on for the rest of a Claude Code thread.

A UserPromptSubmit hook. A prompt with `/eastack-mode` turns the mode on and
"eastack-mode off" turns it off. While it is on, every prompt carries a
one-line reminder, the job pstack's `reminder:` field does in Cursor.

The state comes from the user's own prompts on the thread's active branch,
which the transcript links through `parentUuid`. A fork copies that branch, so
it keeps the mode. Claude Code writes the new prompt only after this hook runs,
so the first prompt after a rewind still reads the branch it left.
"""
import json
import re
import sys
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent / "skills" / "eastack-mode" / "SKILL.md"
COMMAND_TAG = re.compile(r"</?command-(?:message|name|args)>")
ON = re.compile(r"(?:^|\s)/eastack-mode(?=\s|$)")
OFF = re.compile(r"(?:^|\s)/?eastack-mode\s+off\b", re.IGNORECASE)


def command(text):
    # Claude Code stores `/eastack-mode off` as tagged parts, so tags become spaces.
    text = COMMAND_TAG.sub(" ", text)
    if OFF.search(text):
        return "off"
    if ON.search(text):
        return "on"
    return None


def prompt_text(entry):
    # Skill bodies and leading text are meta entries; compaction summaries quote old prompts.
    if entry.get("type") != "user" or entry.get("isMeta") or entry.get("isCompactSummary"):
        return None
    content = (entry.get("message") or {}).get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        texts = [block.get("text", "") for block in content if isinstance(block, dict) and block.get("type") == "text"]
        return "\n".join(texts) if texts else None
    return None


def branch_state(transcript):
    parents, commands, head = {}, {}, None
    try:
        with open(transcript, encoding="utf-8") as lines:
            for line in lines:
                try:
                    entry = json.loads(line)
                except ValueError:
                    continue
                uuid = entry.get("uuid")
                if not uuid or entry.get("isSidechain"):
                    continue
                parents[uuid] = entry.get("parentUuid") or entry.get("logicalParentUuid")
                text = prompt_text(entry)
                if text is not None:
                    commands[uuid] = command(text)
                head = uuid
    except (OSError, TypeError):
        return None
    seen = set()
    while head and head not in seen:
        seen.add(head)
        if commands.get(head):
            return commands[head]
        head = parents.get(head)
    return None


event = json.load(sys.stdin)
current = command(event.get("prompt") or "")

if current == "off":
    context = "eastack-mode is off for this thread. Stop applying it, including any instructions this message loaded."
elif current == "on" or branch_state(event.get("transcript_path")) == "on":
    context = (
        "eastack-mode is on for this thread. New task? If it matches a playbook or needs rigor, apply eastack-mode. "
        f"If the turn is casual or the user opts out, don't. If its instructions have left your context, read {SKILL}."
    )
else:
    sys.exit(0)

json.dump({"hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": context}}, sys.stdout)
