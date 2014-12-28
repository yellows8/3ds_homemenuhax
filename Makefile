#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/base_rules

.PHONY: clean all

all:	themedatahax_v94.lz themedatahax_v93.lz themedatahax_v92.lz themedatahax_v91j.lz themedatahax_v90.lz

clean:
	rm -f themedata_payload_v94.elf themedata_payload_v94.bin themedatahax_v94.lz
	rm -f themedata_payload_v93.elf themedata_payload_v93.bin themedatahax_v93.lz
	rm -f themedata_payload_v92.elf themedata_payload_v92.bin themedatahax_v92.lz
	rm -f themedata_payload_v91j.elf themedata_payload_v91j.bin themedatahax_v91j.lz
	rm -f themedata_payload_v90.elf themedata_payload_v90.bin themedatahax_v90.lz

themedatahax_v94.lz:	themedata_payload_v94.bin
	python3 payload.py $< $@ 0x4652 0x100000 0x0FFFFEA4 0x35052144

themedatahax_v93.lz:	themedata_payload_v93.bin
	python3 payload.py $< $@ 0x4652 0x100000 0x0FFFFEA4 0x35052144

themedatahax_v92.lz:	themedata_payload_v92.bin
	python3 payload.py $< $@ 0x4652 0x100000 0x0FFFFEA4 0x35052144

themedatahax_v91j.lz:	themedata_payload_v91j.bin
	python3 payload.py $< $@ 0x4652 0x100000 0x0FFFFEA4 0x35052144

themedatahax_v90.lz:	themedata_payload_v90.bin
	python3 payload.py $< $@ 0x4652 0x100000 0x0FFFFEA4 0x35052144

themedata_payload_v94.bin:	themedata_payload_v94.elf
	$(OBJCOPY) -O binary $< $@

themedata_payload_v93.bin:	themedata_payload_v93.elf
	$(OBJCOPY) -O binary $< $@

themedata_payload_v92.bin:	themedata_payload_v92.elf
	$(OBJCOPY) -O binary $< $@

themedata_payload_v91j.bin:	themedata_payload_v91j.elf
	$(OBJCOPY) -O binary $< $@

themedata_payload_v90.bin:	themedata_payload_v90.elf
	$(OBJCOPY) -O binary $< $@

themedata_payload_v94.elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=94 $< -o $@

themedata_payload_v93.elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=93 $< -o $@

themedata_payload_v92.elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=92 $< -o $@

themedata_payload_v91j.elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=91 $< -o $@

themedata_payload_v90.elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=90 $< -o $@

