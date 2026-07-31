# tic80-tools

CI/CD templates for [TIC-80](https://tic80.com) (Lua) game projects.

- `example-makefile.make` — project Makefile: local dev targets
  (`build`, `minify`, `watch`, `lint`, `docs`, `import_assets`,
  `export_assets`, `clean`, `install_precommit_hook`) plus the
  Woodpecker pipeline targets (`ci-version`, `ci-lint`, `ci-minify`,
  `ci-docs`, `ci-export`, `ci-artifact`, `ci-update`).
- `example-woodpecker.yaml` — Woodpecker pipeline: version → lint →
  minify → docs → export (TIC-80 Pro image) → artifact (scp to the
  droparea) → update (calls the teletypegames `/update` endpoint with
  `platform=tic80`).
- `example-tasks.json` — VS Code `.vscode/tasks.json` with the common
  dev tasks: **Run TIC80** (default build task, `Cmd+Shift+B`),
  **Build & Run TIC80**, **Export assets** and **Make build**.

## Usage in a game repo

1. Copy `example-makefile.make` to `Makefile` and set `PROJECT`
   (the cartridge is built as `$(PROJECT).lua` from the file list in
   `$(PROJECT).inc`).
2. Copy `example-woodpecker.yaml` to `.woodpecker.yaml` and add the
   `droparea_ssh_password` / `update_secret_key` secrets in Woodpecker.
3. Copy `example-tasks.json` to `.vscode/tasks.json` and replace the
   cart name (`impostor.lua`) with `$(PROJECT).lua`.

The pipeline uploads `$(PROJECT)-$(VERSION).lua`, `.tic`, `.html.zip`
and `-docs.zip` to the droparea, then triggers
`/update?platform=tic80&name=$(PROJECT)&version=$(VERSION)`.

## Builder image

The export step uses the TIC-80 Pro image
(`git.teletypegames.org/internal/tic80pro`, built from the
`tic80pro-dockerfile` repo). For the lint / minify / docs steps,
`builder.Dockerfile` bakes Lua 5.4 + luacheck + ldoc + zip into
`git.teletypegames.org/internal/tic80-luatools`, so the pipeline no longer
runs luarocks (and a C compiler install) on every run:

```sh
docker build --platform linux/amd64 -f builder.Dockerfile \
  -t git.teletypegames.org/internal/tic80-luatools:latest .
docker push git.teletypegames.org/internal/tic80-luatools:latest
```

Detailed documentation lives on the wiki: `/development/tic80`.
