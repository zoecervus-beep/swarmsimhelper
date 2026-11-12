# Building and testing this fork

Status, Nov 12 2026: the toolchain (Node 16, yarn, compass) and the `tables` and
`swarmsim-ts` workspaces are verified working. `swarmsim-coffee` (the game itself)
is **not yet verified**: its `yarn install` needs ~39 GitHub tarballs from
`codeload.github.com`, which the cloud sandbox this was set up in refuses with
HTTP 403 ("GitHub access to this repository is not enabled for this session").
Steps below marked *(unverified)* follow upstream CI and the Dockerfile but have not
been run here yet.

## What you need

| Tool | Version | Why |
| --- | --- | --- |
| Node | 16.x (16.20.2 tested) | upstream CI version; Grunt 1.0 / Karma 1.5 era tooling |
| yarn | 1.x (1.22.22) | workspaces are linked with `yarn link` by the root `install` script |
| Ruby + `compass` gem | Ruby 2.5 to 3.3; compass 1.0.3 | `grunt build` and `grunt serve` compile Sass with compass |
| PhantomJS 2.1.1 | downloaded by `yarn install` | Karma unit and integration suites run in PhantomJS |
| Network | npm registry, codeload.github.com, github.com releases | bower deps are GitHub tarballs; PhantomJS binary is a GitHub release |

Two compatibility workarounds, both applied by `advisor/setup-dev.sh` through the
generated `env.sh`:

- Ruby 3.2+ removed `File.exists?`, which compass/sass 3.4 call. A two-line shim
  is loaded through `RUBYOPT`.
- PhantomJS 2.1.1 aborts ("Auto configuration failed ... libproviders.so") when
  it reads a modern OpenSSL config, so `OPENSSL_CONF=/dev/null` is exported (the
  upstream Dockerfile does the same).

## (a) Linux container (like the Claude Code cloud sandbox)

One-time setup. Toolchain goes outside the repo; pick any directory.

```bash
export SWARMSIM_TOOLCHAIN_DIR="$HOME/.cache/swarmsim-toolchain"
```

```bash
advisor/setup-dev.sh
```

It downloads Node 16.20.2 (checksum-verified), installs the compass gem into
`$SWARMSIM_TOOLCHAIN_DIR/gems`, writes `$SWARMSIM_TOOLCHAIN_DIR/env.sh`, checks that
GitHub tarballs are downloadable, then runs `yarn install --frozen-lockfile` at the
repo root. It is idempotent. If the GitHub check fails it exits with code 2 before
installing; the toolchain part is still done.

In **every new shell** (Node 16 is not the system Node):

```bash
. "$SWARMSIM_TOOLCHAIN_DIR/env.sh"
```

`env.sh` also strips `--use-openssl-ca` from `NODE_OPTIONS` (the sandbox sets it;
Node 16 rejects it in worker threads, which breaks Parcel) and sets `CHROME_BIN` to
the sandbox Chromium if one is found.

## (b) Your own machine

Install Node 16 with your version manager, yarn 1, Ruby, and compass:

```bash
nvm install 16 && nvm use 16
```

```bash
npm install -g yarn@1.22.22
```

```bash
gem install compass
```

On Ruby 3.2 or newer, compass needs the shim; easiest is to let the script do
it (it also works when Node 16 is already on PATH; it then skips the download):

```bash
advisor/setup-dev.sh
```

```bash
. "${XDG_CACHE_HOME:-$HOME/.cache}/swarmsim-toolchain/env.sh"
```

On macOS the script's Node download is Linux-only; use nvm as above so it finds
Node 16 on PATH. PhantomJS on macOS/Apple Silicon may need Rosetta.

## Install

```bash
yarn install --frozen-lockfile
```

Run from the repo root. Links and installs `tables`, `swarmsim-ts`, `swarmsim-coffee`.
`swarmsim-coffee/bower_components` becomes a symlink to `node_modules/@bower_components`.

## Tests

All workspaces (tables jest, swarmsim-ts jest, then swarmsim-coffee pretest + Karma unit + Karma integration):

```bash
yarn test
```

Verified parts: `tables` 10 passed, 3 skipped (2 suites skipped upstream); `swarmsim-ts`
11 passed. `swarmsim-coffee` part *(unverified)*.

Only the swarmsim-coffee Karma unit suite *(unverified)*. `yarn _pretest` generates
`.tmp/scripts/env.js`, which the Karma config loads; run it once per checkout:

```bash
cd swarmsim-coffee && yarn _pretest && yarn test:unit
```

### One spec file *(unverified)*

`advisor/karma-spec.conf.coffee` wraps the upstream Karma config and swaps the
spec glob for `$SPEC` (file or glob, relative to `swarmsim-coffee/`). App code,
mocks and libraries load as in the full suite. After `yarn _pretest` once:

```bash
cd swarmsim-coffee && SPEC=test/spec/services/unit.coffee yarn karma start ../advisor/karma-spec.conf.coffee
```

To focus on a few `it`s inside that file, temporarily use `fit` / `fdescribe`
(Jasmine 2.5); do not commit them.

## Build and serve *(unverified)*

Production bundle, copied to `dist/` at the repo root:

```bash
yarn build
```

Serve `dist/` (static, `serve` picks port 3000):

```bash
yarn start:dist
```

Dev server with live reload (`grunt serve`, port 9000, or `$PORT`), plus Parcel
watching `swarmsim-ts`:

```bash
yarn start
```
