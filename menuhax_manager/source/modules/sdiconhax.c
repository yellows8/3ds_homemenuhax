#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"
#include "log.h"

#include "modules_common.h"

#define LINEARMEMSYS_BASE_RELOFFSET_OLD3DS(addr) (addr-0x34000000)
#define LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(addr) (addr-0x37c00000)

Result sdiconhax_install(char *menuhax_basefn);
Result sdiconhax_delete();

typedef struct {
	u8 region;
	u8 language;

	u32 linearaddr_savedatadat;
	u32 linearaddr_target_objectslist_buffer;
	s16 icon_16val;
	u32 original_objptrs[2];
} sdiconhax_addrset;

//These are for the v10.6..v11.0 Home Menu.
sdiconhax_addrset sdiconhax_addrset_builtinlist[] = {
	{
		.region = CFG_REGION_JPN,
		.language = CFG_LANGUAGE_JP,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c0fe0),
		//.linearaddr_target_objectslist_buffer = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382bdd40),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382b85fc), LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x38f7cb94)}
	},

	{
		.region = CFG_REGION_USA,
		.language = CFG_LANGUAGE_EN,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_OLD3DS(0x346c8260),
		//.linearaddr_target_objectslist_buffer = LINEARMEMSYS_BASE_RELOFFSET_OLD3DS(0x346c4fc0),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_OLD3DS(0x346bf8fc), LINEARMEMSYS_BASE_RELOFFSET_OLD3DS(0x346c3138)}
	},
	{
		.region = CFG_REGION_USA,
		.language = CFG_LANGUAGE_FR,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382ca3e0),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c19fc), LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c52b8)}
	},
	{
		.region = CFG_REGION_USA,
		.language = CFG_LANGUAGE_ES,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382ca460),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c1a7c), LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c5338)}
	},
	{
		.region = CFG_REGION_USA,
		.language = CFG_LANGUAGE_PT,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c8b60),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c017c), LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c3a38)}
	},

	{
		.region = CFG_REGION_EUR,
		.language = CFG_LANGUAGE_EN,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c8ce0),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c037c), LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c3bb8)}
	},
	{
		.region = CFG_REGION_EUR,
		.language = CFG_LANGUAGE_DE,

		.linearaddr_savedatadat = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382cbb60),
		//.linearaddr_target_objectslist_buffer = LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c88c0),
		.original_objptrs = {LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c317c), LINEARMEMSYS_BASE_RELOFFSET_NEW3DS(0x382c6a38)}
	}
};

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

Result sdiconhax_locatelinearmem(u32 *outaddr0, u32 *outaddr1, s16 *icon_16val, u32 *original_objptrs)
{
	u32 *tmpbuf;
	u32 *linearaddr;
	u32 linearpos = osGetMemRegionSize(MEMREGION_APPLICATION);
	u32 chunksize=0x800000;
	u32 pos;
	u32 tmpval;
	u32 iconbuffer_pos;

	//Copy the first 8MB of the SYSTEM memregion into tmpbuf.

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

	#ifndef RELEASE
	archive_writefile(SDArchive, "sdmc:/3ds/menuhax_manager/sdiconhax_locatelinearmem_x400000.bin", (u8*)&tmpbuf[0x400000>>2], 0x400000, 0);
	#endif

	for(pos=0; pos<(chunksize-8)>>2; pos++)//Locate the address of the SaveData.dat buffer in the linearmem heap, since it varies per system in some cases.
	{
		if(tmpbuf[pos]==0x5544 && tmpbuf[pos+1]==0x2da0)//Check the CTRSDK heap memchunkhdr.
		{
			break;
		}
	}

	if(pos==((chunksize-8)>>2))
	{
		linearFree(tmpbuf);
		log_printf(LOGTAR_LOG, "Failed to find the target CTRSDK heap memchunkhdr.\n");
		return -2;
	}

	pos+= 4;

	*outaddr0 = (u32)&linearaddr[pos];//Actual address of the SaveData.dat buffer.

	iconbuffer_pos = pos + (0x2da0>>2);

	if(!(tmpbuf[iconbuffer_pos]==0x5544 && tmpbuf[iconbuffer_pos+1]==0x7bc0))//Check the CTRSDK heap memchunkhdr.
	{
		log_printf(LOGTAR_LOG, "The icon buffer was not found at the expected address.\n");
		return -3;
	}

	iconbuffer_pos+= 4;

	pos-= 8;

	//Locate the buffer containing the target objects-list.

	pos = iconbuffer_pos - (0x6050/4)-4;//This is done because the below code fails to find the right buffer otherwise, with certain EUR systems at least.

	/*while(pos>0)
	{
		if((tmpbuf[pos] & 0xffff) == 0x5544 && tmpbuf[pos+1]==0x10)break;

		pos--;
	}*/

	if(!((tmpbuf[pos] & 0xffff) == 0x5544 && tmpbuf[pos+1]==0x10))pos = 0;

	if(pos==0)
	{
		linearFree(tmpbuf);
		log_printf(LOGTAR_LOG, "Failed to find the buffer for the target objects-list.\n");
		return -4;
	}

	pos+= 4;

	tmpval = iconbuffer_pos - pos;

	if(tmpval & 1)
	{
		pos++;
		tmpval = iconbuffer_pos - pos;
		log_printf(LOGTAR_LOG, "The relative offset for iconbuffer_pos->target_objectslist_buffer is 4-byte aligned, increasing it for 8-byte alignment.\n");
	}

	*outaddr1 = (u32)&linearaddr[pos];//Actual address of the target objects-list buffer.

	original_objptrs[0] = tmpbuf[pos];//Original objptrs before they get overwritten.
	original_objptrs[1] = tmpbuf[pos+1];

	linearFree(tmpbuf);

	tmpval*= 4;
	*icon_16val = -(tmpval/8);

	log_printf(LOGTAR_LOG, "linearaddr_savedatadat=0x%08x, linearaddr_target_objectslist_buffer=0x%08x, original_objptrs[0]=0x%x, original_objptrs[1]=0x%x, iconbuffer_pos=0x%x, pos=0x%x, tmpval=0x%x, icon_16val=0x%x\n", *outaddr0, *outaddr1, original_objptrs[0], original_objptrs[1], iconbuffer_pos, pos, tmpval, *icon_16val);

	return 0;
}

