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

PARAMS	:=	
DEFINES	:=	

ifneq ($(strip $(ENABLE_RET2MENU)),)
	PARAMS	:=	$(PARAMS) ENABLE_RET2MENU=1
	DEFINES	:=	$(DEFINES) -DENABLE_RET2MENU
endif

ifneq ($(strip $(CODEBINPAYLOAD)),)
	PARAMS	:=	$(PARAMS) CODEBINPAYLOAD=$(CODEBINPAYLOAD) PAYLOADENABLED=1
	DEFINES	:=	$(DEFINES) -DCODEBINPAYLOAD=\"$(CODEBINPAYLOAD)\" -DPAYLOADENABLED
endif

ifneq ($(strip $(BOOTGAMECARD)),)
	PARAMS	:=	$(PARAMS) BOOTGAMECARD=1
	DEFINES	:=	$(DEFINES) -DBOOTGAMECARD
endif

ifneq ($(strip $(USE_PADCHECK)),)
	PARAMS	:=	$(PARAMS) USE_PADCHECK=$(USE_PADCHECK)
	DEFINES	:=	$(DEFINES) -DUSE_PADCHECK=$(USE_PADCHECK)
endif

ifneq ($(strip $(GAMECARD_PADCHECK)),)
	PARAMS	:=	$(PARAMS) GAMECARD_PADCHECK=$(GAMECARD_PADCHECK)
	DEFINES	:=	$(DEFINES) -DGAMECARD_PADCHECK=$(GAMECARD_PADCHECK)
endif

ifneq ($(strip $(EXITMENU)),)
	PARAMS	:=	$(PARAMS) EXITMENU=1
	DEFINES	:=	$(DEFINES) -DEXITMENU
endif

ifneq ($(strip $(LOADSDPAYLOAD)),)
	PARAMS	:=	$(PARAMS) LOADSDPAYLOAD=1 PAYLOADENABLED=1
	DEFINES	:=	$(DEFINES) -DLOADSDPAYLOAD -DPAYLOADENABLED
endif

all:	
	@make buildtheme --no-print-directory SYSVER=90
	@make buildtheme --no-print-directory SYSVER=91
	@make buildtheme --no-print-directory SYSVER=92
	@make buildtheme --no-print-directory SYSVER=93
	@make buildtheme --no-print-directory SYSVER=94
	@make buildtheme --no-print-directory SYSVER=95
	@make buildtheme --no-print-directory SYSVER=96
	@make buildtheme --no-print-directory SYSVER=97

clean:
	@make cleanbuild --no-print-directory SYSVER=90
	@make cleanbuild --no-print-directory SYSVER=91
	@make cleanbuild --no-print-directory SYSVER=92
	@make cleanbuild --no-print-directory SYSVER=93
	@make cleanbuild --no-print-directory SYSVER=94
	@make cleanbuild --no-print-directory SYSVER=95
	@make cleanbuild --no-print-directory SYSVER=96
	@make cleanbuild --no-print-directory SYSVER=97

buildtheme:
	@make $(THEMEPREFIX)$(SYSVER)_old3ds.lz --no-print-directory BUILDPREFIX=$(THEMEPREFIX)$(SYSVER)_old3ds SYSVER=$(SYSVER) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_OLD3DS) HEAPBUF=$(HEAPBUF_OLD3DS) NEW3DS=0 $(PARAMS)
	@make $(THEMEPREFIX)$(SYSVER)_new3ds.lz --no-print-directory BUILDPREFIX=$(THEMEPREFIX)$(SYSVER)_new3ds SYSVER=$(SYSVER) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_NEW3DS) HEAPBUF=$(HEAPBUF_NEW3DS) NEW3DS=1 $(PARAMS)

cleanbuild:
	rm -f $(THEMEPREFIX)$(SYSVER)_old3ds.elf $(THEMEPREFIX)$(SYSVER)_old3ds.bin $(THEMEPREFIX)$(SYSVER)_old3ds.lz
	rm -f $(THEMEPREFIX)$(SYSVER)_new3ds.elf $(THEMEPREFIX)$(SYSVER)_new3ds.bin $(THEMEPREFIX)$(SYSVER)_new3ds.lz

$(BUILDPREFIX).lz:	$(BUILDPREFIX).bin
	python3 payload.py $< $@ 0x4652 0x100000 $(TARGETOVERWRITE_MEMCHUNKADR) $(HEAPBUF_OBJADDR)

$(BUILDPREFIX).bin:	$(BUILDPREFIX).elf
	$(OBJCOPY) -O binary $< $@

$(BUILDPREFIX).elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DSYSVER=$(SYSVER) -DHEAPBUF=$(HEAPBUF) -DTARGETOVERWRITE_MEMCHUNKADR=$(TARGETOVERWRITE_MEMCHUNKADR) -DNEW3DS=$(NEW3DS) $(DEFINES) $< -o $@

