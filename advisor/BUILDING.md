# Building and testing this fork

## Status (Nov 12 2026)

- **Your own machine / CI (codeload.github.com reachable):** plain
  `yarn install --frozen-lockfile` fetches everything, GitHub pins included. Not run by
  us on such a network, but it is the same unmodified command as below.
- **The Claude Code cloud container this was set up in:** codeload.github.com is
  refused (HTTP 403). All 39 GitHub-pinned dependencies were installed **from local
  git clones at the exact lockfile-pinned commits**: `advisor/github-pins-mirror.sh`
  turns them into a yarn offline mirror, and the normal, unmodified
  `yarn install --frozen-lockfile` runs against it. Yarn does resolution, linking
  and lifecycle scripts as usual. `package.json` and `yarn.lock` are not touched.
  No npm substitutes and no near versions are in that tree.
- Everything below marked "Container run" was actually run there.

## What you need

| Tool | Version | Why |
| --- | --- | --- |
| Node | 16.x (16.20.2 tested) | upstream CI version; Grunt 1.0 / Karma 1.5 era tooling |
| yarn | 1.x (1.22.22) | workspaces are linked with `yarn link` by the root `install` script |
| Ruby + `compass` gem | Ruby 2.5 to 3.3; compass 1.0.3 | `grunt pretest`, `build`, `serve` compile Sass with compass |
| PhantomJS 2.1.1 | downloaded by `yarn install` (GitHub release) | Karma unit and integration suites |
| Network | npm registry, codeload.github.com, github.com releases | bower deps are GitHub tarballs; PhantomJS is a GitHub release |

Two compatibility workarounds, both applied by the `env.sh` that `advisor/setup-dev.sh` writes:

- Ruby 3.2+ removed `File.exists?`, which compass/sass 3.4 call. A two-line shim is loaded through `RUBYOPT`.
- PhantomJS 2.1.1 aborts on modern OpenSSL configs ("Auto configuration failed ... libproviders.so"), so `OPENSSL_CONF=/dev/null` is exported. Upstream's Dockerfile does the same.

## Setup

### (a) Your own machine

```bash
nvm install 16 && nvm use 16
```

```bash
npm install -g yarn@1.22.22
```

Then the setup script. It finds Node 16 on PATH and installs compass, plus the Ruby 3.2+
shim if needed. With codeload reachable it then runs plain `yarn install --frozen-lockfile`:

```bash
advisor/setup-dev.sh
```

```bash
. "${XDG_CACHE_HOME:-$HOME/.cache}/swarmsim-toolchain/env.sh"
```

The script's own Node download is Linux x64 only; on macOS use nvm as above.
PhantomJS on Apple Silicon may need Rosetta.

### (b) Linux container without codeload.github.com

Pick a toolchain directory outside the repo:

```bash
export SWARMSIM_TOOLCHAIN_DIR="$HOME/.cache/swarmsim-toolchain"
```

If you have local clones of the 39 pinned repos, laid out as `<dir>/<owner>/<repo>`
(name match is case-insensitive) and each containing its pinned commit (shallow
clones are fine), point the script at them:

```bash
SWARMSIM_GIT_CLONES=/home/user advisor/setup-dev.sh
```

Container run: about 39s from an empty tree, exit 0. It downloads Node 16.20.2
(checksum-verified) and installs compass into `$SWARMSIM_TOOLCHAIN_DIR/gems`. It writes
`$SWARMSIM_TOOLCHAIN_DIR/env.sh`. Then it builds `$SWARMSIM_TOOLCHAIN_DIR/github-mirror`:
one `git archive` tarball per pinned commit, named the way yarn looks it up (about 3s).
Finally it runs `YARN_YARN_OFFLINE_MIRROR=… yarn install --frozen-lockfile`. The clones
are only read. The lockfile has no integrity hashes for these 39 entries, so git's commit
hash is the integrity check. Yarn also copies registry tarballs into that mirror (~170 MB).
The script is idempotent. The mirror step on its own:

```bash
advisor/github-pins-mirror.sh /home/user "$SWARMSIM_TOOLCHAIN_DIR/github-mirror"
```

To populate the clones on a network that blocks codeload but serves plain `git fetch`
from github.com (this container was one), fetch just the pinned commits, one repository
at a time:

```bash
advisor/fetch-github-pins.sh /home/user
```

It reads the 39 `owner/repo` and commit pairs from `swarmsim-coffee/yarn.lock` and skips
any that are already present. In the container all 39 fetched without error.

Without clones, the script falls back to `advisor/npm-bower-fallback.sh`. That fallback
installs npm-registry copies of 33 of the 39 at their pinned versions. Six have no npm
copy and stay missing: swarm-numberformat 0.2.1, swarm-persist 0.0.3,
playfab-sdk-browser, PlayFab JavaScriptSDK 1.0.170130, flash-cookies 2.2.3 and
grunt-wiredep-away. The script then exits 3. With those gaps, Karma aborts at load,
`grunt build`/`serve` stop at `Task "wiredep" not found`, and the app cannot start
(`window.persist` is undefined). The opt-in flag below installs stand-ins that are
**not** the pinned versions: swarm-numberformat 0.2.0 and flash-cookies 2.2.1. Each one
gets a `NOT-THE-PINNED-VERSION.txt` marker. Without the flag, any earlier stand-ins
are removed. Even with them, swarm-persist is still missing, so 5 upstream unit specs
fail (`window.persist.chunker`): command "should do something", "can undo", "undoes
visibility. #639"; mtx "should do something"; playfab "should do something". The
app still cannot fully start.

