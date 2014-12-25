Currently this is just a tool for simulating the Home Menu code handling theme-data decompression.

When Home Menu is starting up, it can load theme-data from the home-menu theme SD extdata. The flaw can be triggered from here, it seems this can be triggered from extdata without having any theme DLC installed. Note that when triggered at startup, no networking system-modules are loaded yet(including dlp module).

Home Menu allocates a 0x2a0000-byte heap buffer using the ctrsdk heap code: offset 0x0 size 0x150000 is for the output decompressed data, offset 0x150000 size 0x150000 is for the input compressed data. Immediately after this buffer is a heap freemem memchunkhdr, successfully overwriting it results a crash(when the data written there is junk) in the heap memchunk handling code with the linked-lists.

The decompression code only has an input-size parameter, no output size parameter. Hence, the output size is not restricted/checked at all. Since the decompressed data is located before the compressed data, the buf overflow results in the input compressed data being overwritten first. Eventually this overflow will result in the input data actually being used by the decompression function being overwritten, which can later result in an error before the function ever writes to the memchunk-hdr(if the input compressed data doesn't workaround that).

# System Versions
This flaw was introduced with the Home Menu version which added support for themes: 9.0.0-X. In Japan according to Nintendo, theme support was added with 9.1.0-XJ.

This flaw still exists with system-version 9.4.0-X, the newest version this flaw was checked for at the time of writing.

# Installation
One of the ways to write to the theme extdata is with ctrclient-yls8(extdataID below is for USA, extdataID is different for other regions):
* Write to BodyCache: ctrclient-yls8 --serveradr={ipaddr} "--customcmd=directfilerw 0x6 0x2 0xc 0x4 0x1e 0x2 0x150000 01000000cd02000000000000 2f0042006f0064007900430061006300680065002e00620069006e000000 @BodyCache_mod.bin"
* Write to ThemeManage: ctrclient-yls8 --serveradr={ipaddr} "--customcmd=directfilerw 0x6 0x2 0xc 0x4 0x22 0x2 0x800 01000000cd02000000000000 2F005400680065006D0065004D0061006E006100670065002E00620069006E000000 @ThemeManage_mod.bin"

# payload.py
payload.py generates an lz11 compressed file which will first decompress a given file (first argument) and then overwrite the 0x10 bytes immediately after the buffer with the data specified in the script's "overwriteData" list.
This works correctly with the pc-side simulator. It also works fine on hardware: the memchunk-hdr after the buffer is overwritten with the intended data, resulting in a crash with the heap memory-free code.

Example use :
	python payload.py uncompressed_rop_data.bin payload.bin 0xDEADBABE 0xBADBEEF 0xDEADC0DE 0xCAFE
