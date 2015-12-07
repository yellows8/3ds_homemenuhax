#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/base_rules

.PHONY: clean all defaultbuild ropbins bins buildtheme buildropbin buildbin

BUILDPREFIX	:=	menuhax_

# Heap start on Old3DS is 0x34352000.
# Heap start on New3DS is 0x37f52000.
# Relative offset for the heapbuf is 0xD00080.
TARGETOVERWRITE_MEMCHUNKADR	:=	0x0FFFFEA4

ifeq ($(strip $(THEMEDATA_PATH)),)
	HEAPBUF_OBJADDR_OLD3DS	:=	0x35052144
	HEAPBUF_OBJADDR_NEW3DS	:=	0x38c52144
else
	THEMEDATA_FILESIZE	:=	$$(stat -L -c %s $(THEMEDATA_PATH))
	HEAPBUF_OBJADDR_OLD3DS	:=	$$(( $(THEMEDATA_FILESIZE) + 889528448 ))
	HEAPBUF_OBJADDR_NEW3DS	:=	$$(( $(THEMEDATA_FILESIZE) + 952443008 ))
endif

HEAPBUF_ROPBIN_OLD3DS	:=	0x35040000
HEAPBUF_ROPBIN_NEW3DS	:=	0x38C40000

ifeq ($(strip $(HEAPBUF_HAX_OLD3DS)),)
	HEAPBUF_HAX_OLD3DS	:=	0x35052080
endif

ifeq ($(strip $(HEAPBUF_HAX_NEW3DS)),)
	HEAPBUF_HAX_NEW3DS	:=	0x38c52080
endif

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

ifneq ($(strip $(LOADSDCFG_PADCHECK)),)
	PARAMS	:=	$(PARAMS) LOADSDCFG_PADCHECK=$(LOADSDCFG_PADCHECK)
	DEFINES	:=	$(DEFINES) -DLOADSDCFG_PADCHECK=$(LOADSDCFG_PADCHECK)
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

ifneq ($(strip $(ENABLE_LOADROPBIN)),)
	PARAMS	:=	$(PARAMS) ENABLE_LOADROPBIN=1
	DEFINES	:=	$(DEFINES) -DENABLE_LOADROPBIN
endif

ifneq ($(strip $(ENABLE_HBLAUNCHER)),)
	PARAMS	:=	$(PARAMS) ENABLE_HBLAUNCHER=1
	DEFINES	:=	$(DEFINES) -DENABLE_HBLAUNCHER
endif

ifeq ($(strip $(MENUROP_PATH)),)
	MENUROP_PATH	:=	menurop
endif

ifneq ($(strip $(THEMEDATA_PATH)),)
	PARAMS	:=	$(PARAMS) THEMEDATA_PATH=$(THEMEDATA_PATH)
	DEFINES	:=	$(DEFINES) -DTHEMEDATA_PATH=\"$(THEMEDATA_PATH)\"
endif

ifneq ($(strip $(LOADOTHER_THEMEDATA)),)
	PARAMS	:=	$(PARAMS) LOADOTHER_THEMEDATA=1
	DEFINES	:=	$(DEFINES) -DLOADOTHER_THEMEDATA
endif

ifneq ($(strip $(ENABLE_IMAGEDISPLAY)),)
	PARAMS	:=	$(PARAMS) ENABLE_IMAGEDISPLAY=1
	DEFINES	:=	$(DEFINES) -DENABLE_IMAGEDISPLAY
endif

ifneq ($(strip $(ENABLE_IMAGEDISPLAY_SD)),)
	PARAMS	:=	$(PARAMS) ENABLE_IMAGEDISPLAY_SD=1
	DEFINES	:=	$(DEFINES) -DENABLE_IMAGEDISPLAY_SD
endif

# The input options starting from here can be used internally for hax building, hence why they aren't listed in the README.

ifneq ($(strip $(PAYLOAD_PADFILESIZE)),)
	PARAMS	:=	$(PARAMS) PAYLOAD_PADFILESIZE=$(PAYLOAD_PADFILESIZE)
	DEFINES	:=	$(DEFINES) -DPAYLOAD_PADFILESIZE=$(PAYLOAD_PADFILESIZE)
endif

ifneq ($(strip $(PAYLOAD_HEADERFILE)),)
	PARAMS	:=	$(PARAMS) PAYLOAD_HEADERFILE=$(PAYLOAD_HEADERFILE)
	DEFINES	:=	$(DEFINES) -DPAYLOAD_HEADERFILE=\"$(PAYLOAD_HEADERFILE)\"
endif

