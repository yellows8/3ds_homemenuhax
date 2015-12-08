#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"

#include "modules_common.h"

Result themehax_install(char *menuhax_basefn);
Result themehax_delete();

void register_module_themehax()
{
	register_module(MODULE_MAKE_CVER(10, 2, 0), themehax_install, themehax_delete);
}

Result themehax_install(char *menuhax_basefn)
{
	Result ret=0;

	char body_filepath[256];

	memset(body_filepath, 0, sizeof(body_filepath));

	snprintf(body_filepath, sizeof(body_filepath)-1, "sdmc:/3ds/menuhax_manager/finaloutput/themepayload/%s.lz", menuhax_basefn);

	printf("Installing themehax...\n");

	printf("Enabling persistent themecache...\n");
	ret = menu_enablethemecache_persistent();
	if(ret!=0)return ret;

	printf("Installing to the SD theme-cache...\n");
	ret = sd2themecache(body_filepath, "sdmc:/3ds/menuhax_manager/bgm_bundledmenuhax.bcstm", 0);
	if(ret!=0)return ret;

	printf("Initializing the seperate menuhax theme-data files...\n");
	ret = sd2themecache("sdmc:/3ds/menuhax_manager/blanktheme.lz", NULL, 1);
	if(ret!=0)return ret;

	return 0;
}

Result themehax_delete()
{
	Result ret=0;

	printf("Deleting themehax...\n");

	printf("Disabling theme-usage via SaveData.dat...\n");
	ret = disablethemecache();
	if(ret!=0)return ret;

	memset(filebuffer, 0, filebuffer_maxsize);

	printf("Clearing the theme-cache extdata now...\n");

	printf("Clearing the ThemeManage...\n");
	ret = archive_writefile(Theme_Extdata, "/ThemeManage.bin", filebuffer, 0x800, 0x800);
	if(ret!=0)
	{
		printf("Failed to clear the ThemeManage: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Clearing the regular BodyCache...\n");
	ret = archive_writefile(Theme_Extdata, "/BodyCache.bin", filebuffer, 0x150000, 0x150000);
	if(ret!=0)
	{
		printf("Failed to clear the regular BodyCache: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	printf("Clearing the regular BgmCache...\n");
	ret = archive_writefile(Theme_Extdata, "/BgmCache.bin", filebuffer, 0x337000, 0x337000);
	if(ret!=0)
	{
		printf("Failed to clear the regular BgmCache: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	return 0;
}

