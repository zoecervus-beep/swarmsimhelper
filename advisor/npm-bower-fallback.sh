#!/usr/bin/env bash
# FALLBACK ONLY: install swarmsim-coffee when codeload.github.com is unreachable.
#
# swarmsim-coffee/package.json pins its browser libraries ("@bower_components/*")
# and grunt-wiredep-away to GitHub tarballs. This script, run by setup-dev.sh only
# when the GitHub check fails:
#   1. installs every *other* swarmsim-coffee dependency normally (yarn, lockfile
#      versions), using a temporary copy of package.json without the GitHub entries;
#      the committed package.json and yarn.lock are restored by an EXIT trap and
#      yarn runs with --pure-lockfile, so neither is ever rewritten;
#   2. fills node_modules/@bower_components/<name> from npm-registry packages at
#      the version the lockfile pins (table below);
#   3. for the six with no npm copy (GIT table below): if SWARMSIM_GIT_CLONES names
#      a directory holding local clones laid out as <owner>/<repo> (name match is
#      case-insensitive), exports each at the commit the lockfile pins (checked
#      against yarn.lock; `git archive`, the same tree the codeload tarball has,
#      clones are only read) and lets yarn install that tarball in place of the
#      GitHub URL, so their own dependencies come from the lockfile as usual;
#   4. leaves whatever is still missing empty and says so. Nothing is substituted,
#      unless you pass --near-versions (see NEAR below).
#
# Results obtained this way are "with npm-registry copies", not with the real
# pinned sources. On a normal network, use plain `yarn install` instead.
#
# Usage: [SWARMSIM_GIT_CLONES=<dir>] advisor/npm-bower-fallback.sh [--near-versions]
#   --near-versions  OPT-IN: also install the NEAR stand-ins below, which are NOT
#                    the pinned versions. Each gets a NOT-THE-PINNED-VERSION.txt
#                    marker. Without the flag, stand-ins from an earlier run are removed.
#
# Needs Node 16 + yarn 1 on PATH (source the env.sh written by setup-dev.sh).
set -euo pipefail

NEAR_VERSIONS=0
for a in "$@"; do
  case "$a" in
    --near-versions) NEAR_VERSIONS=1 ;;
    *) echo "unknown argument: $a" >&2; exit 64 ;;
  esac
done

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COFFEE="$REPO/swarmsim-coffee"
BC="$COFFEE/node_modules/@bower_components"
MARKER="NOT-THE-PINNED-VERSION.txt"
GIT_CLONES="${SWARMSIM_GIT_CLONES:-}"

# No npm copy at the pinned version; installable from a local clone:
# package.json key (swarmsim-coffee) | GitHub owner/repo | lockfile entry it must match
# playfab-sdk-browser is a dependency of swarm-persist (applied via yarn "resolutions").
GIT='
@bower_components/swarm-persist|erosson/swarm-persist|"@bower_components/swarm-persist@erosson/swarm-persist#0.0.3":
@bower_components/swarm-numberformat|erosson/swarm-numberformat|"@bower_components/swarm-numberformat@erosson/swarm-numberformat#0.2.1":
@bower_components/playfab-sdk|PlayFab/JavaScriptSDK|"@bower_components/playfab-sdk@PlayFab/JavaScriptSDK#1.0.170130":
@bower_components/flash-cookies|nfriedly/Javascript-Flash-Cookies|"@bower_components/flash-cookies@nfriedly/Javascript-Flash-Cookies#2.2.3":
grunt-wiredep-away|gscavalcante/grunt-wiredep-away|grunt-wiredep-away@gscavalcante/grunt-wiredep-away:
playfab-sdk-browser|erosson/playfab-sdk-browser|"playfab-sdk-browser@github:erosson/playfab-sdk-browser":
'

# Opt-in stand-ins (--near-versions): name | npm stand-in | pinned version | why
# swarm-persist, playfab-sdk, grunt-wiredep-away, playfab-sdk-browser have no npm
# copy at ANY version and stay missing even with the flag.
NEAR='
swarm-numberformat|swarm-numberformat@0.2.0|0.2.1|0.2.1 only adds "Support undefined/null/zero sigfigs" (upstream changelog)
flash-cookies|flash-cookies@2.2.1|2.2.3|npm has only 2.2.0 and 2.2.1
'

