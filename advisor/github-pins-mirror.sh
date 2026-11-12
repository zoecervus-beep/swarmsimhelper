#!/usr/bin/env bash
# For networks where codeload.github.com is blocked but local git clones of the
# GitHub-pinned dependencies exist: build a yarn offline mirror from them, so the
# normal, unmodified `yarn install --frozen-lockfile` succeeds.
#
# For every `resolved "https://codeload.github.com/<owner>/<repo>/tar.gz/<sha>"` in
# the repo's yarn.lock files, this writes <mirror>/<sha> (the file name yarn looks
# for) as `git archive --format=tar.gz --prefix=<repo>-<sha>/ <sha>`, i.e. the same
# tree codeload would serve. Clones are read-only inputs: they are looked up as
# <clones>/<owner>/<repo> (case-insensitive) and must contain the pinned commit;
# git's commit hash is the integrity check (the lockfile carries no integrity
# hash for these entries). Nothing is fetched from the network.
#
# Usage: advisor/github-pins-mirror.sh <clones dir> <mirror dir>
# Then:  YARN_YARN_OFFLINE_MIRROR=<mirror dir> yarn install --frozen-lockfile
# (setup-dev.sh does both when SWARMSIM_GIT_CLONES is set.)
# Exit 3 if any pinned commit has no clone; nothing else is changed.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLONES="${1:?usage: $0 <clones dir> <mirror dir>}"
MIRROR="${2:?usage: $0 <clones dir> <mirror dir>}"
mkdir -p "$MIRROR"

pins="$(cat "$REPO"/yarn.lock "$REPO"/*/yarn.lock \
  | sed -n 's#^  resolved "https://codeload.github.com/\([^/]*\)/\([^/]*\)/tar.gz/\([0-9a-f]\{40\}\)"$#\1 \2 \3#p' \
  | sort -u)"
total=0; made=0; missing=()
while read -r owner repo sha; do
  [ -n "$sha" ] || continue
  total=$((total + 1))
  clone="$(find "$CLONES" -mindepth 2 -maxdepth 2 -type d -ipath "$CLONES/$owner/$repo" 2>/dev/null | head -1)"
  if [ -z "$clone" ] || [ "$(git -C "$clone" cat-file -t "$sha" 2>/dev/null)" != commit ]; then
    missing+=("$owner/$repo@$sha")
    continue
  fi
  out="$MIRROR/$sha"
  if [ ! -s "$out" ]; then
    git -C "$clone" archive --format=tar.gz --prefix="$repo-$sha/" "$sha" > "$out.tmp"
    mv "$out.tmp" "$out"
  fi
  made=$((made + 1))
done <<< "$pins"

echo "github-pins-mirror: $made of $total pinned GitHub tarballs built from local clones into $MIRROR"
if [ "${#missing[@]}" -gt 0 ]; then
  printf '  no clone with pinned commit: %s\n' "${missing[@]}" >&2
  exit 3
fi