Result sdiconhax_getaddrs_builtin(u32 *outaddr0, u32 *outaddr1, s16 *icon_16val, u32 *original_objptrs)
{
	Result ret=0;
	u8 region=0, language=0;
	sdiconhax_addrset *curset;
	u32 pos, len;

	u32 sysbase = osGetMemRegionSize(MEMREGION_APPLICATION) + 0x30000000;

	ret = cfguInit();
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "Failed to init cfg: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}
	ret = CFGU_SecureInfoGetRegion(&region);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "Failed to get region from cfg: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}
	if(region>=7)
	{
		log_printf(LOGTAR_ALL, "Region value from cfg is invalid: 0x%02x.\n", (unsigned int)region);
		ret = -9;
		return ret;
	}

	ret = CFGU_GetSystemLanguage(&language);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "Failed to get language from cfg: 0x%08x.\n", (unsigned int)ret);
	}

	cfguExit();

	len = sizeof(sdiconhax_addrset_builtinlist) / sizeof(sdiconhax_addrset);

	for(pos=0; pos<len; pos++)
	{
		curset = &sdiconhax_addrset_builtinlist[pos];

		if(curset->region == region && curset->language == language)break;
	}

	if(pos==len)return -1;

	*outaddr0 = curset->linearaddr_savedatadat + sysbase;
	*outaddr1 = curset->linearaddr_target_objectslist_buffer + sysbase;
	*icon_16val = curset->icon_16val;
	original_objptrs[0] = curset->original_objptrs[0] + sysbase;
	original_objptrs[1] = curset->original_objptrs[1] + sysbase;

	if(curset->linearaddr_target_objectslist_buffer==0)*outaddr1 = (curset->linearaddr_savedatadat + sysbase + 0x2db0) - 0x6050;
	if(*icon_16val == 0)*icon_16val = 0xf3f6;

	return 0;
}

Result sdiconhax_setupstage1(char *menuhax_basefn, u32 *original_objptrs)
{
	Result ret=0;
	u32 filesize=0;
	u32 pos;
	u32 *filebuf;

	char tmpstr[256];
	char tmpstr2[256];

	memset(tmpstr, 0, sizeof(tmpstr));
	memset(tmpstr2, 0, sizeof(tmpstr2));

	snprintf(tmpstr, sizeof(tmpstr)-1, "romfs:/finaloutput/stage1_sdiconhax.zip@%s.bin", menuhax_basefn);
	snprintf(tmpstr2, sizeof(tmpstr2)-1, "sdmc:/menuhax/stage1/%s.bin", menuhax_basefn);

	filebuf = malloc(0x1000);
	if(filebuf==NULL)
	{
		log_printf(LOGTAR_LOG, "Failed to allocate filebuf.\n");
		return -1;
	}
	memset(filebuf, 0, 0x1000);

	ret = archive_getfilesize(SDArchive, tmpstr, &filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to get filesize for stage1: 0x%08x\n", (unsigned int)ret);
		free(filebuf);
		return ret;
	}

	if(filesize > 0x1000)
	{
		log_printf(LOGTAR_LOG, "Stage1 filesize is too large. Filesize = 0x%x, expected <=0x1000.\n", (unsigned int)filesize);
		free(filebuf);
		return -2;
	}

	ret = archive_readfile(SDArchive, tmpstr, (u8*)filebuf, filesize);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to read stage1: 0x%08x\n", (unsigned int)ret);
		free(filebuf);
		return ret;
	}

	//Patch stage1 as needed.
	for(pos=0; pos<(filesize>>2); pos++)
	{
		if((filebuf[pos] & 0xffffff00) == 0x58414800)
		{
			if(filebuf[pos] <= 0x58414801)filebuf[pos] = original_objptrs[filebuf[pos] & 0xff];
		}
	}

	ret = archive_writefile(SDArchive, tmpstr2, (u8*)filebuf, 0x1000, 0);
	free(filebuf);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Failed to write stage1: 0x%08x\n", (unsigned int)ret);
		return ret;
	}

	return 0;
}