# name | pinned GitHub source (lockfile) | npm source | note
# npm source "GAP" = no npm package at the pinned version; left uninstalled.
MAP='
SHA-1|linkgod/SHA-1#* @b51b81ce (v1.0.0)|sha-1@1.0.0|npm gitHead 16d9a413 != pinned commit
angular|angular/bower-angular#1.6.1 @38280603|angular@1.6.1|gitHead matches
angular-animate|angular/bower-angular-animate#1.6.1 @49a93460|angular-animate@1.6.1|gitHead matches
angular-cookies|angular/bower-angular-cookies#1.6.1 @7abd6b51|angular-cookies@1.6.1|gitHead matches
angular-google-chart|angular-google-chart/angular-google-chart#0.1.0 @fa139db5|angular-google-chart@0.1.0|gitHead matches
angular-hotkeys|chieffancypants/angular-hotkeys#1.7.0 @07251370|angular-hotkeys@1.7.0|gitHead matches
angular-mocks|angular/bower-angular-mocks#1.6.1 @d8ac5a20|angular-mocks@1.6.1|gitHead matches
angular-resource|angular/bower-angular-resource#1.6.1 @d203a7da|angular-resource@1.6.1|gitHead matches
angular-route|angular/bower-angular-route#1.6.1 @409c45cf|angular-route@1.6.1|gitHead matches
angular-sanitize|angular/bower-angular-sanitize#1.6.1 @4ca63807|angular-sanitize@1.6.1|gitHead matches
angular-scenario|angular/bower-angular-scenario#1.6.1 @21d00b69|angular-scenario@1.6.1|gitHead matches
angular-touch|angular/bower-angular-touch#1.6.1 @85eb1243|angular-touch@1.6.1|gitHead matches
angulartics|angulartics/angulartics#1.3.0 @10d5be2f|angulartics@1.3.0|gitHead matches
angulartics-google-analytics|angulartics/angulartics-google-analytics#0.4.0 @080eb7c8|angulartics-google-analytics@0.4.0|gitHead matches
bootstrap|twbs/bootstrap#~3.3.7 @0b9c4a40|bootstrap@3.3.7|gitHead matches
bootstrap-sass|twbs/bootstrap-sass#3.3.7 @5d6b2ebb|bootstrap-sass@3.3.7|gitHead matches
bootswatch|thomaspark/bootswatch#3.3.7 @4b0d3762|bootswatch@3.3.7|gitHead matches
decimal.js|MikeMcl/decimal.js#7.1.1 @45eec0b8|decimal.js@7.1.1|gitHead matches
es5-shim|es-shims/es5-shim#4.5.9 @30ebdda8|es5-shim@4.5.9|gitHead matches
favico.js|ejci/favico.js#0.3.10 @f612afcb|favico.js@0.3.10|gitHead matches
flash-cookies|nfriedly/Javascript-Flash-Cookies#2.2.3 @07c3a6e2|GAP|npm flash-cookies has only 2.2.0, 2.2.1
font-awesome|FortAwesome/Font-Awesome#4.7.0 @a8386aae|font-awesome@4.7.0|gitHead matches
jquery|jquery/jquery-dist#3.1.1 @1b30f3ad|jquery@3.1.1|gitHead matches
jquery-cookie|carhartl/jquery-cookie#1.4.1 @7f88a4e6|jquery.cookie@1.4.1|npm gitHead bd3c9713 != pinned commit
json3|bestiejs/json3#3.3.2 @dec5c2a5|json3@3.3.2|npm has no gitHead; version matches
lodash|lodash/lodash#4.17.10 @67389a8c|lodash@4.17.10|npm has no gitHead; version matches
lz-string|pieroxy/lz-string#1.4.4 @cf06e9a0|lz-string@1.4.4|gitHead matches
mathjs|josdejong/mathjs#3.8.1 @29da2b04|mathjs@3.8.1|gitHead matches
moment|moment/moment#2.17.1 @b8a297c1|moment@2.17.1|npm has no gitHead; version matches
moment-duration-format|jsmreese/moment-duration-format#1.3.0 @8d0bf29a|moment-duration-format@1.3.0|npm has no gitHead; version matches
numeral|adamwdraper/Numeral-js#2.0.4 @a7a2dedd|numeral@2.0.4|gitHead matches
playfab-sdk|PlayFab/JavaScriptSDK#1.0.170130 @236b18be|GAP|not on npm; playfab-web-sdk starts at 1.17.171127, playfab-sdk is the Node SDK
qs|hapijs/qs#^6.4.0 @56763c12 (v6.11.0)|qs@6.11.0|gitHead matches
seedrandom|davidbau/seedrandom#2.4.2 @1b530945|seedrandom@2.4.2|gitHead matches
sjcl|bitwiseshiftleft/sjcl#1.0.6 @51ae8f8c|sjcl@1.0.6|npm gitHead 00bd42da != pinned commit
swarm-numberformat|erosson/swarm-numberformat#0.2.1 @038998d8|GAP|npm has 0.2.0 and 0.3.0, not 0.2.1
swarm-persist|erosson/swarm-persist#0.0.3 @b7a3f859|GAP|all npm versions unpublished (2024-01-05)
'
# Not under @bower_components (also GAPs, no npm package):
#   grunt-wiredep-away  gscavalcante/grunt-wiredep-away @6b010f5d  -> provides the grunt `wiredep` task
#   playfab-sdk-browser erosson/playfab-sdk-browser @d20778f5       -> dependency of swarm-persist only

