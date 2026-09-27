ifeq ($(shell uname -s),Darwin)
GODOT ?= $(CURDIR)/docs/godot/bin/godot.macos.template_debug.$(shell uname -m)
else
GODOT ?= godot
endif
RUN_ARGS ?=

.PHONY: run build-macos

run:
	@command -v "$(GODOT)" >/dev/null || { echo 'Godot not found. On macOS, run make build-macos first; or set GODOT=/path/to/Godot.'; exit 1; }
	"$(GODOT)" --path "$(CURDIR)" $(RUN_ARGS)

build-macos:
	tools/build_godot_macos.sh
