GODOT ?= /Applications/Godot_mono.app/Contents/MacOS/Godot
RUN_ARGS ?=

.PHONY: run

run:
	"$(GODOT)" --path "$(CURDIR)" $(RUN_ARGS)
