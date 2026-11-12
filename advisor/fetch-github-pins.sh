#!/bin/bash
# Fetch every GitHub commit pinned in swarmsim-coffee/yarn.lock into local clones,
# laid out as <dir>/<owner>/<repo> (lowercased), for advisor/github-pins-mirror.sh.
#
# Only needed on a network that serves plain `git fetch` from github.com but blocks the
# codeload.github.com tarballs yarn normally downloads. Anywhere else, `yarn install` is enough.
# It fetches one repository at a time, only the pinned commit, and never anything
# that is not in the lockfile. Re-running skips commits that are already present.
#
# Usage: advisor/fetch-github-pins.sh <dir>
set -u
dir=${1:?usage: fetch-github-pins.sh <dir>}
lock="$(cd "$(dirname "$0")/.." && pwd)/swarmsim-coffee/yarn.lock"
failed=0
while read -r repo sha; do
  d="$dir/$(echo "$repo" | tr 'A-Z' 'a-z')"
  if git -C "$d" cat-file -e "$sha^{commit}" 2>/dev/null; then echo "have $repo"; continue; fi
  mkdir -p "$d"
  [ -d "$d/.git" ] || { git -C "$d" init -q && git -C "$d" remote add origin "https://github.com/$repo"; }
  for try in 1 2; do
    GIT_LFS_SKIP_SMUDGE=1 git -C "$d" fetch -q --depth 1 origin "$sha" 2>"$d/.fetch.err" && break
    sleep 6
  done
  if git -C "$d" cat-file -e "$sha^{commit}" 2>/dev/null; then
    echo "ok   $repo"; rm -f "$d/.fetch.err"
  else
    echo "FAIL $repo: $(tail -1 "$d/.fetch.err")"; failed=1
  fi
done < <(grep -o 'codeload.github.com/[^/]*/[^/]*/tar.gz/[0-9a-f]*' "$lock" \
  | sed 's#codeload.github.com/##; s#/tar.gz/# #' | sort -u)
exit $failed
