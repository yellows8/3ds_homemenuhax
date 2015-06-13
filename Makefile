#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/base_rules

.PHONY: clean all cleanbuild buildtheme

THEMEPREFIX	:=	themedatahax_

# Heap start on Old3DS is 0x34352000.
# Heap start on New3DS is 0x37f52000.
# Relative offset for the heapbuf is 0xD00080.
TARGETOVERWRITE_MEMCHUNKADR	:=	0x0FFFFEA4
HEAPBUF_OBJADDR_OLD3DS	:=	0x35052144
HEAPBUF_OBJADDR_NEW3DS	:=	0x38c52144

HEAPBUF_ROPBIN_OLD3DS	:=	0x35040000
HEAPBUF_ROPBIN_NEW3DS	:=	0x38C40000

HEAPBUF_THEME_OLD3DS	:=	0x35052080
HEAPBUF_THEME_NEW3DS	:=	0x38c52080

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

ifneq ($(strip $(BUILDROPBIN)),)
	PARAMS	:=	$(PARAMS) BUILDROPBIN=1
	DEFINES	:=	$(DEFINES) -DBUILDROPBIN
endif

all:	
	@mkdir -p themepayload
	@mkdir -p binpayload
	@mkdir -p build
	@if [ ! -d "menurop/JPN" ]; then $$(error "The menurop/JPN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "menurop/USA" ]; then $$(error "The menurop/USA directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi

	@for path in menurop/JPN/*; do make -f Makefile buildtheme --no-print-directory REGION=JPN REGIONVAL=0 MENUVERSION=$$(basename "$$path"); done
	@for path in menurop/USA/*; do make -f Makefile buildtheme --no-print-directory REGION=USA REGIONVAL=1 MENUVERSION=$$(basename "$$path"); done

ropbins:	
	@mkdir -p binpayload
	@mkdir -p build
	@if [ ! -d "menurop/JPN" ]; then $$(error "The menurop/JPN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "menurop/USA" ]; then $$(error "The menurop/USA directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi

	@for path in menurop/JPN/*; do make -f Makefile buildropbin --no-print-directory REGION=JPN REGIONVAL=0 MENUVERSION=$$(basename "$$path"); done
	@for path in menurop/USA/*; do make -f Makefile buildropbin --no-print-directory REGION=USA REGIONVAL=1 MENUVERSION=$$(basename "$$path"); done

clean:
	@rm -R -f themepayload
	@rm -R -f binpayload
	@rm -R -f build

buildtheme:
	@make -f Makefile themepayload/$(THEMEPREFIX)$(REGION)$(MENUVERSION)_old3ds.lz --no-print-directory BUILDPREFIX=$(THEMEPREFIX)$(REGION)$(MENUVERSION)_old3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_OLD3DS) HEAPBUF=$(HEAPBUF_THEME_OLD3DS) NEW3DS=0 $(PARAMS)
	@make -f Makefile themepayload/$(THEMEPREFIX)$(REGION)$(MENUVERSION)_new3ds.lz --no-print-directory BUILDPREFIX=$(THEMEPREFIX)$(REGION)$(MENUVERSION)_new3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_NEW3DS) HEAPBUF=$(HEAPBUF_THEME_NEW3DS) NEW3DS=1 $(PARAMS)

buildropbin:
	@make -f Makefile binpayload/$(THEMEPREFIX)$(REGION)$(MENUVERSION)_old3ds.bin --no-print-directory BUILDPREFIX=$(THEMEPREFIX)$(REGION)$(MENUVERSION)_old3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_OLD3DS) HEAPBUF=$(HEAPBUF_ROPBIN_OLD3DS) NEW3DS=0 BUILDROPBIN=1 $(PARAMS)
	@make -f Makefile binpayload/$(THEMEPREFIX)$(REGION)$(MENUVERSION)_new3ds.bin --no-print-directory BUILDPREFIX=$(THEMEPREFIX)$(REGION)$(MENUVERSION)_new3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_NEW3DS) HEAPBUF=$(HEAPBUF_ROPBIN_NEW3DS) NEW3DS=1 BUILDROPBIN=1 $(PARAMS)

cleanbuild:
	@rm -f build/$(THEMEPREFIX)$(REGION)$(MENUVERSION)_old3ds.elf payload/$(THEMEPREFIX)$(MENUVERSION)_old3ds.bin themepayload/$(THEMEPREFIX)$(MENUVERSION)_old3ds.lz
	@rm -f build/$(THEMEPREFIX)$(REGION)$(MENUVERSION)_new3ds.elf payload/$(THEMEPREFIX)$(MENUVERSION)_new3ds.bin themepayload/$(THEMEPREFIX)$(MENUVERSION)_new3ds.lz

themepayload/$(BUILDPREFIX).lz:	binpayload/$(BUILDPREFIX).bin
	python3 payload.py $< $@ 0x4652 0x100000 $(TARGETOVERWRITE_MEMCHUNKADR) $(HEAPBUF_OBJADDR)

binpayload/$(BUILDPREFIX).bin:	build/$(BUILDPREFIX).elf
	$(OBJCOPY) -O binary $< $@

build/$(BUILDPREFIX).elf:	themedata_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DREGION=$(REGION) -DREGIONVAL=$(REGIONVAL) -DMENUVERSION=$(MENUVERSION) -DHEAPBUF=$(HEAPBUF) -DTARGETOVERWRITE_MEMCHUNKADR=$(TARGETOVERWRITE_MEMCHUNKADR) -DNEW3DS=$(NEW3DS) $(DEFINES) -include menurop/$(REGION)/$(MENUVERSION) $< -o $@

