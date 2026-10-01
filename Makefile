ifeq ($(shell uname -s),Darwin)
GODOT ?= $(CURDIR)/docs/godot/bin/godot.macos.template_debug.$(shell uname -m)
else
GODOT ?= godot
endif
RUN_ARGS ?=

.PHONY: run run-web build-macos build-web export-web serve-web

run:
	@command -v "$(GODOT)" >/dev/null || { echo 'Godot not found. On macOS, run make build-macos first; or set GODOT=/path/to/Godot.'; exit 1; }
	"$(GODOT)" --path "$(CURDIR)" $(RUN_ARGS)

build-macos:
	tools/build_godot_macos.sh

build-web:
	tools/build_godot_web.sh

export-web:
	tools/export_web.sh

run-web: export-web
	$(MAKE) serve-web

serve-web:
	python3 tools/serve_web.py --port $(or $(WEB_PORT),8060)
