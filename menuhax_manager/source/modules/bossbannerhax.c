#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <3ds.h>

#include "archive.h"
#include "log.h"

#include "modules_common.h"

Result bossbannerhax_install(char *menuhax_basefn, s16 menuversion);
Result bossbannerhax_delete();

static u32 bossbannerhax_NsDataId = 0x58484e42;

void register_module_bossbannerhax()
{
	module_entry module = {
		.name = "bossbannerhax",
		.haxinstall = bossbannerhax_install,
		.haxdelete = bossbannerhax_delete,
		.themeflag = false
	};

	register_module(&module);
}

Result bossbannerhax_install(char *menuhax_basefn, s16 menuversion)
{
	Result ret=0;

	bossContext ctx;
	u8 status=0;
	u32 tmp=0;
	u8 tmpbuf[4] = {0};
	char *taskID = "tmptask";

	char payload_filepath[256];
	char tmpstr[256];

	memset(payload_filepath, 0, sizeof(payload_filepath));
	memset(tmpstr, 0, sizeof(tmpstr));

	snprintf(payload_filepath, sizeof(payload_filepath)-1, "romfs:/finaloutput/stage1_bossbannerhax.zip@%s.bin", menuhax_basefn);
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

	log_printf(LOGTAR_ALL, "Running BOSS setup...\n");

	ret = bossInit(0, true);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossInit() failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = bossSetStorageInfo(0x21d, 0x400000, MEDIATYPE_SD);//TODO: Load the actual extdataID for this region.
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossSetStorageInfo() failed: 0x%08x.\n", (unsigned int)ret);
		bossExit();
		return ret;
	}

	memset(tmpstr, 0, sizeof(tmpstr));
	snprintf(tmpstr, sizeof(tmpstr)-1, "http://192.168.254.11/menuhax/bossbannerhax/%s_bossbannerhax.bin" /*"http://yls8.mtheall.com/menuhax/bossbannerhax/%s_bossbannerhax.bin"*/, menuhax_basefn);
	//HTTP is used here since it's currently unknown how to setup a non-default rootCA cert for BOSS.

	bossSetupContextDefault(&ctx, 60, tmpstr);

	ret = bossSendContextConfig(&ctx);
	if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossSendContextConfig returned 0x%08x.\n", (unsigned int)ret);

	if(R_SUCCEEDED(ret))
	{
		ret = bossRegisterTask(taskID, 0, 0);
		if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossRegisterTask returned 0x%08x.\n", (unsigned int)ret);

		if(R_SUCCEEDED(ret))
		{
			ret = bossStartTaskImmediate(taskID);
			if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossStartTaskImmediate returned 0x%08x.\n", (unsigned int)ret);

			if(R_SUCCEEDED(ret))
			{
				log_printf(LOGTAR_ALL, "Waiting for the task to run...\n");

				while(1)
				{
					ret = bossGetTaskState(taskID, 0, &status, NULL ,NULL);
					if(R_FAILED(ret))
					{
						log_printf(LOGTAR_ALL, "bossGetTaskState returned 0x%08x.\n", (unsigned int)ret);
						break;
					}
					if(R_SUCCEEDED(ret))log_printf(LOGTAR_ALL, "...\n");//printf("bossGetTaskState: tmp0=0x%x, tmp2=0x%x, tmp1=0x%x.\n", (unsigned int)tmp0, (unsigned int)tmp2, (unsigned int)tmp1);

					if(status!=BOSSTASKSTATUS_STARTED)break;

					svcSleepThread(1000000000LL);//Delay 1s.
				}
			}

			if(R_SUCCEEDED(ret) && status==BOSSTASKSTATUS_ERROR)
			{
				log_printf(LOGTAR_ALL, "BOSS task failed.\n");
				ret = -9;
			}

			if(R_SUCCEEDED(ret))
			{
				log_printf(LOGTAR_ALL, "Reading BOSS content...\n");

				tmp = 0;
				ret = bossReadNsData(bossbannerhax_NsDataId, 0, tmpbuf, sizeof(tmpbuf), &tmp, NULL);
				if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossReadNsData returned 0x%08x, transfer_total=0x%x.\n", (unsigned int)ret, (unsigned int)tmp);

				if(R_SUCCEEDED(ret) && tmp!=sizeof(tmpbuf))ret = -10;

				if(R_SUCCEEDED(ret) && memcmp(tmpbuf, "CBMD", 4))ret = -11;

				if(R_FAILED(ret))log_printf(LOGTAR_ALL, "BOSS data reading failed: 0x%08x.\n", (unsigned int)ret);
			}

			bossDeleteTask(taskID, 0);
		}
	}

	bossExit();

	return ret;
}

Result bossbannerhax_delete()
{
	Result ret=0;

	ret = bossInit(0, true);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossInit() failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = bossDeleteNsData(bossbannerhax_NsDataId);
	if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossDeleteNsData() returned: 0x%08x.\n", (unsigned int)ret);

	bossExit();

	return 0;
}

