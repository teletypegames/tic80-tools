# tic80-tools

CI/CD templates for [TIC-80](https://tic80.com) (Lua) game projects.

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `minify`, `binaries`, `watch`, `lint`, `docs`,
  `import_assets`, `export_assets`, `clean`, `install_precommit_hook`).
- `example-woodpecker.yaml` — a one-line marker (`platform: tic80`): the
  full pipeline (version → lint → minify → docs → export → binaries →
  artifact → publish) is served by the update server's Woodpecker
  configuration extension — preview it with
  `curl "https://teletypegames.org/build/config?platform=tic80"`.
- `example-tasks.json` — VS Code `.vscode/tasks.json` with the common
  dev tasks: **Run TIC80** (default build task, `Cmd+Shift+B`),
  **Build & Run TIC80**, **Export assets** and **Make build**.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile` and set `PROJECT`
   (the cartridge is built as `$(PROJECT).lua` from the file list in
   `$(PROJECT).inc`).
2. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` (a one-line
   marker — the pipeline itself is served by the update server; add
   `name:` when the software name differs from the repo name) and add
   the `application_token` secret in Woodpecker (an ApplicationToken
   with the `update` + `upload` scopes, created in the admin).
3. Copy `example-tasks.json` to `.vscode/tasks.json` and replace the
   cart name (`impostor.lua`) with `$(PROJECT).lua`.

The served pipeline uploads `$(PROJECT)-$(VERSION).lua`, `.tic`, `.html.zip`,
`-docs.zip` and the native player zips (`-win-x64.zip`,
`-linux-x64.zip`, `-mac-x64.zip`) via `/build/upload`, then triggers
`/build/publish?platform=tic80&name=$(PROJECT)&version=$(VERSION)`. The API's
`BinaryAttachment` concern picks up the `<name>-<version>-<slug>.zip`
files automatically and registers them as `win_x64` / `linux_x64` /
`mac_x64` release assets.

## Native binaries

`make binaries VERSION=x.y` runs TIC-80's `export win / linux / mac`,
which produces self-contained players with the cart baked in. Two
things to know:

- The player templates are **downloaded from tic80.com at export
  time**, so the CI step needs network access (the Woodpecker steps
  have it — the same way the artifact step reaches the API).
- All upstream players are x86-64 — the mac binary is Intel-only
  (runs via Rosetta on Apple Silicon), hence the `mac-x64` slug.

Each binary is zipped with a single `$(PROJECT)-$(VERSION)-<slug>/`
root folder; the zip is created on unix so the executable bit
survives.

Detailed documentation lives on the wiki: `/development/tic80`.
