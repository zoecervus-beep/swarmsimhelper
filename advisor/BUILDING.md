# Building and testing this fork

## Status (Nov 12 2026)

On a normal network (your machine, CI) none of the container caveats below apply:
`yarn install` fetches the real pinned GitHub sources. That path has **not** been run
by us; it is what upstream CI does.

In the Claude Code cloud container used to set this up, `codeload.github.com` is
refused (HTTP 403), so `swarmsim-coffee`'s 39 GitHub-pinned dependencies were
installed from **npm-registry copies** by `advisor/npm-bower-fallback.sh`. Six have no
npm copy at the pinned version and are missing there:

| Missing in the container | Blocks |
| --- | --- |
| `swarm-numberformat` 0.2.1 (npm has 0.2.0, 0.3.0) | Karma unit and integration suites (abort at load: `Can't find variable: numberformat`), number display in the game |
| `swarm-persist` 0.0.3 (unpublished from npm) and its dep `playfab-sdk-browser` | 5 unit specs (command, mtx, playfab); game bootstrap (`window.persist.chunker`) |
| `playfab-sdk` = PlayFab/JavaScriptSDK 1.0.170130 (not on npm) | PlayFab login/save at run time |
| `flash-cookies` 2.2.3 (npm has 2.2.1) | Flash storage fallback |
| `grunt-wiredep-away` (gscavalcante fork, not on npm) | `grunt build` and `grunt serve` (`Task "wiredep" not found`) |

So in the container: install, the `tables`/`swarmsim-ts` tests and the `grunt pretest`
step are verified; the Karma suites, build, serve and boot are blocked by the gaps
above. Each step below says what was actually run.

## What you need

| Tool | Version | Why |
| --- | --- | --- |
| Node | 16.x (16.20.2 tested) | upstream CI version; Grunt 1.0 / Karma 1.5 era tooling |
| yarn | 1.x (1.22.22) | workspaces are linked with `yarn link` by the root `install` script |
| Ruby + `compass` gem | Ruby 2.5 to 3.3; compass 1.0.3 | `grunt pretest`, `build`, `serve` compile Sass with compass |
| PhantomJS 2.1.1 | downloaded by `yarn install` (GitHub release) | Karma unit and integration suites |
| Network | npm registry, codeload.github.com, github.com releases | bower deps are GitHub tarballs; PhantomJS is a GitHub release |

Two compatibility workarounds, both applied by the `env.sh` that `advisor/setup-dev.sh` writes:

