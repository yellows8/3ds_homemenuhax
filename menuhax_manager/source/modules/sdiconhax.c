#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"
#include "log.h"

#include "modules_common.h"

Result sdiconhax_install(char *menuhax_basefn);
Result sdiconhax_delete();

void register_module_sdiconhax()
{
	module_entry module = {
		.name = "sdiconhax",
		.haxinstall = sdiconhax_install,
		.haxdelete = sdiconhax_delete,
		.themeflag = true
	};

	register_module(&module);
}

Result sdiconhax_load_savedatadat(void)
{
	Result ret=0;
	u32 filesize=0;

	memset(filebuffer, 0, filebuffer_maxsize);

	ret = archive_getfilesize(HomeMenu_Extdata, "/SaveData.dat", &filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to get filesize for extdata SaveData.dat: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(filesize > filebuffer_maxsize)filesize = filebuffer_maxsize;

	if(filesize != 0x2da0)
	{
		log_printf(LOGTAR_ALL, "The SaveData.dat filesize is invalid. This may mean you're running menuhax_manager on an unsupported system-version.\n");
		log_printf(LOGTAR_LOG, "Filesize = 0x%x, expected 0x2da0.\n", (unsigned int)filesize);
		return -2;
	}

	ret = archive_readfile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to read SaveData.dat: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	if(filebuffer[0]<2 || filebuffer[0]>4)
	{
		log_printf(LOGTAR_ALL, "The SaveData.dat format is unsupported. This may mean you're running menuhax_manager on an unsupported system-version.\n");
		log_printf(LOGTAR_LOG, "Format = 0x%x, expected 2..4.\n", (unsigned int)filebuffer[0]);
		return -2;
	}

	return ret;
}

Result sdiconhax_locatelinearmem(u32 *outaddr)
{
	u32 *tmpbuf;
	u32 *linearaddr;
	u32 linearpos = osGetMemRegionSize(MEMREGION_APPLICATION);
	u32 chunksize=0x800000;
	u32 pos;

	tmpbuf = linearAlloc(chunksize);
	if(tmpbuf==NULL)
	{
		log_printf(LOGTAR_LOG, "Failed to allocate mem for tmpbuf.\n");
		return -1;
	}

	linearaddr = (u32*)(0x30000000+linearpos);

	memset(tmpbuf, 0, chunksize);
	GSPGPU_FlushDataCache(tmpbuf, chunksize);

	GX_TextureCopy(linearaddr, 0, tmpbuf, 0, chunksize, 0x8);
	gspWaitForPPF();

	for(pos=0; pos<(chunksize-8)>>2; pos++)//Locate the address of the SaveData.dat buffer in the linearmem heap, since it varies per system in some cases.
	{
		if(tmpbuf[pos]==0x5544 && tmpbuf[pos+1]==0x2da0)
		{
			break;
		}
	}

	linearFree(tmpbuf);

	if(pos==((chunksize-8)>>2))return -2;

	pos+= 4;

	*outaddr = (u32)&linearaddr[pos];

	return 0;
}

Result sdiconhax_install(char *menuhax_basefn)
{
	Result ret=0;
	u32 linearaddr=0;
	u32 *savedatadat = (u32*)filebuffer;
	u32 *tmpbuf = (u32*)&filebuffer[0x2da0];
	u32 pos;
	u64 *tidptr_in, *tidptr_out;
	s16 *ptr16_in, *ptr16_out;
	s8 *ptr8_in, *ptr8_out;

	char filepath[256];

	log_printf(LOGTAR_ALL, "Loading SaveData.dat...\n");
	ret = sdiconhax_load_savedatadat();
	if(ret!=0)return ret;

	log_printf(LOGTAR_ALL, "Locating linearmem addr...\n");
	ret = sdiconhax_locatelinearmem(&linearaddr);
	if(ret!=0)return ret;

	log_printf(LOGTAR_ALL, "Loading exploit file-data + writing into extdata...\n");

	memset(filepath, 0, sizeof(filepath));

	snprintf(filepath, sizeof(filepath)-1, "romfs:/finaloutput/sdiconhax.zip@%s_sdiconhax.bin", menuhax_basefn);

	ret = archive_readfile(SDArchive, filepath, (u8*)tmpbuf, 0x2da0);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to load data from romfs: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	tidptr_in = (u64*)&tmpbuf[0x8>>2];
	ptr16_in = (s16*)&tmpbuf[0xcb0>>2];
	ptr8_in = (s8*)&tmpbuf[0xf80>>2];

	tidptr_out = (u64*)&savedatadat[0x8>>2];
	ptr16_out = (s16*)&savedatadat[0xcb0>>2];
	ptr8_out = (s8*)&savedatadat[0xf80>>2];

	//Only copy data to SaveData.dat when the titleID is set.
	for(pos=0; pos<360; pos++)
	{
		if(tidptr_in[pos] != ~0)
		{
			tidptr_out[pos] = tidptr_in[pos];
			ptr16_out[pos] = ptr16_in[pos];
			ptr8_out[pos] = ptr8_in[pos];
		}
	}

	ret = archive_writefile(HomeMenu_Extdata, "/SaveData.dat", (u8*)savedatadat, 0x2da0, 0);

	return ret;
}

Result sdiconhax_delete()
{
	Result ret=0;
	s16 *ptr;
	u32 pos;
	u32 update = 0;

	log_printf(LOGTAR_ALL, "Loading SaveData.dat...\n");
	ret = sdiconhax_load_savedatadat();
	if(ret!=0)return ret;

	ptr = (s16*)&filebuffer[0xcb0];
	for(pos=0; pos<360; pos++)
	{
		if(ptr[pos] < -1)//The exploit implementation used here only uses negative values for this, so this code only checks for negative values.
		{
			ptr[pos] = -1;
			update = 1;
		}
	}

	if(update)
	{
		log_printf(LOGTAR_ALL, "Writing the updated SaveData.dat...\n");
		ret = archive_writefile(HomeMenu_Extdata, "/SaveData.dat", filebuffer, 0x2da0, 0);
	}
	else
	{
		log_printf(LOGTAR_ALL, "SaveData.dat wasn't updated since sdiconhax wasn't detected.\n");
	}

	return ret;
}

