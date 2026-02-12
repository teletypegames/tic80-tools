# -----------------------------------------
# Makefile – TIC-80 project builder
# -----------------------------------------

PROJECT = impostor

ORDER      = $(PROJECT).inc
OUTPUT     = $(PROJECT).lua
OUTPUT_ZIP = $(PROJECT).html.zip
OUTPUT_TIC = $(PROJECT).tic

SRC_DIR    = inc
SRC        = $(shell sed 's|^|$(SRC_DIR)/|' $(ORDER))

ASSETS_LUA = inc/meta/meta.assets.lua
ASSETS_DIR = assets
ASSET_TYPES = tiles sprites sfx music

# CI/CD variables
VERSION_FILE = .version
GAME_LANG ?= lua
DROPAREA_HOST ?= vps.teletype.hu
DROPAREA_PORT ?= 2223
DROPAREA_TARGET_PATH ?= /home/drop
DROPAREA_USER ?= drop
UPDATE_SERVER ?= https://games.vps.teletype.hu

all: build

build: $(OUTPUT)

$(OUTPUT): $(SRC) $(ORDER)
	@rm -f $(OUTPUT)
	@while read f; do \
		cat "$(SRC_DIR)/$$f" >> $(OUTPUT); \
		echo "" >> $(OUTPUT); \
	done < $(ORDER)

export: build
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

watch:
	make build
	fswatch -o $(SRC_DIR) $(ORDER) assets | while read; do make build; done

import_assets:
	@for t in $(ASSET_TYPES); do \
		for f in $(ASSETS_DIR)/$$t/*.png; do \
			[ -e "$$f" ] || continue; \
			echo "==> Importing $$f as $$t..."; \
			tic80 --cli --skip --fs=. --cmd="import $$t $$f & exit"; \
		done; \
	done

export_assets: build
	@echo "==> Exporting TIC-80 asset sections"
	@mkdir -p inc/meta
	@sed -n '/^-- <PALETTE>/,/^-- <\/PALETTE>/p;\
	         /^-- <TILES>/,/^-- <\/TILES>/p;\
	         /^-- <SPRITES>/,/^-- <\/SPRITES>/p;\
	         /^-- <MAP>/,/^-- <\/MAP>/p;\
	         /^-- <SFX>/,/^-- <\/SFX>/p;\
	         /^-- <MUSIC>/,/^-- <\/MUSIC>/p' \
		$(OUTPUT) > $(ASSETS_LUA)

clean:
	@rm -f $(PROJECT)-*.tic $(PROJECT)-*.html.zip $(OUTPUT)
	@echo "==> Cleaned build artifacts"

# CI/CD Targets
ci-version:
	@VERSION=$$(sed -n "s/^-- version: //p" inc/meta/meta.header.lua | head -n 1 | tr -d "[:space:]"); \
	BRANCH=$${CI_COMMIT_BRANCH:-$${WOODPECKER_BRANCH}}; \
	BRANCH=$$(echo "$$BRANCH" | tr '/' '-'); \
	if [ "$$BRANCH" != "main" ] && [ "$$BRANCH" != "master" ] && [ -n "$$BRANCH" ]; then \
		VERSION=dev-$$VERSION-$$BRANCH; \
	fi; \
	echo "VERSION is: $$VERSION"; \
	echo $$VERSION > $(VERSION_FILE)

ci-export:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Building and exporting version $$VERSION"; \
	$(MAKE) export VERSION=$$VERSION

ci-upload:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Uploading artifacts for version $$VERSION"; \
	ls -lh $(PROJECT)-$$VERSION.* $(PROJECT).tic $(PROJECT).html.zip 2>/dev/null || true; \
	cp $(PROJECT).lua $(PROJECT)-$$VERSION.lua; \
	FILE_LUA=$(PROJECT)-$$VERSION.lua; \
	FILE_TIC=$(PROJECT)-$$VERSION.tic; \
	FILE_HTML_ZIP=$(PROJECT)-$$VERSION.html.zip; \
	SCP_TARGET="$(DROPAREA_USER)@$(DROPAREA_HOST):$(DROPAREA_TARGET_PATH)/"; \
	sshpass -p "$(DROPAREA_SSH_PASSWORD)" scp -o StrictHostKeyChecking=no -P $(DROPAREA_PORT) $$FILE_LUA $$FILE_TIC $$FILE_HTML_ZIP $$SCP_TARGET

ci-update:
	@VERSION=$$(cat $(VERSION_FILE)); \
	echo "==> Triggering update for version $$VERSION"; \
	curl "$(UPDATE_SERVER)/update?secret=$(UPDATE_SECRET)&name=$(PROJECT)&platform=tic80&version=$$VERSION"

.PHONY: all build export watch import_assets export_assets clean ci-version ci-export ci-upload ci-update

