#!/usr/bin/env bash
# Tests for worktree-audit.sh's differences from upstream (drift rows D-X1,
# D-X2, D-X7). Builds a throwaway repo and T3 state database in a temporary
# directory, runs the audit against them, checks each worktree's bucket, and
# deletes everything it created.
#
# Usage: bash worktree-audit.test.sh
#   AUDIT=<path> tests another copy of the audit, such as upstream's.
set -u

audit="${AUDIT:-$(cd "$(dirname "$0")" && pwd)/worktree-audit.sh}"
tmp=$(cd -P "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$tmp"' EXIT

# Isolate git, gh and T3 from the user's config, account and threads. The
# audit reads the database at its default path under this HOME.
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
mkdir -p "$HOME/.t3/userdata" "$tmp/bin"
printf '#!/bin/sh\necho "[]"\n' > "$tmp/bin/gh"
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH"
db="$HOME/.t3/userdata/statev2.sqlite"

fail=0
pass=0

repo="$tmp/repo"
wts="$tmp/wt"
git init -q --bare -b main "$tmp/origin.git"
git init -q -b main "$repo"
echo base > "$repo/file"
git -C "$repo" add file
git -C "$repo" commit -q -m base
git -C "$repo" remote add origin "$tmp/origin.git"
git -C "$repo" push -q origin main
mkdir -p "$wts"

# Every worktree starts clean, merged and without a remote branch, so the
# signal under test decides its bucket.
for name in clean-merged recent recent-sub sibling deleted pinned "wip space"; do
	git -C "$repo" worktree add -q -b "${name// /-}" "$wts/$name" main
done
# D-X7: tracked edits in a worktree whose path holds a space.
echo edit >> "$wts/wip space/file"

# thread <worktreePath> <age: now|old> <pinned: yes|no> [deleted]
sqlite3 "$db" "create table orchestration_v2_projection_threads (
	thread_id text primary key, updated_at text not null, deleted_at text, payload_json text not null)"
n=0
thread() {
	n=$((n + 1))
	path=$(printf '%s' "$1" | sed "s/'/''/g")
	[ "$2" = now ] && mod="'-1 hours'" || mod="'-30 days'"
	[ "$3" = yes ] && pin="strftime('%Y-%m-%dT%H:%M:%fZ', 'now')" || pin="null"
	[ "${4:-}" = deleted ] && del="strftime('%Y-%m-%dT%H:%M:%fZ', 'now')" || del="null"
	sqlite3 "$db" "insert into orchestration_v2_projection_threads values ('t$n',
		strftime('%Y-%m-%dT%H:%M:%fZ', 'now', $mod), $del, json_object('worktreePath', '$path', 'pinnedAt', $pin))"
}
thread "$wts/recent" now no
thread "$wts/recent-sub/ui" now no
thread "$wts/sibling-r37" now no
thread "$wts/deleted" now no deleted
thread "$wts/pinned" old yes

# expect <label> <worktree path> <bucket>
expect() {
	got=$(awk -F'\t' -v p="$2" '$NF == p { print $(NF - 1) }' "$tmp/out")
	if [ "$got" = "$3" ]; then
		pass=$((pass + 1)); echo "ok   $1: $3"
	else
		fail=$((fail + 1)); echo "FAIL $1: want $3, got ${got:-<no row>}"
	fi
}

run() { bash "$audit" -b origin/main "$repo" > "$tmp/out" 2> "$tmp/err"; }

run
expect "clean merged worktree" "$wts/clean-merged" safe
expect "D-X1: recent T3 thread" "$wts/recent" verify-recent-thread
expect "D-X1: recent thread bound under the worktree" "$wts/recent-sub" verify-recent-thread
expect "D-X1: thread bound to a longer sibling name" "$wts/sibling" safe
expect "D-X1: deleted thread" "$wts/deleted" safe
expect "D-X2: pinned thread" "$wts/pinned" hold-pinned
expect "D-X7: tracked edits in a path with a space" "$wts/wip space" hold-wip

# D-X1: an unreadable database warns and shows no thread, as upstream does
# without a transcripts directory.
mv "$db" "$db.away"
run
expect "D-X1: unreadable database, recent worktree" "$wts/recent" safe
if grep -q 'cannot read T3 threads' "$tmp/err"; then
	pass=$((pass + 1)); echo "ok   D-X1: unreadable database warns"
else
	fail=$((fail + 1)); echo "FAIL D-X1: unreadable database warns"
fi

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