TMPD="$(mktemp -d)"
BACKUP="$TMPD/backup"
mkdir -p "$BACKUP"
cp -p "$COFFEE/package.json" "$COFFEE/yarn.lock" "$BACKUP/"
restore() {
  cp -p "$BACKUP/package.json" "$COFFEE/package.json"
  cp -p "$BACKUP/yarn.lock" "$COFFEE/yarn.lock"
  rm -rf "$TMPD"
}
trap restore EXIT INT TERM

# ---- local git clones for the no-npm six (optional)
FROM_GIT="$TMPD/from-git.tsv"   # key <TAB> tarball <TAB> owner/repo <TAB> sha
: > "$FROM_GIT"
if [ -n "$GIT_CLONES" ]; then
  echo "== [npm fallback] looking for local clones under $GIT_CLONES"
  while IFS='|' read -r key slug entry; do
    [ -n "$key" ] || continue
    # pinned commit = last path part of the lockfile's codeload URL for that entry
    sha="$(grep -F -x -A3 -- "$entry" "$BACKUP/yarn.lock" | sed -n 's#^  resolved "https://codeload.github.com/.*/tar.gz/\([0-9a-f]\{40\}\)"$#\1#p' | head -1)"
    [ -n "$sha" ] || { echo "ERROR: no codeload pin for $key in yarn.lock" >&2; exit 1; }
    clone="$(find "$GIT_CLONES" -mindepth 2 -maxdepth 2 -type d -ipath "$GIT_CLONES/$slug" | head -1)"
    if [ -z "$clone" ]; then echo "   no clone for $slug"; continue; fi
    if [ "$(git -C "$clone" cat-file -t "$sha" 2>/dev/null)" != commit ]; then
      echo "   $clone lacks pinned commit $sha; not used"; continue
    fi
    tgz="$TMPD/$(echo "$slug" | tr / -)-$sha.tgz"
    git -C "$clone" archive --format=tar.gz --prefix="$(basename "$slug")-$sha/" "$sha" > "$tgz"
    printf '%s\t%s\t%s\t%s\n' "$key" "$tgz" "$slug" "$sha" >> "$FROM_GIT"
    echo "   $key <- $clone @ $sha (lockfile pin)"
  done <<< "$GIT"
  # swarm-persist needs playfab-sdk-browser from GitHub; without its clone yarn would
  # try GitHub, so use neither.
  if grep -q $'^@bower_components/swarm-persist\t' "$FROM_GIT" && ! grep -q $'^playfab-sdk-browser\t' "$FROM_GIT"; then
    echo "   swarm-persist needs playfab-sdk-browser's clone too; leaving swarm-persist out"
    sed -i $'/^@bower_components\/swarm-persist\t/d' "$FROM_GIT"
  fi
fi

if [ -s "$FROM_GIT" ]; then
  echo "== [npm fallback] yarn install (registry deps + local-clone tarballs) in swarmsim-coffee"
else
  echo "== [npm fallback] yarn install (registry deps only) in swarmsim-coffee"
