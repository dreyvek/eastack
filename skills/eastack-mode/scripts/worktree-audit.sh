#!/usr/bin/env bash
# Worktree prune audit. Classifies every git worktree by size, merge state,
# uncommitted and unpushed work, remote/PR state, and the newest T3 thread bound
# to it. Emits a table sorted by size with a suggested bucket. It reads only,
# apart from fetching the base ref. Never deletes anything; deletion stays a
# human-gated step in the playbook.
#
# Usage: worktree-audit.sh [-b|--base <ref>] [repo-path]
#   repo-path defaults to the current repo.
#   -b sets the ref the MERGED column checks against (e.g. origin/integration).
#   Without it the base is origin/HEAD, then origin/main, then origin/master.
#   origin/HEAD is the remote's default branch, not necessarily the branch PRs
#   merge into; pass -b when they differ.
set -u

base=""
while [ $# -gt 0 ]; do
	case "$1" in
	-b|--base) [ $# -ge 2 ] || { echo "error: $1 needs a ref" >&2; exit 2; }; base="$2"; shift 2 ;;
	-h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d; s/^# \{0,1\}//'; exit 0 ;;
	-*) echo "error: unknown option: $1" >&2; exit 2 ;;
	*) break ;;
	esac
done

repo="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -z "$repo" ] && { echo "not in a git repo; pass a repo path" >&2; exit 1; }
cd "$repo" || exit 1
git rev-parse --git-dir >/dev/null 2>&1 || { echo "error: not a git repo: $repo" >&2; exit 1; }

prs=$(mktemp); wtlist=$(mktemp); bindings=$(mktemp)
trap 'rm -f "$prs" "$wtlist" "$bindings"' EXIT

# NUL-separated, so paths keep their spaces. The main worktree is the first
# entry; everything else is a candidate.
git worktree list --porcelain -z > "$wtlist" || { echo "error: cannot list worktrees" >&2; exit 1; }
IFS= read -r -d '' main_wt < "$wtlist"
main_wt="${main_wt#worktree }"

if [ -z "$base" ]; then
	for cand in "$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)" origin/main origin/master; do
		[ -n "$cand" ] && git rev-parse --verify --quiet "$cand^{commit}" >/dev/null && { base="$cand"; break; }
	done
	[ -z "$base" ] && { echo "error: no base ref (origin/HEAD, origin/main, origin/master all missing); pass -b <ref>" >&2; exit 1; }
	echo "warn: no -b given; MERGED checks against $base" >&2
fi

