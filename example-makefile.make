# -----------------------------------------
# Makefile – TIC-80 project builder
# -----------------------------------------

PROJECT = impostor

ORDER      = $(PROJECT).inc
OUTPUT     = $(PROJECT).lua
OUTPUT_ORIGINAL   = $(PROJECT).original.lua
OUTPUT_ZIP = $(PROJECT).html.zip
OUTPUT_TIC = $(PROJECT).tic

MINIFY     = minify.lua
MINIFY_URL = https://raw.githubusercontent.com/ztimar31/lua-minify-tic80/refs/heads/master/minify.lua

SRC_DIR    = inc
SRC        = $(shell sed 's|^|$(SRC_DIR)/|' $(ORDER))

ASSETS_LUA = inc/meta/meta.assets.lua
ASSETS_DIR = assets
ASSET_TYPES = tiles sprites sfx music

LINT_TMP_LUA  := /tmp/_lint_combined.lua
LINT_TMP_MAP   := /tmp/_lint_map.txt

# CI/CD variables
VERSION_FILE = .version
GAME_LANG ?= lua
UPDATE_SERVER ?= https://teletypegames.org

all: build

build:
	@rm -f $(OUTPUT)
	@sed 's/\r$$//' $(ORDER) | while read f; do \
		cat "$(SRC_DIR)/$$f" >> $(OUTPUT); \
		echo "" >> $(OUTPUT); \
	done

download-minify:
	@test -f $(MINIFY) || { echo "==> Downloading $(MINIFY)"; curl -fsSL $(MINIFY_URL) -o $(MINIFY); }

minify: build download-minify
	@echo "==> Minifying $(OUTPUT)"
	@cp $(OUTPUT) $(OUTPUT_ORIGINAL)
	@lua $(MINIFY) minify $(OUTPUT_ORIGINAL) > $(OUTPUT)

export: minify
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; \
		exit 1; \
	fi
	@echo "==> Exporting HTML for version $(VERSION)"
	@tic80 --cli --skip --fs=. \
		--cmd="load $(OUTPUT) & save $(PROJECT)-$(VERSION) & export html $(PROJECT)-$(VERSION).html & exit"
	@echo "==> Creating versioned files"
	@if [ -f "$(PROJECT)-$(VERSION).tic" ]; then \
		cp $(PROJECT)-$(VERSION).tic $(PROJECT).tic; \
	fi
	@if [ -f "$(PROJECT)-$(VERSION).html.zip" ]; then \
		cp $(PROJECT)-$(VERSION).html.zip $(PROJECT).html.zip; \
	fi
	@echo "==> Generated files:"
	@ls -lh $(PROJECT)-$(VERSION).* $(PROJECT).tic $(PROJECT).html.zip 2>/dev/null || true

# -----------------------------------------
# Native binaries — self-contained TIC-80 players with the cart baked in.
# The player templates are downloaded from tic80.com at export time, so
# this target needs network access. All upstream players are x86-64,
# hence the win-x64 / linux-x64 / mac-x64 slugs (the API maps
# <project>-<version>-<slug>.zip droparea files to ReleaseAsset kinds).
# -----------------------------------------

BINARY_SLUGS = win-x64 linux-x64 mac-x64

# $(1) slug, $(2) exported file, $(3) file name inside the package
# (unixos zip őrzi a végrehajtási bitet)
define f_pack_binary
	PKG_DIR="$(PROJECT)-$(VERSION)-$(1)"; \
	rm -rf "$$PKG_DIR" "$$PKG_DIR.zip"; \
	mkdir -p "$$PKG_DIR"; \
	mv "$(2)" "$$PKG_DIR/$(3)"; \
	chmod +x "$$PKG_DIR/$(3)"; \
	zip -r "$$PKG_DIR.zip" "$$PKG_DIR" >/dev/null; \
	rm -rf "$$PKG_DIR"; \
	echo "==> $$PKG_DIR.zip kesz"
endef

binaries:
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; \
		exit 1; \
	fi
	@echo "==> Exporting native players for version $(VERSION)"
	@tic80 --cli --skip --fs=. \
		--cmd="load $(OUTPUT) & export win $(PROJECT)-win & export linux $(PROJECT)-linux & export mac $(PROJECT)-mac & exit"
	@$(call f_pack_binary,win-x64,$(PROJECT)-win.exe,$(PROJECT).exe)
	@$(call f_pack_binary,linux-x64,$(PROJECT)-linux,$(PROJECT))
	@$(call f_pack_binary,mac-x64,$(PROJECT)-mac,$(PROJECT))

watch:
	$(MAKE) build
	fswatch -o $(SRC_DIR) $(ORDER) assets | while read; do $(MAKE) build; done

