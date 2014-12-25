#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/base_rules

.PHONY: clean all

all:	themedatahax_v94.lz

clean:
	rm -f themedata_payload_v94.elf themedata_payload_v94.bin themedatahax_v94.lz

themedatahax_v94.lz:	themedata_payload_v94.bin
	python3 payload.py $< $@ 0x4652 0x100000 0x00313828 0x35052080

themedata_payload_v94.bin:	themedata_payload_v94.elf
	$(OBJCOPY) -O binary $< $@

themedata_payload_v94.elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib $< -o $@

