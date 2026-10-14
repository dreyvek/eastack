#!/usr/bin/env bash
# Tests for worktree-audit.sh. Builds throwaway git repos and T3 state
# databases in a temporary directory, runs the audit against them, checks
# each worktree's bucket, and deletes everything it created.
#
# Usage: bash worktree-audit.test.sh
#   AUDIT=<path> tests another copy of the audit, such as an older revision.
set -u

audit="${AUDIT:-$(cd "$(dirname "$0")" && pwd)/worktree-audit.sh}"
tmp=$(cd -P "$(mktemp -d)" && pwd -P)
trap 'chmod -R u+rwx "$tmp" 2>/dev/null; rm -rf "$tmp"' EXIT

# Isolate git and gh from the user's config, account and network.
export HOME="$tmp/home" GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
mkdir -p "$HOME" "$tmp/bin"
# gh answers as GH_STUB says: "empty" lists no PRs, "garbage" prints what jq
# cannot parse, and anything else fails.
cat > "$tmp/bin/gh" <<'EOF'
#!/bin/sh
case "${GH_STUB:-}" in
empty) echo '[]' ;;
garbage) echo 'not json' ;;
*) exit 1 ;;
esac
EOF
# Finding 2: a git shim fails `rev-list` in the bad-rev-list worktree.
cat > "$tmp/bin/git" <<EOF
#!/bin/sh
case "\$*" in *bad-rev-list\ rev-list\ *) echo "fatal: injected" >&2; exit 128 ;; esac
exec "$(command -v git)" "\$@"
EOF
chmod +x "$tmp/bin/gh" "$tmp/bin/git"
export PATH="$tmp/bin:$PATH"

fail=0
pass=0

repo="$tmp/repo"
wts="$tmp/wt"
git init -q --bare -b main "$tmp/origin.git"
git init -q -b main "$repo"
git -C "$repo" commit -q --allow-empty -m base
git -C "$repo" remote add origin "$tmp/origin.git"
git -C "$repo" push -q origin main
git -C "$repo" fetch -q origin
mkdir -p "$wts"

# Every worktree starts clean, merged and without a remote branch, so the
# signal under test decides its bucket.
add_wt() { git -C "$repo" worktree add -q -b "$2" "$1" main; }
add_wt "$wts/clean-merged" clean-merged
add_wt "$wts/recent" recent
add_wt "$wts/pinned" pinned
add_wt "$wts/dot-pinned" dot-pinned
add_wt "$wts/link-pinned" link-pinned
add_wt "$wts/space pinned" space-pinned
add_wt "$wts/bad-status" bad-status
add_wt "$wts/bad-rev-list" bad-rev-list
add_wt "$wts/bad-remote-ref" bad-remote-ref
ln -s "$wts" "$tmp/link"
ln -s "$wts/recent" "$tmp/alias"

# Finding 2: an index git cannot open makes `git status` fail.
chmod 000 "$repo/.git/worktrees/bad-status/index"
# Finding 2: the bad-rev-list branch is behind its remote, so the remote
# check runs `rev-list`, which the shim fails.
ahead=$(git -C "$repo" commit-tree -p main -m ahead "main^{tree}")
git -C "$repo" update-ref refs/remotes/origin/bad-rev-list "$ahead"
# Finding 2: a remote-tracking ref naming a missing object makes `show-ref` fail.
printf '0123456789012345678901234567890123456789\n' > "$repo/.git/refs/remotes/origin/bad-remote-ref"

# make_db <file> <worktreePath> <age> <pinned> per row; age is "now" or "old".
make_db() {
	db="$1"; shift
	sqlite3 "$db" "create table orchestration_v2_projection_threads (
		thread_id text primary key, project_id text not null, title text not null,
		default_provider text not null, runtime_mode text not null, interaction_mode text not null,
		active_provider_thread_id text, created_at text not null, updated_at text not null,
		archived_at text, deleted_at text, payload_json text not null, provider_instance_id text)"
	n=0
	while [ $# -ge 3 ]; do
		n=$((n + 1))
		path=$(printf '%s' "$1" | sed "s/'/''/g")
		[ "$2" = now ] && mod="'-1 hours'" || mod="'-30 days'"
		[ "$3" = yes ] && pin="strftime('%Y-%m-%dT%H:%M:%fZ', 'now')" || pin="null"
		sqlite3 "$db" "insert into orchestration_v2_projection_threads
			(thread_id, project_id, title, default_provider, runtime_mode, interaction_mode, created_at, updated_at, payload_json)
			values ('t$n', 'p', 't', 'codex', 'full-access', 'default',
				strftime('%Y-%m-%dT%H:%M:%fZ', 'now', $mod), strftime('%Y-%m-%dT%H:%M:%fZ', 'now', $mod),
				json_object('worktreePath', '$path', 'pinnedAt', $pin))"
		shift 3
	done
}

