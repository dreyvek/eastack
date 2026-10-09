#!/usr/bin/env bash
# Read-only worktree prune audit. Classifies every git worktree by size, merge
# state, uncommitted and unpushed work, remote/PR state, and the newest T3
# thread bound to it. Emits a table sorted by size with a suggested bucket.
# Never deletes anything; deletion stays a human-gated step in the playbook.
#
# Usage: worktree-audit.sh [repo-path]   (defaults to the current repo)
set -u

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1

# Main worktree is the first entry; everything else is a candidate.
main_wt=$(git worktree list --porcelain | awk '/^worktree /{print $2; exit}')

# origin/main drives the merge check. Best-effort; stale is fine for a first pass.
git fetch origin main --quiet 2>/dev/null || echo "warn: could not fetch origin/main; merged column may be stale" >&2

# PR state by branch, fetched once. Empty if gh is unavailable.
prs=$(mktemp)
gh pr list --author "@me" --state all --limit 1000 \
	--json number,state,headRefName 2>/dev/null > "$prs" || echo "[]" > "$prs"

# T3 records each thread's worktree binding and pin in its state database. The
# MCP tools expose neither per worktree: t3_worktree_status reports only the
# calling thread, and t3_worktree_list skips detached worktrees. Unreadable
# means unknown, and unknown never buckets as safe.
db="${T3_STATE_DB:-$HOME/.t3/userdata/state.sqlite}"
threads=yes
sqlite3 -readonly "$db" "select 1 from projection_threads limit 1" >/dev/null 2>&1 || {
	threads=no
	echo "warn: cannot read T3 threads from $db; LAST_THREAD is unknown and no row buckets as safe" >&2
}

printf "SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_THREAD\tPINNED\tBUCKET\tWORKTREE\n"

git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
	[ "$wt" = "$main_wt" ] && continue

	size=$(du -sh "$wt" 2>/dev/null | awk '{print $1}')
	head=$(git -C "$wt" rev-parse HEAD 2>/dev/null)
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( ($(date +%s) - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of main, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	git merge-base --is-ancestor "$head" origin/main 2>/dev/null && merged=YES || merged=no

	# Distinguish real WIP (tracked edits) from disposable untracked scratch.
	porcelain=$(git -C "$wt" status --porcelain 2>/dev/null)
	if [ -z "$porcelain" ]; then dirty=clean
	elif printf '%s\n' "$porcelain" | grep -qv '^??'; then
		dirty="wip:$(printf '%s\n' "$porcelain" | grep -cv '^??')"
	else dirty="scratch:$(printf '%s\n' "$porcelain" | grep -c '^??')"; fi

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null || echo "")
	if [ -z "$branch" ]; then remote=detached
	elif git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		ahead=$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)
		if [ "$(git -C "$wt" rev-parse "origin/$branch" 2>/dev/null)" = "$head" ]; then remote=pushed
		elif [ "$ahead" -gt 0 ]; then remote="ahead$ahead"
		else remote=behind; fi
	else remote=no-remote; fi

	pr=$([ -n "$branch" ] && jq -r --arg b "$branch" \
		'.[] | select(.headRefName==$b) | "#\(.number)/\(.state)"' "$prs" 2>/dev/null | head -1)
	[ -z "$pr" ] && pr="-"

	# Newest live thread bound to this worktree, whether it is within four
	# days, and whether any bound thread is pinned.
	last="?"; recent=no; pinned="?"
	if [ "$threads" = yes ]; then
		q=$(printf '%s' "$wt" | sed "s/'/''/g")
		IFS=$'\t' read -r last recent pinned < <(sqlite3 -readonly -separator $'\t' "$db" "
			select coalesce(date(max(updated_at)), '-'),
				case when max(updated_at) >= strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-4 days') then 'yes' else 'no' end,
				case when max(pinned_at is not null) = 1 then 'yes' else 'no' end
			from projection_threads
			where deleted_at is null and worktree_path in ('$q', '$q/')")
	fi

	case "$dirty" in wip:*) bucket=hold-wip ;; *)
		if [ "$pinned" = yes ]; then bucket=hold-pinned
		else case "$pr" in *OPEN*) bucket=hold-open-pr ;; *)
			if [ "$recent" = yes ]; then bucket=verify-recent-thread
			else case "$remote" in ahead*) bucket=hold-unpushed ;; *)
				if [ "$threads" = yes ] && { [ "$merged" = YES ] || [ "$pr" != "-" ]; }; then bucket=safe
				else bucket=review; fi ;;
			esac; fi ;;
		esac; fi ;;
	esac

	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$pinned" "$bucket" "$wt"
done | sort -t$'\t' -k1,1 -rh

rm -f "$prs"
