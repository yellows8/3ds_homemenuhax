#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/base_rules

.PHONY: clean all cleanbuild buildtheme

THEMEPREFIX	:=	themedatahax_v

# Heap start on Old3DS is 0x34352000.
# Heap start on New3DS is 0x37f52000.
# Relative offset for the heapbuf is 0xD00080.
TARGETOVERWRITE_MEMCHUNKADR	:=	0x0FFFFEA4
HEAPBUF_OBJADDR_OLD3DS	:=	0x35052144
HEAPBUF_OLD3DS	:=	0x35052080
HEAPBUF_OBJADDR_NEW3DS	:=	0x38c52144
HEAPBUF_NEW3DS	:=	0x38c52080

all:	
	@make buildtheme --no-print-directory SYSVER=94
	@make buildtheme --no-print-directory SYSVER=93
	@make buildtheme --no-print-directory SYSVER=92
	@make buildtheme --no-print-directory SYSVER=91
	@make buildtheme --no-print-directory SYSVER=90

clean:
	@make cleanbuild --no-print-directory SYSVER=94
	@make cleanbuild --no-print-directory SYSVER=93
	@make cleanbuild --no-print-directory SYSVER=92
	@make cleanbuild --no-print-directory SYSVER=91
	@make cleanbuild --no-print-directory SYSVER=90

buildtheme:
	@make $(THEMEPREFIX)$(SYSVER)_old3ds.lz --no-print-directory -f Makefile_new BUILDPREFIX=$(THEMEPREFIX)$(SYSVER)_old3ds SYSVER=$(SYSVER) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_OLD3DS) HEAPBUF=$(HEAPBUF_OLD3DS)
	@make $(THEMEPREFIX)$(SYSVER)_new3ds.lz --no-print-directory -f Makefile_new BUILDPREFIX=$(THEMEPREFIX)$(SYSVER)_new3ds SYSVER=$(SYSVER) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_NEW3DS) HEAPBUF=$(HEAPBUF_NEW3DS)

cleanbuild:
	rm -f $(THEMEPREFIX)$(SYSVER)_old3ds.elf $(THEMEPREFIX)$(SYSVER)_old3ds.bin $(THEMEPREFIX)$(SYSVER)_old3ds.lz
	rm -f $(THEMEPREFIX)$(SYSVER)_new3ds.elf $(THEMEPREFIX)$(SYSVER)_new3ds.bin $(THEMEPREFIX)$(SYSVER)_new3ds.lz

$(BUILDPREFIX).lz:	$(BUILDPREFIX).bin
	python3 payload.py $< $@ 0x4652 0x100000 $(TARGETOVERWRITE_MEMCHUNKADR) $(HEAPBUF_OBJADDR)

$(BUILDPREFIX).bin:	$(BUILDPREFIX).elf
	$(OBJCOPY) -O binary $< $@

$(BUILDPREFIX).elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=$(SYSVER) -DHEAPBUF=$(HEAPBUF) $< -o $@

