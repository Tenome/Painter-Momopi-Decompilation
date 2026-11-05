# Build the ROM with RGBDS (https://rgbds.gbdev.io, 0.9 or newer) and compare it with the original.
#   make           assemble, link, and compare SHA-1 with the original
#   make report    refresh progress/jp/report.json from the built ROM
ROM  := build/painter_momopie.gb
SRCS := $(wildcard src/*.asm)
OBJS := $(patsubst src/%.asm,build/%.o,$(SRCS))
SHA1 := 193901223ffc89cf4f42a19e57447249affcc843

all:
	@python tools/build.py

all-make: $(ROM)
	@python tools/check_rom.py $(ROM) $(SHA1)

$(ROM): $(OBJS)
	rgblink -p 0xFF -n build/painter_momopie.sym -m build/painter_momopie.map -o $@ $(OBJS)

build/%.o: src/%.asm | build
	rgbasm -o $@ $<

build:
	mkdir -p build

report: $(ROM)
	python tools/report.py --built $(ROM)

# No RGBDS? The in-repo reference assembler proves the sources reproduce the ROM:
check:
	python tools/gb_dis.py --check

.PHONY: all report check
