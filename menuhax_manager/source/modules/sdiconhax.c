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

Result sdiconhax_install(char *menuhax_basefn)
{
	Result ret=0;

	log_printf(LOGTAR_ALL, "Loading SaveData.dat...\n");
	ret = sdiconhax_load_savedatadat();
	if(ret!=0)return ret;

	return 0;
}

Result sdiconhax_delete()
{
	Result ret=0;

	log_printf(LOGTAR_ALL, "Loading SaveData.dat...\n");
	ret = sdiconhax_load_savedatadat();
	if(ret!=0)return ret;

	return 0;
}