ifneq ($(strip $(PAYLOAD_FOOTER_WORDS)),)
	PARAMS	:=	$(PARAMS) PAYLOAD_FOOTER_WORDS=1 PAYLOAD_FOOTER_WORD0=$(PAYLOAD_FOOTER_WORD0) PAYLOAD_FOOTER_WORD1=$(PAYLOAD_FOOTER_WORD1) PAYLOAD_FOOTER_WORD2=$(PAYLOAD_FOOTER_WORD2) PAYLOAD_FOOTER_WORD3=$(PAYLOAD_FOOTER_WORD3)
	DEFINES	:=	$(DEFINES) -DPAYLOAD_FOOTER_WORDS -DPAYLOAD_FOOTER_WORD0=$(PAYLOAD_FOOTER_WORD0) -DPAYLOAD_FOOTER_WORD1=$(PAYLOAD_FOOTER_WORD1) -DPAYLOAD_FOOTER_WORD2=$(PAYLOAD_FOOTER_WORD2) -DPAYLOAD_FOOTER_WORD3=$(PAYLOAD_FOOTER_WORD3)
endif

DEFINES	:=	$(DEFINES) -DROPBINPAYLOAD_PATH=\"sd:/ropbinpayload_$(BUILDPREFIX).bin\"

BUILDMODULES_COMMAND	:=	

include Makefile_modules_include

defaultbuild:
	make -f Makefile all --no-print-directory LOADSDPAYLOAD=1 USE_PADCHECK=0x200 ENABLE_LOADROPBIN=1 ENABLE_HBLAUNCHER=1 LOADSDCFG_PADCHECK=1 LOADOTHER_THEMEDATA=1 ENABLE_IMAGEDISPLAY=1 ENABLE_IMAGEDISPLAY_SD=1 MENUROP_PATH=menurop_prebuilt