```bash
advisor/setup-dev.sh --near-versions
```

In **every new shell** (Node 16 is not the system Node):

```bash
. "$SWARMSIM_TOOLCHAIN_DIR/env.sh"
```

`env.sh` also strips `--use-openssl-ca` from `NODE_OPTIONS`. The sandbox sets that flag,
and Node 16 rejects it in worker threads, which breaks Parcel. It also sets
`CHROME_BIN` if unset.

## Install

```bash
yarn install --frozen-lockfile
```

From the repo root, on a network that reaches codeload. `swarmsim-coffee/bower_components`
becomes a symlink to `node_modules/@bower_components`.

## Tests

Everything: tables jest, swarmsim-ts jest, then swarmsim-coffee `grunt pretest` + Karma unit + Karma integration.
`yarn test` stops at the first failing step:

```bash
yarn test
```

swarmsim-coffee only. `yarn _pretest` (~8s) generates `.tmp/scripts/env.js`, which Karma loads; run it once per checkout:

```bash
cd swarmsim-coffee && yarn _pretest && yarn test:unit && yarn test:integration
```

Karma runs PhantomJS 2.1.1 with the upstream configuration, plus one served fixture
(`../advisor/sim/example_save_14h.json`, for the advisor spec). Karma warns that
`konami-js/` and `appcache-nanny/` match no file: upstream lists them but never installs them.

Container run (~41s for `yarn test`):

- `tables`: 10 passed, 3 skipped.
- `swarmsim-ts`: 11 passed.
- Karma unit, upstream baseline at commit 3a161e7: 168 specs, 141 passed, 27 skipped, 0 failed.
- Karma unit with the advisor feature: 239 specs, 193 passed, 27 skipped, 19 failed.
  All 19 failures are in the new `test/spec/directives/advisor.coffee`.
- Karma integration: 4 passed, 1 skipped (~6s).

### One spec file

`advisor/karma-spec.conf.coffee` wraps the upstream Karma config and swaps the spec glob
for `$SPEC`, a file or glob relative to `swarmsim-coffee/`; a path outside that
folder is not compiled. App code, mocks, libraries and served fixtures load as in the
full suite. After `yarn _pretest` once:

```bash
cd swarmsim-coffee && SPEC=test/spec/services/advisor.coffee yarn karma start ../advisor/karma-spec.conf.coffee
```

Container run: about 3s; services/advisor 46 of 46 passed; services/options 8 of 8 passed.
To focus on single `it`s, temporarily use `fit` / `fdescribe` (Jasmine 2.5) and don't commit them.

## Build

Production bundle, also copied to `dist/` at the repo root (container run: ~46s, wiredep included, `app/index.html` left unchanged):

```bash
yarn build
```

The `Loading "cdnify.js" tasks...ERROR primordials` line is harmless; that task is unused.

## Serve and check

### Built `dist/` (port 3000)

The prod build redirects plain http to https unless the URL carries `allowinsecure`, so open
`http://localhost:3000/#/?allowinsecure=1`. Alternatively build with `yarn build:docker`, which allows http.

```bash
yarn start:dist
```

Non-interactive start/stop, from the repo root:

```bash
nohup node_modules/.bin/serve -n -l tcp://127.0.0.1:3000 dist > /tmp/swarmsim-dist.log 2>&1 & echo $! > /tmp/swarmsim-dist.pid
```

```bash
kill "$(cat /tmp/swarmsim-dist.pid)"
```

### Dev server (port 9000; use this for feature work)

`grunt serve` serves the un-minified per-file scripts. It recompiles CoffeeScript on save
(about 3s, coffeelint included) and live-reloads on port 35728; Parcel watches `swarmsim-ts`.
Container run: up in about 12s at `http://localhost:9000/#/`, with no `allowinsecure` needed.

```bash
yarn start
```

Non-interactive start/stop. It runs several processes, so stop it as a process group:

```bash
setsid bash -c 'echo $$ > /tmp/swarmsim-dev.pgid; exec yarn start' > /tmp/swarmsim-dev.log 2>&1 < /dev/null &
```

```bash
kill -- -"$(cat /tmp/swarmsim-dev.pgid)"
```

### Headless boot check

Container run, against both servers, using Playwright's Chromium (Node 20+ is needed for
Playwright, so this ran with the system Node, not Node 16). The game service returned an
object with meat 35 and larvae ~11. Units were listed and no raw `{{…}}` bindings remained.
The Climbing Advisor panel was rendered on the main view. There were no console errors apart
from the external requests the check itself blocks (Google Analytics, a Freshdesk stylesheet).
