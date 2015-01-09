# Summary
When Home Menu is starting up, it can load theme-data from the home-menu theme SD extdata. The flaw can be triggered from here.

# Vuln
Home Menu allocates a 0x2a0000-byte heap buffer using the ctrsdk heap code: offset 0x0 size 0x150000 is for the output decompressed data, offset 0x150000 size 0x150000 is for the input compressed data. Immediately after this buffer is a heap freemem memchunkhdr, successfully overwriting it results a crash(when the data written there is junk) in the heap memchunk handling code with the linked-lists.

The decompression code only has an input-size parameter, no output size parameter. Hence, the output size is not restricted/checked at all. Since the decompressed data is located before the compressed data, the buf overflow results in the input compressed data being overwritten first. Eventually this overflow will result in the input data actually being used by the decompression function being overwritten, which can later result in an error before the function ever writes to the memchunk-hdr(if the input compressed data doesn't workaround that).

# Supported System Versions
* v9.0 non-JPN (not tested, unknown if the heap/stack addrs are correct)
* v9.1j (not tested, unknown if the heap/stack addrs are correct)
* v9.2
* v9.3 (not tested, unknown if the heap/stack addrs are correct)
* v9.4

This flaw was introduced with the Home Menu version which added support for themes: 9.0.0-X. In Japan according to Nintendo, theme support was "added" with 9.1.0-XJ(but the code binary for v9.0j appears to have theme support too). Therefore, the lowest system-version supported by this is v9.0(non-JPN), and JPN v9.1.

This flaw still exists with system-version 9.4.0-X, the newest version this flaw was checked for at the time of writing.

# Building
Just run "make", or even "make clean && make".

# Usage
Just boot the system, the haxx will automatically trigger when Home Menu loads the theme-data from the cache in SD extdata. See themedata_payload.s for what the ROP currently does.

# Installation
One of the ways to write to the theme extdata is with ctrclient-yls8(extdataIDs below is for USA, extdataID is different for other regions). The built filename for ThemeManage is this: themedatahax_v{systemversion}.lz

Theme-data cache from this extdata is only loaded at startup when cetain fields in the home-menu SD extdata Savedata.dat are set to certain values, see here: http://3dbrew.org/wiki/Home_Menu

* Write to BodyCache: ctrclient-yls8 --serveradr={ipaddr} "--customcmd=directfilerw 0x6 0x2 0xc 0x4 0x1e 0x2 0x150000 01000000cd02000000000000 2f0042006f0064007900430061006300680065002e00620069006e000000 @BodyCache_mod.bin"
* Write to ThemeManage: ctrclient-yls8 --serveradr={ipaddr} "--customcmd=directfilerw 0x6 0x2 0xc 0x4 0x22 0x2 0x800 01000000cd02000000000000 2F005400680065006D0065004D0061006E006100670065002E00620069006E000000 @ThemeManage_mod.bin"
* Read homemenu SaveData.dat: ctrclient-yls8 --serveradr={ipaddr} "--customcmd=directfilerw 0x6 0x2 0xc 0x4 0x1c 0x1 010000008f00000000000000 2F00530061007600650044006100740061002E006400610074000000 @out.bin"
* Write homemenu SaveData.dat: ctrclient-yls8 --serveradr={ipaddr} "--customcmd=directfilerw 0x6 0x2 0xc 0x4 0x1c 0x2 0x2da0 010000008f00000000000000  2F00530061007600650044006100740061002E006400610074000000 @in.bin"

# payload.py
payload.py generates an lz11 compressed file which will first decompress a given file (first argument) and then overwrite the 0x10 bytes immediately after the buffer with the data specified in the script's "overwriteData" list.
This works correctly with the pc-side simulator. It also works fine on hardware: the memchunk-hdr after the buffer is overwritten with the intended data, resulting in a crash with the heap memory-free code.

Example use :
	python3 payload.py uncompressed_rop_data.bin payload.bin 0xDEADBABE 0xBADBEEF 0xDEADC0DE 0xCAFE