import_assets: build
	@TIC_CMD="load $(OUTPUT) &"; \
	for t in $(ASSET_TYPES); do \
		for f in $(ASSETS_DIR)/$$t/*.png; do \
			[ -e "$$f" ] || continue; \
			echo "==> Importing $$f as $$t..."; \
			TIC_CMD="$${TIC_CMD} & import $$t $$f"; \
		done; \
	done; \
	TIC_CMD="$$TIC_CMD save & exit"; \
	echo $$TIC_CMD; \
	tic80 --cli --skip --fs=. --cmd="$$TIC_CMD"

# export helper function
define f_export_asset_awk
	cat $(2) | awk '/-- <$(1)>/,/<\/$(1)>/' >> $(3)
endef

lint:
	@echo "==> Merging..."
	@rm -f $(LINT_TMP_LUA) $(LINT_TMP_MAP)
	@touch $(LINT_TMP_LUA)
	@line=1; \
	while IFS= read -r f || [ -n "$$f" ]; do \
	    f=$$(printf '%s' "$$f" | tr -d '\r'); \
	    [ -z "$$f" ] && continue; \
	    before=$$(wc -l < $(LINT_TMP_LUA)); \
	    cat "$(SRC_DIR)/$$f" >> $(LINT_TMP_LUA); \
	    printf '\n' >> $(LINT_TMP_LUA); \
	    after=$$(wc -l < $(LINT_TMP_LUA)); \
	    linecount=$$((after - before)); \
	    echo "$$line $$linecount $(SRC_DIR)/$$f" >> $(LINT_TMP_MAP); \
	    line=$$((line + linecount)); \
	done < $(ORDER)
	@echo "==> luacheck..."
	@LINT_OUTPUT=$$(luacheck --no-max-line-length $(LINT_TMP_LUA) 2>&1 | awk -v map=$(LINT_TMP_MAP) ' \
	BEGIN { \
	    NR_map = 0; \
	    while ((getline line < map) > 0) { \
	        n = split(line, a, " "); \
	        start[NR_map] = a[1]+0; \
	        count[NR_map] = a[2]+0; \
	        fname[NR_map] = a[3]; \
	        NR_map++; \
	    } \
	} \
	/^[^:]+:[0-9]+:[0-9]+:/ { \
	    colon1 = index($$0, ":"); \
	    rest1  = substr($$0, colon1+1); \
	    colon2 = index(rest1, ":"); \
	    absline = substr(rest1, 1, colon2-1) + 0; \
	    rest2  = substr(rest1, colon2+1); \
	    colon3 = index(rest2, ":"); \
	    col    = substr(rest2, 1, colon3-1); \
	    rest   = substr(rest2, colon3); \
	    found  = 0; \
	    for (i = 0; i < NR_map; i++) { \
	        end_line = start[i] + count[i] -1; \
	        if (absline >= start[i] && absline <= end_line) { \
	            relline = absline - start[i] + 1; \
	            print fname[i] ":" relline ":" col ":" rest; \
	            found = 1; \
	            break; \
	        } \
	    } \
	    if (!found) print $$0; \
	    next; \
	} \
	{ print } \
	'); \
	echo "$$LINT_OUTPUT"; \
	NUM_ISSUES=$$(echo "$$LINT_OUTPUT" | grep -cE "^[^:]+:[0-9]+:[0-9]+:"); \
	if [ "$$NUM_ISSUES" -gt 0 ]; then \
	    echo "Total: $$NUM_ISSUES issue(s) found, commit aborted."; \
	    exit 1; \
	else \
	    echo "Checking /tmp/_lint_combined.lua                  OK"; \
	    echo "Total: 0 warnings / 0 errors in 1 file"; \
	fi
	@rm -f $(LINT_TMP_LUA) $(LINT_TMP_MAP)

export_assets:
# $(OUTPUT) would be a circular dependency
	@test -e $(OUTPUT)
	@echo "==> Exporting TIC-80 asset sections"
	@mkdir -p inc/meta
	@echo -n '' > $(ASSETS_LUA)
	@$(call f_export_asset_awk,PALETTE,$(OUTPUT),$(ASSETS_LUA))
	@$(call f_export_asset_awk,TILES,$(OUTPUT),$(ASSETS_LUA))
	@$(call f_export_asset_awk,SPRITES,$(OUTPUT),$(ASSETS_LUA))
	@$(call f_export_asset_awk,MAP,$(OUTPUT),$(ASSETS_LUA))
	@$(call f_export_asset_awk,SFX,$(OUTPUT),$(ASSETS_LUA))
	@$(call f_export_asset_awk,WAVES,$(OUTPUT),$(ASSETS_LUA))

clean:
	@rm -f $(PROJECT)-*.tic $(PROJECT)-*.html.zip $(PROJECT)-*-docs.zip $(PROJECT)-docs.zip $(OUTPUT) $(OUTPUT_ORIGINAL)
	@rm -f $(PROJECT)-*-win-x64.zip $(PROJECT)-*-linux-x64.zip $(PROJECT)-*-mac-x64.zip
	@rm -f $(PROJECT)-win.exe $(PROJECT)-linux $(PROJECT)-mac
	@echo "==> Cleaned build artifacts"

install_precommit_hook:
	@echo "Installing Git pre-commit hook (lint check)..."
	@mkdir -p .git/hooks
	@printf '#!/bin/bash\n' > .git/hooks/pre-commit
	@printf 'echo "Running lint before commit..."\n' >> .git/hooks/pre-commit
	@printf 'make lint\n' >> .git/hooks/pre-commit
	@printf 'if [ $$? -ne 0 ]; then\n' >> .git/hooks/pre-commit
	@printf '    echo "Lint failed! Commit aborted."\n' >> .git/hooks/pre-commit
	@printf '    exit 1\n' >> .git/hooks/pre-commit
	@printf 'fi\n' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "Pre-commit hook installed successfully."

docs: build
	@echo "==> Checking for ldoc..."
	@if ! command -v ldoc &> /dev/null; then \
		echo "ldoc not found, attempting to install with luarocks..."; \
		if command -v luarocks &> /dev/null; then \
			luarocks install ldoc; \
		else \
			echo "Error: luarocks not found. Please install luarocks and then ldoc manually."; \
			exit 1; \
		fi; \
	fi
	@echo "==> Running ldoc..."
	@ldoc ${OUTPUT} -d docs
	@echo "==> Documentation generated."

# -----------------------------------------
# CI/CD Pipeline targets
# -----------------------------------------

ci-version:
	@VERSION=$$(sed -n "s/^-- version: //p" inc/meta/meta.header.lua | head -n 1 | tr -d "[:space:]"); \
	BRANCH=$${CI_COMMIT_BRANCH:-$${WOODPECKER_BRANCH}}; \
	BRANCH=$$(echo "$$BRANCH" | tr '/' '-'); \
	if [ "$$BRANCH" != "main" ] && [ "$$BRANCH" != "master" ] && [ -n "$$BRANCH" ]; then \
		VERSION=dev-$$VERSION-$$BRANCH; \
	fi; \
	echo "VERSION is: $$VERSION"; \
	echo $$VERSION > $(VERSION_FILE)

ci-lint: lint

ci-minify: minify

ci-docs:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Generating docs from $(OUTPUT_ORIGINAL)"; \
	ldoc $(OUTPUT_ORIGINAL) -d docs; \
	echo "==> Zipping docs for version $$VERSION"; \
	(cd docs && zip -r ../$(PROJECT)-$$VERSION-docs.zip .); \
	cp $(PROJECT)-$$VERSION-docs.zip $(PROJECT)-docs.zip; \
	echo "==> Docs zip created"

ci-export:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Exporting HTML for version $$VERSION"; \
	tic80 --cli --skip --fs=. \
		--cmd="load $(OUTPUT) & save $(PROJECT)-$$VERSION & export html $(PROJECT)-$$VERSION.html & exit"; \
	if [ -f "$(PROJECT)-$$VERSION.tic" ]; then \
		cp $(PROJECT)-$$VERSION.tic $(PROJECT).tic; \
	fi; \
	if [ -f "$(PROJECT)-$$VERSION.html.zip" ]; then \
		cp $(PROJECT)-$$VERSION.html.zip $(PROJECT).html.zip; \
	fi; \
	echo "==> Generated files:"; \
	ls -lh $(PROJECT)-$$VERSION.* $(PROJECT).tic $(PROJECT).html.zip 2>/dev/null || true

ci-binaries:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) binaries VERSION=$$VERSION

ci-artifact:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Uploading artifacts for version $$VERSION"; \
	cp $(PROJECT).lua $(PROJECT)-$$VERSION.lua; \
	BINS=""; \
	for slug in $(BINARY_SLUGS); do \
		[ -f "$(PROJECT)-$$VERSION-$$slug.zip" ] && BINS="$$BINS $(PROJECT)-$$VERSION-$$slug.zip"; \
	done; \
	for f in $(PROJECT)-$$VERSION.lua $(PROJECT)-$$VERSION.tic $(PROJECT)-$$VERSION.html.zip $(PROJECT)-$$VERSION-docs.zip $$BINS; do \
		curl -fsS -H "X-Update-Secret: $(UPDATE_SECRET)" \
			-F "file=@$$f" \
			"$(UPDATE_SERVER)/build/upload?name=$(PROJECT)&version=$$VERSION" || exit 1; \
	done

ci-publish:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Triggering update for version $$VERSION"; \
	curl -fsS -X POST -H "X-Update-Secret: $(UPDATE_SECRET)" "$(UPDATE_SERVER)/build/publish?name=$(PROJECT)&platform=tic80&version=$$VERSION"

.PHONY: all build download-minify minify export binaries watch import_assets export_assets clean lint install_precommit_hook docs ci-version ci-lint ci-minify ci-docs ci-export ci-binaries ci-artifact ci-publish
