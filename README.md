# Summary
When Home Menu is starting up, it can load theme-data from the home-menu theme SD extdata. The flaw can be triggered from here. Although this triggers during Home Menu boot, this can't cause any true bricks: just remove the *SD card if any booting issues ever occur(or delete/rename the theme-cache extdata directory).

Since this is a theme exploit, no actual gfx/audio theme can be used with this hax installed to the *SD card. Gfx/audio theme-data can't be included with the themehax builds either currently, due to HEAPBUF_OBJADDR_*3DS being hard-coded in the Makefile(that value would vary for every gfx theme).

# Vuln
This was discovered on December 22, 2014.

Home Menu allocates a 0x2a0000-byte heap buffer using the ctrsdk heap code: offset 0x0 size 0x150000 is for the output decompressed data, offset 0x150000 size 0x150000 is for the input compressed data. Immediately after this buffer is a heap freemem memchunkhdr, successfully overwriting it results a crash(when the data written there is junk) in the heap memchunk handling code with the linked-lists.

The decompression code only has an input-size parameter, no output size parameter. Hence, the output size is not restricted/checked at all. Since the decompressed data is located before the compressed data, the buf overflow results in the input compressed data being overwritten first. Eventually this overflow will result in the input data actually being used by the decompression function being overwritten, which can later result in an error before the function ever writes to the memchunk-hdr(if the input compressed data doesn't workaround that).

# Supported System Versions
* v9.0 non-JPN (not tested, unknown if the heap/stack addrs are correct)
* v9.1j (not tested, unknown if the heap/stack addrs are correct)
* v9.2
* v9.3 (not tested, unknown if the heap/stack addrs are correct)
* v9.4
* v9.5
* v9.6
* v9.7
* All homemenu versions with this vuln where the ropgadget-finder successfully finds the required addresses, unless structs involved with the initial ROP-chain change etc.

This flaw was introduced with the Home Menu version which added support for themes: 9.0.0-X on Old3DS, v8.1 on New3DS. Old3DS JPN theme support was "added" 9.1.0-XJ. The lowest system-version supported by this is v9.0(non-JPN), and JPN v9.1.

This flaw still exists with system-version 9.9.0-X, the newest version this flaw was checked for at the time of writing. Last system-version this haxx was successfully tested with: 9.9.0-X.

# Building
Just run "make", or even "make clean && make". For building ROP binaries which can be used for general homemenu ROP, this can be used: "{make clean &&} make ropbins". "make bins" is the same as "make", except building the .lz is skipped.

Before building, the menurop directories+files must be generated. "./generate_menurop_addrs.sh {path}". See the source of that script for details. Note that the USA/EUR/JPN homemenu exefs:/.code binaries starting with system-version v9.2 are all identical, while USA/EUR binaries for v9.0 differs from the JPN versions.

Build options:
* "ENABLE_RET2MENU=1" Just return from the haxx to the Home Menu code after writing to the framebufs.
* "CODEBINPAYLOAD=path" Code binary payload to load into the launched process(default is the system web-browser). This will be included in the theme-data itself.
* "LOADSDPAYLOAD=1" Enable loading a code binary from SD for loading into the launched process("/menuhax_payload.bin"). The total size of the code(including additional code prior to the binary from SD) loaded into the process is 0x4000-bytes. Therefore, the max size of the code binary from SD is a bit less than 0x3000-bytes.
* "BOOTGAMECARD=1" Reboot the system via NSS:RebootSystem to launch the gamecard(region-free). This is handled right after the ROP for LOADROPBIN, if that's even enabled. If GAMECARD_PADCHECK isn't used, the ROP will always execute this without executing the title-launch + takeover ROP.
* "USE_PADCHECK=val" When set, at the very start of the menu ROP it will check if the current HID PAD state is set to the specified value. When they match, it continues the ROP, otherwise it returns to the homemenu code. This is done before writing to the framebuffers.
* "GAMECARD_PADCHECK=val" Similar to USE_PADCHECK except for BOOTGAMECARD: the BOOTGAMECARD ROP only gets executed when the specified HID PAD state matches the current one. After writing to framebufs the ROP will delay 3 seconds, then run this PADCHECK ROP.
* "EXITMENU=1" Terminate homemenu X seconds(see source) after getting code exec under the launched process.
* "ENABLE_LOADROPBIN=1" Load a homemenu ropbin then stack-pivot to it, see the Makefile HEAPBUF_ROPBIN_* values for the load-address. When LOADSDPAYLOAD isn't used, the binary is the one specified by CODEBINPAYLOAD, otherwise it's loaded from "sd:/menuhax_ropbinpayload.bin". The binary size should be <=0x10000-bytes.

# Usage
Just boot the system, the haxx will automatically trigger when Home Menu loads the theme-data from the cache in SD extdata. The ROP right after the ROP for USE_PADCHECK, if that's even enabled, will overwrite the main-screen framebuffers with data from elsewhere, resulting in junk being displayed.

When the ROP returns from the haxx to running the actual Home Menu code, such as when USE_PADCHECK is used where the current PAD state doesn't match the specified state, Home Menu will use the "theme" data from this hax: the end result is that it appears to use the same theme as the default one.

When built with ENABLE_LOADROPBIN=1, this can boot into the homebrew-launcher if the ropbin listed above is one for the homebrew-launcher.

# Installation
The files for BodyCache.bin/Body_LZ.bin is located under "themepayload/". The built "USA" theme .lz files can be used with both USA and EUR(in the context of this hax, for v9.9 only USA needs the v9.9 build, the rest use v9.8). The built filenames include the Home Menu title-version, see here: http://3dbrew.org/wiki/Title_list#00040030_-_Applets

Theme-data cache from this extdata is only loaded at startup when certain fields in the home-menu SD extdata Savedata.dat are set to certain values, see here(this is handled by the below tool): http://3dbrew.org/wiki/Home_Menu

The following tool can be used for installing the hax: https://github.com/yellows8/3ds_homemenu_extdatatool

The hax can be installed with the following:
* 1) Setup 3ds_homemenu_extdatatool on your SD card, for use via the homebrew-launcher from another exploit.
* 2) Copy the .lz from themepayload/ above for your system, to "/3ds/3ds_homemenu_extdatatool/Body_LZ.bin".
* 3) Boot the tool via homebrew-launcher, then use the following menu options in the tool: "Enable persistent theme-cache"(if it wasn't setup that way already) and "Copy theme-data from sd to extdata".
* 4) The hax is now setup. You can now exit the tool+hbmenu to reboot for trying the hax.

# Credits
* smea for payload.py. This is where the actual generation for the compressed data which triggers the buf-overflow is done.