all:	
	@mkdir -p finaloutput
	@mkdir -p binpayload
	@mkdir -p build
	@if [ ! -d "$(MENUROP_PATH)/JPN" ]; then $$(error "The $(MENUROP_PATH)/JPN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/USA" ]; then $$(error "The $(MENUROP_PATH)/USA directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/EUR" ]; then $$(error "The $(MENUROP_PATH)/EUR directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	#@if [ ! -d "$(MENUROP_PATH)/CHN" ]; then $$(error "The $(MENUROP_PATH)/CHN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/KOR" ]; then $$(error "The $(MENUROP_PATH)/KOR directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	#@if [ ! -d "$(MENUROP_PATH)/TWN" ]; then $$(error "The $(MENUROP_PATH)/TWN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	
	$(BUILDMODULES_COMMAND)

ropbins:	
	@mkdir -p binpayload
	@mkdir -p build
	@if [ ! -d "$(MENUROP_PATH)/JPN" ]; then $$(error "The $(MENUROP_PATH)/JPN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/USA" ]; then $$(error "The $(MENUROP_PATH)/USA directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/EUR" ]; then $$(error "The $(MENUROP_PATH)/EUR directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	#@if [ ! -d "$(MENUROP_PATH)/CHN" ]; then $$(error "The $(MENUROP_PATH)/CHN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/KOR" ]; then $$(error "The $(MENUROP_PATH)/KOR directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	#@if [ ! -d "$(MENUROP_PATH)/TWN" ]; then $$(error "The $(MENUROP_PATH)/TWN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi

	@for path in $(MENUROP_PATH)/JPN/*; do make -f Makefile buildropbin --no-print-directory REGION=JPN REGIONVAL=0 MENUVERSION=$$(basename "$$path"); done
	@for path in $(MENUROP_PATH)/USA/*; do make -f Makefile buildropbin --no-print-directory REGION=USA REGIONVAL=1 MENUVERSION=$$(basename "$$path"); done
	@for path in $(MENUROP_PATH)/EUR/*; do make -f Makefile buildropbin --no-print-directory REGION=EUR REGIONVAL=2 MENUVERSION=$$(basename "$$path"); done
	#@for path in $(MENUROP_PATH)/CHN/*; do make -f Makefile buildropbin --no-print-directory REGION=CHN REGIONVAL=3 MENUVERSION=$$(basename "$$path"); done
	@for path in $(MENUROP_PATH)/KOR/*; do make -f Makefile buildropbin --no-print-directory REGION=KOR REGIONVAL=4 MENUVERSION=$$(basename "$$path"); done
	#@for path in $(MENUROP_PATH)/TWN/*; do make -f Makefile buildropbin --no-print-directory REGION=TWN REGIONVAL=5 MENUVERSION=$$(basename "$$path"); done

bins:	
	@mkdir -p binpayload
	@mkdir -p build
	@if [ ! -d "$(MENUROP_PATH)/JPN" ]; then $$(error "The $(MENUROP_PATH)/JPN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/USA" ]; then $$(error "The $(MENUROP_PATH)/USA directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/EUR" ]; then $$(error "The $(MENUROP_PATH)/EUR directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	#@if [ ! -d "$(MENUROP_PATH)/CHN" ]; then $$(error "The $(MENUROP_PATH)/CHN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	@if [ ! -d "$(MENUROP_PATH)/KOR" ]; then $$(error "The $(MENUROP_PATH)/KOR directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi
	#@if [ ! -d "$(MENUROP_PATH)/TWN" ]; then $$(error "The $(MENUROP_PATH)/TWN directory doesn't exist, please run the generate_menurop_addrs.sh script."); fi

	@for path in $(MENUROP_PATH)/JPN/*; do make -f Makefile buildbin --no-print-directory REGION=JPN REGIONVAL=0 MENUVERSION=$$(basename "$$path"); done
	@for path in $(MENUROP_PATH)/USA/*; do make -f Makefile buildbin --no-print-directory REGION=USA REGIONVAL=1 MENUVERSION=$$(basename "$$path"); done
	@for path in $(MENUROP_PATH)/EUR/*; do make -f Makefile buildbin --no-print-directory REGION=EUR REGIONVAL=2 MENUVERSION=$$(basename "$$path"); done
	#@for path in $(MENUROP_PATH)/CHN/*; do make -f Makefile buildbin --no-print-directory REGION=CHN REGIONVAL=3 MENUVERSION=$$(basename "$$path"); done
	@for path in $(MENUROP_PATH)/KOR/*; do make -f Makefile buildbin --no-print-directory REGION=KOR REGIONVAL=4 MENUVERSION=$$(basename "$$path"); done
	#@for path in $(MENUROP_PATH)/TWN/*; do make -f Makefile buildbin --no-print-directory REGION=TWN REGIONVAL=5 MENUVERSION=$$(basename "$$path"); done

clean:
	@rm -R -f finaloutput
	@rm -R -f binpayload
	@rm -R -f build

buildropbin:
	@make -f Makefile binpayload/$(BUILDPREFIX)$(REGION)$(MENUVERSION)_old3ds.bin --no-print-directory BUILDPREFIX=$(BUILDPREFIX)$(REGION)$(MENUVERSION)_old3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_OLD3DS) HEAPBUF=$(HEAPBUF_HAX_OLD3DS) ROPBIN_BUFADR=$(HEAPBUF_ROPBIN_OLD3DS) NEW3DS=0 BUILDROPBIN=1 $(PARAMS)
	@make -f Makefile binpayload/$(BUILDPREFIX)$(REGION)$(MENUVERSION)_new3ds.bin --no-print-directory BUILDPREFIX=$(BUILDPREFIX)$(REGION)$(MENUVERSION)_new3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_NEW3DS) HEAPBUF=$(HEAPBUF_HAX_NEW3DS) ROPBIN_BUFADR=$(HEAPBUF_ROPBIN_NEW3DS) NEW3DS=1 BUILDROPBIN=1 $(PARAMS)

buildbin:
	@make -f Makefile binpayload/$(BUILDPREFIX)$(REGION)$(MENUVERSION)_old3ds.bin --no-print-directory BUILDPREFIX=$(BUILDPREFIX)$(REGION)$(MENUVERSION)_old3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_OLD3DS) HEAPBUF=$(HEAPBUF_HAX_OLD3DS) FIXHEAPBUF=$(FIXHEAPBUF_HAX_OLD3DS) ROPBIN_BUFADR=$(HEAPBUF_ROPBIN_OLD3DS) NEW3DS=0 $(PARAMS)
	@make -f Makefile binpayload/$(BUILDPREFIX)$(REGION)$(MENUVERSION)_new3ds.bin --no-print-directory BUILDPREFIX=$(BUILDPREFIX)$(REGION)$(MENUVERSION)_new3ds MENUVERSION=$(MENUVERSION) HEAPBUF_OBJADDR=$(HEAPBUF_OBJADDR_NEW3DS) HEAPBUF=$(HEAPBUF_HAX_NEW3DS) FIXHEAPBUF=$(FIXHEAPBUF_HAX_NEW3DS) ROPBIN_BUFADR=$(HEAPBUF_ROPBIN_NEW3DS) NEW3DS=1 $(PARAMS)

binpayload/$(BUILDPREFIX).bin:	build/$(BUILDPREFIX).elf
	$(OBJCOPY) -O binary $< $@

build/$(BUILDPREFIX).elf:	menuhax_payload.s
	$(CC) -x assembler-with-cpp -nostartfiles -nostdlib -DREGION=$(REGION) -DREGIONVAL=$(REGIONVAL) -DMENUVERSION=$(MENUVERSION) -DHEAPBUF=$(HEAPBUF) -DFIXHEAPBUF=$(FIXHEAPBUF) -DROPBIN_BUFADR=$(ROPBIN_BUFADR) -DTARGETOVERWRITE_MEMCHUNKADR=$(TARGETOVERWRITE_MEMCHUNKADR) -DNEW3DS=$(NEW3DS) $(DEFINES) -include $(MENUROP_PATH)/$(REGION)/$(MENUVERSION) $< -o $@