- Ruby 3.2+ removed `File.exists?`, which compass/sass 3.4 call; a two-line shim is loaded through `RUBYOPT`.
- PhantomJS 2.1.1 aborts on modern OpenSSL configs ("Auto configuration failed ... libproviders.so"), so `OPENSSL_CONF=/dev/null` is exported (upstream's Dockerfile does the same).

## (a) Linux container (like the Claude Code cloud sandbox)

Pick a toolchain directory outside the repo:

```bash
export SWARMSIM_TOOLCHAIN_DIR="$HOME/.cache/swarmsim-toolchain"
```

```bash
advisor/setup-dev.sh
```

It downloads Node 16.20.2 (checksum-verified), installs compass into
`$SWARMSIM_TOOLCHAIN_DIR/gems`, writes `$SWARMSIM_TOOLCHAIN_DIR/env.sh`, then:

- if `codeload.github.com` works: `yarn install --frozen-lockfile` (exit 0);
- otherwise: installs root/`tables`/`swarmsim-ts` normally and `swarmsim-coffee` through
  `advisor/npm-bower-fallback.sh`, prints the gaps, and exits 3.

Idempotent. Verified in the container from an empty tree: ~46s (fallback path, exit 3).
The fallback never leaves `swarmsim-coffee/package.json` or `yarn.lock` changed (it
edits package.json only temporarily, restores it from an EXIT trap, and runs yarn with
`--pure-lockfile`; checked with `git status`, including when yarn fails).
A later plain `yarn install` in `swarmsim-coffee` will try GitHub again; re-run the
setup script instead.

In **every new shell** (Node 16 is not the system Node):

```bash
. "$SWARMSIM_TOOLCHAIN_DIR/env.sh"
```

`env.sh` also strips `--use-openssl-ca` from `NODE_OPTIONS` (the sandbox sets it; Node
16 rejects it in worker threads, which breaks Parcel) and sets `CHROME_BIN` if unset.

## (b) Your own machine

```bash
nvm install 16 && nvm use 16
```

```bash
npm install -g yarn@1.22.22
```

Then the same script (finds Node 16 on PATH; installs compass and the Ruby 3.2+ shim if needed):

```bash
advisor/setup-dev.sh
```

```bash
. "${XDG_CACHE_HOME:-$HOME/.cache}/swarmsim-toolchain/env.sh"
```

The script's own Node download is Linux x64 only; on macOS use nvm as above.
PhantomJS on Apple Silicon may need Rosetta.

## Install

```bash
yarn install --frozen-lockfile
```

From the repo root (normal network only). `swarmsim-coffee/bower_components` becomes a
symlink to `node_modules/@bower_components`.

## Tests

Everything (tables jest, swarmsim-ts jest, swarmsim-coffee `grunt pretest` + Karma unit + Karma integration):

```bash
yarn test
```

Container run (~44s): `tables` 10 passed, 3 skipped (2 suites skipped upstream);
`swarmsim-ts` 11 passed; `grunt pretest` OK (69 files lint free); Karma unit then aborts
at load on the `swarm-numberformat` gap, so 0 Karma specs run. The
`Loading "cdnify.js" tasks...ERROR primordials` line is harmless (that task is unused).

swarmsim-coffee only. `yarn _pretest` generates `.tmp/scripts/env.js`, which Karma loads; run it once per checkout (~8s):

```bash
cd swarmsim-coffee && yarn _pretest && yarn test:unit && yarn test:integration
```

Karma runs PhantomJS 2.1.1 (works in the container with `OPENSSL_CONF=/dev/null`);
the upstream config is unchanged. Karma warns that `konami-js/` and `appcache-nanny/`
don't match any file: upstream lists them but never installs them.

### One spec file

`advisor/karma-spec.conf.coffee` wraps the upstream Karma config and swaps the spec glob
for `$SPEC` (file or glob, relative to `swarmsim-coffee/`); app code, mocks and
libraries load as in the full suite. After `yarn _pretest` once:

```bash
cd swarmsim-coffee && SPEC=test/spec/services/unit.coffee yarn karma start ../advisor/karma-spec.conf.coffee
```

Ran in the container (~3s, 30 passed, 1 skipped) only with the `swarm-numberformat`
gap temporarily filled by npm 0.2.0, which is not the pinned version; with the gap,
it aborts at load like the full suite. To focus on single `it`s, temporarily use
`fit` / `fdescribe` (Jasmine 2.5) and don't commit them.

## Build and serve *(not run in the container: blocked by the grunt-wiredep-away gap)*

Production bundle, copied to `dist/` at the repo root:

```bash
yarn build
```

Serve `dist/` on http://localhost:3000. The prod build redirects plain http to https
unless the URL carries `allowinsecure`, so open `http://localhost:3000/#/?allowinsecure=1`
(or build with `yarn build:docker`, which allows http):

```bash
yarn start:dist
```

Non-interactive start/stop (from the repo root):

```bash
nohup node_modules/.bin/serve -n -l tcp://127.0.0.1:3000 dist > /tmp/swarmsim-serve.log 2>&1 & echo $! > /tmp/swarmsim-serve.pid
```

```bash
kill "$(cat /tmp/swarmsim-serve.pid)"
```

Dev server with live reload (`grunt serve`, port 9000 or `$PORT`) plus Parcel watching `swarmsim-ts`:

```bash
yarn start
```
