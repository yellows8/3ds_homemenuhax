#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"
#include "log.h"

#include "modules_common.h"

Result themehax_install(char *menuhax_basefn);
Result themehax_delete();

void register_module_themehax()
{
	module_entry module = {
		.name = "themehax",
		.haxinstall = themehax_install,
		.haxdelete = themehax_delete,
		.themeflag = false
	};

	register_module(&module);
}

Result themehax_install(char *menuhax_basefn)
{
	Result ret=0;

	char payload_filepath[256];
	char tmpstr[256];

	memset(payload_filepath, 0, sizeof(payload_filepath));
	memset(tmpstr, 0, sizeof(tmpstr));

	snprintf(payload_filepath, sizeof(payload_filepath)-1, "romfs:/finaloutput/stage1_themedata.zip@%s.bin", menuhax_basefn);
	snprintf(tmpstr, sizeof(tmpstr)-1, "sdmc:/menuhax/stage1/%s.bin", menuhax_basefn);

	log_printf(LOGTAR_ALL, "Copying stage1 to SD...\n");
	log_printf(LOGTAR_LOG, "Src path = '%s', dst = '%s'.\n", payload_filepath, tmpstr);

	unlink(tmpstr);
	ret = archive_copyfile(SDArchive, SDArchive, payload_filepath, tmpstr, filebuffer, 0, 0x1000, 0, "stage1");
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to copy stage1 to SD: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	memset(payload_filepath, 0, sizeof(payload_filepath));
	snprintf(payload_filepath, sizeof(payload_filepath)-1, "romfs:/finaloutput/themepayload.zip@%s.lz", menuhax_basefn);

	log_printf(LOGTAR_ALL, "Enabling persistent themecache...\n");
	ret = menu_enablethemecache_persistent();
	if(ret!=0)return ret;

	log_printf(LOGTAR_ALL, "Installing to the SD theme-cache...\n");
	ret = sd2themecache(payload_filepath, "sdmc:/3ds/menuhax_manager/bgm_bundledmenuhax.bcstm", 0);
	if(ret!=0)return ret;

	log_printf(LOGTAR_ALL, "Initializing the seperate menuhax theme-data files...\n");
	ret = sd2themecache("romfs:/blanktheme.lz", NULL, 1);
	if(ret!=0)return ret;

	return 0;
}

Result themehax_delete()
{
	Result ret=0;

	log_printf(LOGTAR_ALL, "Disabling theme-usage via SaveData.dat...\n");
	ret = disablethemecache();
	if(ret!=0)return ret;

	memset(filebuffer, 0, filebuffer_maxsize);

	log_printf(LOGTAR_ALL, "Clearing the theme-cache extdata now...\n");

	log_printf(LOGTAR_ALL, "Clearing the ThemeManage...\n");
	ret = archive_writefile(Theme_Extdata, "/ThemeManage.bin", filebuffer, 0x800, 0x800);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to clear the ThemeManage: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	log_printf(LOGTAR_ALL, "Clearing the regular BodyCache...\n");
	ret = archive_writefile(Theme_Extdata, "/BodyCache.bin", filebuffer, 0x150000, 0x150000);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to clear the regular BodyCache: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	log_printf(LOGTAR_ALL, "Clearing the regular BgmCache...\n");
	ret = archive_writefile(Theme_Extdata, "/BgmCache.bin", filebuffer, 0x337000, 0x337000);
	if(ret!=0)
	{
		log_printf(LOGTAR_ALL, "Failed to clear the regular BgmCache: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	return 0;
}