Result sdiconhax_install(char *menuhax_basefn)
{
	Result ret=0;

	u32 linearaddr_savedatadat=0;
	u32 linearaddr_target_objectslist_buffer=0;
	s16 icon_16val=0;
	u32 original_objptrs[2] = {0};

	u32 *savedatadat = (u32*)filebuffer;
	u32 *tmpbuf = (u32*)&filebuffer[0x2da0];
	u32 pos, pos2;
	u64 *tidptr_in, *tidptr_out;
	s16 *ptr16_in, *ptr16_out;
	s8 *ptr8_in, *ptr8_out;
	u32 *ptr32;

	char filepath[256];

	log_printf(LOGTAR_ALL, "Loading SaveData.dat...\n");
	ret = sdiconhax_load_savedatadat();
	if(ret!=0)return ret;

	log_printf(LOGTAR_ALL, "Locating data in Home Menu linearmem heap...\n");
	ret = sdiconhax_locatelinearmem(&linearaddr_savedatadat, &linearaddr_target_objectslist_buffer, &icon_16val, original_objptrs);
	if(ret!=0)
	{
		log_printf(LOGTAR_LOG, "Error from sdiconhax_locatelinearmem(): 0x%08x\n", (unsigned int)ret);
		log_printf(LOGTAR_ALL, "Trying to load addrs from the built-in list since auto-locate failed...\n");

		ret = sdiconhax_getaddrs_builtin(&linearaddr_savedatadat, &linearaddr_target_objectslist_buffer, &icon_16val, original_objptrs);

		if(ret!=0)
		{
			log_printf(LOGTAR_LOG, "Error from sdiconhax_getaddrs_builtin(): 0x%08x\n", (unsigned int)ret);
			log_printf(LOGTAR_ALL, "Failed to load from the built-in list.\n\n");
			return ret;
		}
	}

	log_printf(LOGTAR_ALL, "Running SD setup for stage1...\n");
	ret = sdiconhax_setupstage1(menuhax_basefn, original_objptrs);
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

			ptr32 = (u32*)&tidptr_out[pos];//Replace the words used as the heap-buffer base addr.
			for(pos2=0; pos2<2; pos2++)
			{
				if((ptr32[pos2] & 0xffff0000) == 0x58480000)
				{
					ptr32[pos2]&= ~0xffff0000;
					ptr32[pos2]+= linearaddr_savedatadat;
				}
			}

			if(ptr16_in[pos]!=0x5848)
			{
				ptr16_out[pos] = ptr16_in[pos];
			}
			else
			{
				ptr16_out[pos] = icon_16val;
			}
			ptr8_out[pos] = ptr8_in[pos];
		}
	}

	ret = archive_writefile(HomeMenu_Extdata, "/SaveData.dat", (u8*)savedatadat, 0x2da0, 0);

	return ret;
}

Result sdiconhax_delete()
{
	Result ret=0;
	u64 *tidarray;
	s16 *ptr;
	s8 *array8;
	u32 pos;
	u32 update = 0;

	log_printf(LOGTAR_ALL, "Loading SaveData.dat...\n");
	ret = sdiconhax_load_savedatadat();
	if(ret!=0)return ret;

	tidarray = (u64*)&filebuffer[0x8];
	ptr = (s16*)&filebuffer[0xcb0];
	array8 = (s8*)&filebuffer[0xf80];

	for(pos=0; pos<360; pos++)
	{
		if(ptr[pos] < -2)//The exploit implementation used here only uses negative values for this, so this code only checks for negative values.
		{
			ptr[pos] = -1;//-1 is the default, while -2 is a special value.
			update = 1;
		}
	}

	//If sdiconhax was detected, reset the TID-data for the last 60 icons to the default value if the s8/s16 values match what sdiconhax uses.
	if(update)
	{
		for(pos=300; pos<360; pos++)
		{
			if(ptr[pos] == -1 && array8[pos] == -1)//These are the default values for these two arrays.
			{
				tidarray[pos] = ~0;
			}
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