fi
# Stand-ins from an earlier --near-versions run must not survive under the real names.
for d in "$BC"/*/; do [ -f "$d$MARKER" ] && rm -rf "$d"; done 2>/dev/null || true
node -e '
  const fs = require("fs"), f = process.argv[1], p = JSON.parse(fs.readFileSync(f, "utf8"));
  const fromGit = {};
  for (const line of fs.readFileSync(process.argv[2], "utf8").split("\n").filter(Boolean)) {
    const [key, tgz] = line.split("\t"); fromGit[key] = "file:" + tgz;
  }
  for (const sec of ["dependencies", "devDependencies"])
    for (const k of Object.keys(p[sec] || {}))
      if (k.startsWith("@bower_components/") || k === "grunt-wiredep-away") {
        if (fromGit[k]) p[sec][k] = fromGit[k]; else delete p[sec][k];
      }
  if (fromGit["playfab-sdk-browser"]) p.resolutions = Object.assign({}, p.resolutions, {"playfab-sdk-browser": fromGit["playfab-sdk-browser"]});
  fs.writeFileSync(f, JSON.stringify(p, null, 2) + "\n");
' "$COFFEE/package.json" "$FROM_GIT"
(cd "$COFFEE" && yarn install --pure-lockfile --non-interactive)
cp "$FROM_GIT" "$COFFEE/node_modules/.swarmsim-from-git.tsv"
restore
trap - EXIT INT TERM
TMPD="$(mktemp -d)"
trap 'rm -rf "$TMPD"' EXIT

echo "== [npm fallback] filling node_modules/@bower_components from the npm registry"
mkdir -p "$BC"
fetch() { # fetch <name> <npm spec>: (re)install @bower_components/<name> unless already that spec
  local dest="$BC/$1"
  if [ -f "$dest/.npm-fallback" ] && [ "$(cat "$dest/.npm-fallback")" = "$2" ]; then
    return 1
  fi
  rm -rf "$dest"
  local tgz
  tgz="$(cd "$TMPD" && npm pack --silent "$2")"   # npm checks the registry integrity hash
  mkdir -p "$dest"
  tar --warning=no-unknown-keyword -xzf "$TMPD/$tgz" -C "$dest" --strip-components=1
  rm -f "$TMPD/$tgz"
  echo "$2" > "$dest/.npm-fallback"
  echo "   $1 <- $2"
}
FROM_GIT_DONE="$COFFEE/node_modules/.swarmsim-from-git.tsv"
from_git() { grep -q "^$1	" "$FROM_GIT_DONE" 2>/dev/null; }

gaps=()
while IFS='|' read -r name pinned spec note; do
  [ -n "$name" ] || continue
  if [ "$spec" = GAP ]; then
    from_git "@bower_components/$name" || gaps+=("$name ($pinned): $note")
    continue
  fi
  fetch "$name" "$spec" || true
done <<< "$MAP"
for k in grunt-wiredep-away playfab-sdk-browser; do
  from_git "$k" || gaps+=("$k ($(grep "^$k|" <<< "$GIT" | cut -d'|' -f2)): not on npm")
done

near_used=()
while IFS='|' read -r name spec pinned why; do
  [ -n "$name" ] || continue
  from_git "@bower_components/$name" && continue   # real pinned copy installed
  dest="$BC/$name"
  if [ "$NEAR_VERSIONS" = 1 ]; then
    fetch "$name" "$spec" || true
    cat > "$dest/$MARKER" <<EOF
NOT THE PINNED VERSION. Installed by advisor/npm-bower-fallback.sh --near-versions.
This directory holds npm $spec as a stand-in for the pinned GitHub version $pinned,
which has no npm copy ($why). Test or app results that use it are not
results with the pinned dependency. Re-run the fallback without --near-versions to remove it.
EOF
    near_used+=("$name: npm $spec installed in place of pinned $pinned ($why)")
  elif [ -f "$dest/$MARKER" ]; then
    rm -rf "$dest"
    echo "   removed stand-in $name (run without --near-versions)"
  fi
done <<< "$NEAR"

# Layout: every bower_components path used by test/karma-*.conf.coffee, app/index.html,
# app/styles/*.scss, Gruntfile.js (copy, compass importPath) and options.coffee
# (bootswatch themes) was checked against the npm packages above: all present at
# the same paths, so no fix-ups are needed. Missing paths are only the GAPs, plus
# konami-js/ and appcache-nanny/, which the karma configs list but package.json
# never installed (upstream too; Karma just warns).

(cd "$COFFEE" && node -e "try { require('fs').symlinkSync(require('path').resolve('node_modules/@bower_components'), 'bower_components', 'junction') } catch (e) { }")

echo
echo "== [npm fallback] done."
echo "   33 GitHub-pinned libraries: npm-registry copies at the pinned versions (table in this script)."
if [ -s "$FROM_GIT_DONE" ]; then
  echo "   From local git clones at the lockfile-pinned commit:"
  while IFS=$'\t' read -r key _ slug sha; do echo "     $key <- $slug @ $sha"; done < "$FROM_GIT_DONE"
fi
if [ "${#gaps[@]}" -gt 0 ]; then
  echo "   NOT installed (no npm copy at the pinned version, no local clone):"
  for g in "${gaps[@]}"; do
    n="${g%% *}"
    if [ -f "$BC/$n/$MARKER" ]; then echo "     GAP $g  [stand-in installed, see below]"; else echo "     GAP $g"; fi
  done
  echo "   Set SWARMSIM_GIT_CLONES=<dir with owner/repo clones> to install them from local clones."
fi
if [ "${#near_used[@]}" -gt 0 ]; then
  echo
  echo "!! --near-versions: these are NOT the pinned versions (marker: $MARKER in each):"
  for n in "${near_used[@]}"; do echo "!!   $n"; done
  echo "!! Results with these stand-ins are not results with the pinned dependencies."
fi
[ "${#gaps[@]}" -eq 0 ] || exit 3