# expect <label> <output file> <worktree path> <bucket>
expect() {
	got=$(awk -F'\t' -v p="$3" '$10 == p { print $9 }' "$2")
	if [ "$got" = "$4" ]; then
		pass=$((pass + 1)); echo "ok   $1: $4"
	else
		fail=$((fail + 1)); echo "FAIL $1: want $4, got ${got:-<no row>}"
	fi
}

# run <database> <output file> [gh stub mode, default empty]
run() { GH_STUB="${3:-empty}" T3_STATE_DB="$1" bash "$audit" -b origin/main "$repo" > "$2" 2> "$2.err"; }

# warns <label> <output file> <pattern>
warns() {
	if grep -q "$3" "$2.err"; then
		pass=$((pass + 1)); echo "ok   $1"
	else
		fail=$((fail + 1)); echo "FAIL $1"
	fi
}

# One database for the good paths and findings 2 and 3.
make_db "$tmp/state.sqlite" \
	"$wts/recent" now no \
	"$wts/pinned" old yes \
	"$wts/./dot-pinned" old yes \
	"$tmp/link/link-pinned" old yes \
	"$wts/space pinned" old yes \
	"$wts/clean-merged-gone" now yes \
	"$tmp/alias/../gone" now yes
out="$tmp/out"
run "$tmp/state.sqlite" "$out"
expect "clean merged worktree, valid empty PR list" "$out" "$wts/clean-merged" safe
expect "recent thread" "$out" "$wts/recent" verify-recent-thread
expect "pinned thread" "$out" "$wts/pinned" hold-pinned
expect "finding 3: pin bound through ./" "$out" "$wts/dot-pinned" hold-pinned
expect "finding 3: pin bound through a symlink" "$out" "$wts/link-pinned" hold-pinned
expect "finding 3: path with a space" "$out" "$wts/space pinned" hold-pinned
expect "finding 2: unreadable git status" "$out" "$wts/bad-status" review
expect "finding 2: failed rev-list" "$out" "$wts/bad-rev-list" review
expect "finding 2: unreadable remote ref" "$out" "$wts/bad-remote-ref" review

# Finding 1: a malformed payload makes the thread query fail.
make_db "$tmp/malformed.sqlite" "$wts/recent" now no
sqlite3 "$tmp/malformed.sqlite" "insert into orchestration_v2_projection_threads
	(thread_id, project_id, title, default_provider, runtime_mode, interaction_mode, created_at, updated_at, payload_json)
	values ('bad', 'p', 't', 'codex', 'full-access', 'default', '2026-01-01T00:00:00.000Z', '2026-01-01T00:00:00.000Z', '{not json')"
run "$tmp/malformed.sqlite" "$out"
expect "finding 1: malformed thread payload" "$out" "$wts/clean-merged" review

# Finding 1: a binding T3 stored as a relative path cannot be placed.
make_db "$tmp/relative.sqlite" "wt/clean-merged" old yes
run "$tmp/relative.sqlite" "$out"
expect "finding 1: relative thread binding" "$out" "$wts/clean-merged" review

# Finding 3: a binding under a directory the audit cannot enter cannot be
# resolved, so it could name any worktree.
mkdir -p "$tmp/locked/inner"
chmod 000 "$tmp/locked"
make_db "$tmp/locked.sqlite" "$tmp/locked/inner/clean-merged" old yes
run "$tmp/locked.sqlite" "$out"
chmod 700 "$tmp/locked"
expect "finding 3: unresolvable thread binding" "$out" "$wts/clean-merged" review

# A binding through a symlink and then ".." resolves physically while every
# directory on it exists. Once one is gone, a ".." after it has no known
# parent, so the binding could name any worktree.
make_db "$tmp/dotdot.sqlite" "$tmp/alias/../deleted/../clean-merged" old yes
mkdir "$wts/deleted"
run "$tmp/dotdot.sqlite" "$out"
expect "pin through a symlink and .., every directory present" "$out" "$wts/clean-merged" hold-pinned
rmdir "$wts/deleted"
run "$tmp/dotdot.sqlite" "$out"
expect "pin through a symlink and .. past a missing directory" "$out" "$wts/clean-merged" review

# Unreadable database: thread state is unknown, so nothing is safe.
run "$tmp/missing.sqlite" "$out"
expect "unreadable database" "$out" "$wts/clean-merged" review
warns "unreadable database warns" "$out" 'cannot read T3 threads'

# Failed PR discovery: an open PR could be missed, so nothing is safe.
run "$tmp/state.sqlite" "$out" fail
expect "failing gh" "$out" "$wts/clean-merged" review
warns "failing gh warns" "$out" 'cannot list PRs'
run "$tmp/state.sqlite" "$out" garbage
expect "PR list jq cannot parse" "$out" "$wts/clean-merged" review

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