# The base drives the merge check. The fetch is best-effort (stale is fine for
# a first pass) and runs before the check, since -b may name a branch not
# fetched yet. The explicit refspec creates it even in a single-branch clone.
case "$base" in
origin/*) git fetch origin "+refs/heads/${base#origin/}:refs/remotes/$base" --quiet 2>/dev/null \
	|| echo "warn: could not fetch $base; merged column may be stale" >&2 ;;
esac
git rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1 || { echo "error: base ref not found: $base" >&2; exit 1; }

# PR state by branch, fetched once as [{number, state, head}] with a lowercase
# state. If gh or jq fails, an open PR could be missed, so PR state is unknown.
prs_known=no
if raw=$(gh pr list --author "@me" --state all --limit 1000 \
		--json number,state,headRefName 2>/dev/null) \
	&& printf '%s' "$raw" | jq -e 'if type == "array" then
		[.[] | {number, state: (.state | ascii_downcase), head: .headRefName}]
		else error("not a list") end' > "$prs" 2>/dev/null; then
	prs_known=yes
else
	echo "warn: cannot list PRs with gh; PR is unknown and no row buckets as safe" >&2
fi

# physical <absolute path>: the path with symlinks, ".", "..", and repeated and
# trailing slashes resolved. A path that does not fully exist resolves its
# longest existing prefix that way and appends the missing rest as written,
# less repeated and trailing slashes. Fails on a relative path, on a prefix it
# cannot enter, and on a "." or ".." after the first missing component, whose
# parent is unknown.
physical() {
	case "$1" in /*) ;; *) return 1 ;; esac
	if [ -d "$1" ]; then (cd -P -- "$1" 2>/dev/null && pwd -P); return; fi
	local part dir="" rest="" top IFS=/
	set -f
	for part in $1; do
		if [ -z "$part" ]; then continue
		elif [ -n "$rest" ]; then
			case "$part" in .|..) set +f; return 1 ;; esac
			rest="$rest/$part"
		elif [ -d "$dir/$part" ]; then dir="$dir/$part"
		else rest="/$part"; fi
	done
	set +f
	top=$(cd -P -- "${dir:-/}" 2>/dev/null && pwd -P) || return 1
	printf '%s\n' "${top%/}$rest"
}

# T3 records each thread's worktree binding and pin in its state database. The
# MCP tools expose neither per worktree: t3_worktree_status reports only the
# calling thread, and t3_worktree_list skips detached worktrees. T3 stores the
# path it was given, so bindings and worktrees compare by physical path. A
# binding that cannot be read or resolved could belong to any worktree, so it
# makes every row unknown, and unknown never buckets as safe.
db="${T3_STATE_DB:-$HOME/.t3/userdata/statev2.sqlite}"
threads=no
if raw=$(sqlite3 -readonly -json "$db" "
		select json_type(payload_json, '\$.worktreePath') as type,
			json_extract(payload_json, '\$.worktreePath') as path,
			updated_at as updated,
			updated_at >= strftime('%Y-%m-%dT%H:%M:%SZ', 'now', '-4 days') as recent,
			json_extract(payload_json, '\$.pinnedAt') is not null as pinned
		from orchestration_v2_projection_threads
		where deleted_at is null and coalesce(json_type(payload_json, '\$.worktreePath'), 'null') <> 'null'" 2>/dev/null) \
	&& rows=$(printf '%s' "$raw" | jq -r '.[] |
		if .type == "text" and (.path | test("^/[^\t\n]*$"))
			and (.updated | type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[^\t\n]*$"))
			and (.recent == 0 or .recent == 1) and (.pinned == 0 or .pinned == 1)
		then [.path, .updated, .recent, .pinned] | map(tostring) | join("\t")
		else error("bad binding") end' 2>/dev/null); then
	threads=yes
	if [ -n "$rows" ]; then
		while IFS=$'\t' read -r path updated recent pinned; do
			real=$(physical "$path") || { threads=no; break; }
			printf '%s\t%s\t%s\t%s\n' "$real" "$updated" "$recent" "$pinned"
		done <<< "$rows" > "$bindings"
	fi
fi
[ "$threads" = yes ] \
	|| echo "warn: cannot read T3 threads from $db; LAST_THREAD is unknown and no row buckets as safe" >&2
now=$(date +%s)

echo "# base: $base"
printf "SIZE\tAGE\tMERGED\tDIRTY\tREMOTE\tPR\tLAST_THREAD\tPINNED\tBUCKET\tWORKTREE\n"

while IFS= read -r -d '' line; do
	case "$line" in "worktree "*) wt="${line#worktree }" ;; *) continue ;; esac
	[ "$wt" = "$main_wt" ] && continue

	# Any signal git or the database cannot read is unknown: its column prints
	# "?" and the row cannot bucket as safe.
	unknown=no
	[ "$threads" = yes ] || unknown=yes

	size=$(du -sh "$wt" 2>/dev/null | awk '{print $1}')
	head=$(git -C "$wt" rev-parse --verify --quiet HEAD 2>/dev/null) || { head=""; unknown=yes; }
	head_ts=$(git -C "$wt" log -1 --format='%ct' HEAD 2>/dev/null || echo 0)
	age=$([ "$head_ts" -gt 0 ] 2>/dev/null && echo "$(( (now - head_ts) / 86400 ))d" || echo "?")

	# Squash-merged branches are not ancestors of the base, so PR state is the
	# real signal; merge-base only catches fast-forward/rebase merges.
	merged="?"
	if [ -n "$head" ]; then
		git merge-base --is-ancestor "$head" "$base" 2>/dev/null
		case $? in 0) merged=YES ;; 1) merged=no ;; *) unknown=yes ;; esac
	fi

	# Distinguish real WIP (tracked edits) from disposable untracked scratch.
	if ! porcelain=$(git -C "$wt" status --porcelain 2>/dev/null); then dirty="?"; unknown=yes
	elif [ -z "$porcelain" ]; then dirty=clean
	elif printf '%s\n' "$porcelain" | grep -qv '^??'; then
		dirty="wip:$(printf '%s\n' "$porcelain" | grep -cv '^??')"
	else dirty="scratch:$(printf '%s\n' "$porcelain" | grep -c '^??')"; fi

	branch=$(git -C "$wt" symbolic-ref --quiet --short HEAD 2>/dev/null)
	case $? in
	0)
		git -C "$wt" show-ref --verify --quiet "refs/remotes/origin/$branch"
		case $? in
		0)
			if ahead=$(git -C "$wt" rev-list --count "origin/$branch..HEAD" 2>/dev/null) \
				&& [ "$ahead" -ge 0 ] 2>/dev/null \
				&& upstream=$(git -C "$wt" rev-parse --verify --quiet "origin/$branch^{commit}" 2>/dev/null) \
				&& [ -n "$head" ]; then
				if [ "$upstream" = "$head" ]; then remote=pushed
				elif [ "$ahead" -gt 0 ]; then remote="ahead$ahead"
				else remote=behind; fi
			else remote="?"; unknown=yes; fi ;;
		1) remote=no-remote ;;
		*) remote="?"; unknown=yes ;;
		esac ;;
	1) branch=""; remote=detached ;;
	*) branch=""; remote="?"; unknown=yes ;;
	esac

	if [ "$prs_known" = no ]; then pr="?"; unknown=yes
	elif [ -z "$branch" ]; then pr="-"
	elif ! pr=$(jq -r --arg b "$branch" \
		'[.[] | select(.head==$b) | "#\(.number)/\(.state)"] | .[0] // "-"' "$prs" 2>/dev/null); then
		pr="?"; unknown=yes
	fi

	# Newest live thread bound to this worktree, whether it is within four
	# days, and whether any bound thread is pinned.
	last="?"; recent=no; pinned="?"
	if [ "$threads" = yes ]; then
		if [ -d "$wt" ] && real=$(physical "$wt") \
			&& m=$(REAL="$real" awk -F'\t' '
				$1 == ENVIRON["REAL"] { n++; if ($2 > max) max = $2; if ($3 == 1) r = 1; if ($4 == 1) p = 1 }
				END { printf "%s\t%s\t%s\n", n ? substr(max, 1, 10) : "-", r ? "yes" : "no", p ? "yes" : "no" }' "$bindings"); then
			IFS=$'\t' read -r last recent pinned <<< "$m"
		else unknown=yes; fi
	fi

	case "$dirty" in wip:*) bucket=hold-wip ;; *)
		if [ "$pinned" = yes ]; then bucket=hold-pinned
		else case "$pr" in */open) bucket=hold-open-pr ;; *)
			if [ "$recent" = yes ]; then bucket=verify-recent-thread
			else case "$remote" in ahead*) bucket=hold-unpushed ;; *)
				if [ "$unknown" = no ] && { [ "$merged" = YES ] || [ "$pr" != "-" ]; }; then bucket=safe
				else bucket=review; fi ;;
			esac; fi ;;
		esac; fi ;;
	esac

	printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
		"$size" "$age" "$merged" "$dirty" "$remote" "$pr" "$last" "$pinned" "$bucket" "$wt"
done < "$wtlist" | sort -t$'\t' -k1,1 -rh
