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

Result bossbannerhax_getprograminfo(u64 *programID, u32 *extdataID)
{
	Result ret=0;
	bool new3dsflag=false;

	ret = APT_GetProgramID(programID);
	if(R_FAILED(ret))return ret;

	APT_CheckNew3DS(&new3dsflag);

	if(new3dsflag)*programID |= 0x20000000;//Various get-programID cmds won't return the programID /w this bitmask set on new3ds, so set it manually. Needed since Home Menu uses the titleID raw from AM(?) with BOSS exbanner-loading, while normally the new3ds programID bitmask is cleared with BOSS.
	if(extdataID)*extdataID = (((u32)*programID) & 0x0fffff00) >> 8;

	return 0;
}

Result bossbannerhax_install(char *menuhax_basefn, s16 menuversion)
{
	Result ret=0;

	bossContext ctx;
	u8 status=0;
	u32 tmp=0;
	u8 tmpbuf[4] = {0};
	char *taskID = "tmptask";

	Handle fshandle=0;
	FS_Path archpath;
	FS_ExtSaveDataInfo extdatainfo;
	u32 extdataID = 0;
	u32 extdata_exists = 0;
	u64 cur_programid = 0;

	u32 numdirs = 0, numfiles = 0;
	u8 *smdh = NULL;
	u32 smdh_size = 0x36c0;

	struct romfs_mount *mount = NULL;
	Handle filehandle = 0;
	char iconpath[256];

	u32 file_lowpath_data[0xc>>2];

	FS_Path archpath_romfs = { PATH_EMPTY, 1, (u8*)"" };
	FS_Path fileLowPath;

	char payload_filepath[256];
	char tmpstr[256];

	memset(payload_filepath, 0, sizeof(payload_filepath));
	memset(tmpstr, 0, sizeof(tmpstr));
	memset(iconpath, 0, sizeof(iconpath));

	memset(file_lowpath_data, 0, sizeof(file_lowpath_data));

	fileLowPath.type = PATH_BINARY;
	fileLowPath.size = 0xc;
	fileLowPath.data = (u8*)file_lowpath_data;

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

	ret = bossbannerhax_getprograminfo(&cur_programid, &extdataID);

	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossbannerhax_getprograminfo() failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	log_printf(LOGTAR_LOG, "cur_programid=0x%016llx, extdataID=0x%08x.\n", (unsigned long long)cur_programid, (unsigned int)extdataID);

	log_printf(LOGTAR_ALL, "Running extdata deletion+creation if required, for the currently running title...\n");

	archpath.type = PATH_BINARY;
	archpath.data = &extdatainfo;
	archpath.size = 0xc;

	memset(&extdatainfo, 0, sizeof(extdatainfo));
	extdatainfo.mediaType = MEDIATYPE_SD;
	extdatainfo.saveId = extdataID;

	//For whatever reason deleting/creating this extdata with the default *hax fsuser session(from Home Menu) fails.
	if (R_FAILED(ret = srvGetServiceHandleDirect(&fshandle, "fs:USER"))) return ret;//This code is based on the code from sploit_installer for this.
        if (R_FAILED(ret = FSUSER_Initialize(fshandle))) return ret;
	fsUseSession(fshandle);

	ret = FSUSER_GetFormatInfo(NULL, &numdirs, &numfiles, NULL, ARCHIVE_EXTDATA, archpath);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "FSUSER_GetFormatInfo() failed: 0x%08x.\n", (unsigned int)ret);//TODO: Switch this to LOGTAR_LOG / etc.
		//return ret;
	}
	else
	{
		log_printf(LOGTAR_LOG, "FSUSER_GetFormatInfo: numdirs = 0x%08x, numfiles = 0x%08x.\n", (unsigned int)numdirs, (unsigned int)numfiles);
		extdata_exists = 1;
	}
	

	if(numdirs!=10 || numfiles!=10)
	{
		smdh = malloc(smdh_size);
		if(smdh==NULL)
		{
			log_printf(LOGTAR_ALL, "Failed to allocate memory for the SMDH.\n");
			ret = -12;
			fsEndUseSession();
			return ret;
		}
		memset(smdh, 0, smdh_size);

		//TODO: Load "extdata:/ExBanner/COMMON.bin", then write it after creating the extdata.

		if(extdata_exists)
		{
			ret = FSUSER_ReadExtSaveDataIcon(&tmp, extdatainfo, smdh_size, smdh);
			if(R_SUCCEEDED(ret) && tmp!=smdh_size)ret = -13;
			if(R_FAILED(ret))
			{
				log_printf(LOGTAR_ALL, "Extdata icon reading failed: 0x%08x.\n", (unsigned int)ret);
				free(smdh);
				fsEndUseSession();
				return ret;
			}

			ret = FSUSER_DeleteExtSaveData(extdatainfo);
			if(R_FAILED(ret))
			{
				log_printf(LOGTAR_ALL, "Extdata deletion failed: 0x%08x.\n", (unsigned int)ret);
				free(smdh);
				fsEndUseSession();
				return ret;
			}
		}
		else
		{
			//Load the extdata-icon from the current-title RomFS. While there's a common "banner.icn" file in all regions of this title, it isn't used for non-JPN. This is intended for face-raiders.

			memset(tmpstr, 0, sizeof(tmpstr));

			switch(extdataID)//This is actually for checking the region from the programID but extdataID is calculated the same way here anyway.
			{
				case 0x20d://Filepath doesn't include region for JPN.
				break;

				case 0x21d://USA
					strncpy(tmpstr, "US", sizeof(tmpstr)-1);
				break;

				case 0x22d://EUR
					strncpy(tmpstr, "EU", sizeof(tmpstr)-1);
				break;

				case 0x26d://CHN
					strncpy(tmpstr, "CN", sizeof(tmpstr)-1);
				break;

				case 0x27d://KOR
					strncpy(tmpstr, "KR", sizeof(tmpstr)-1);
				break;

				case 0x28d://TWN
					strncpy(tmpstr, "TW", sizeof(tmpstr)-1);
				break;

				default:
					log_printf(LOGTAR_ALL, "The title currently being run under isn't supported for loading the extdata icon.\n");
				return -15;
			}

			snprintf(iconpath, sizeof(iconpath)-1, "romfs:/hal/banner/banner%s.icn", tmpstr);

			ret = FSUSER_OpenFileDirectly(&filehandle, ARCHIVE_ROMFS, archpath_romfs, fileLowPath, FS_OPEN_READ, 0x0);
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to open the RomFS image for the current process: 0x%08x.\n", (unsigned int)ret);
				free(smdh);
				fsEndUseSession();
				return ret;
			}

			ret = romfsMountFromFile(filehandle, 0x0, &mount);
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to mount the RomFS image for the current process: 0x%08x.\n", (unsigned int)ret);
				free(smdh);
				fsEndUseSession();
				return ret;
			}

			ret = archive_readfile(SDArchive, iconpath, smdh, smdh_size);
			if(ret!=0)
			{
				log_printf(LOGTAR_ALL, "Failed to load the extdata icon from RomFS: 0x%08x.\n", (unsigned int)ret);
				free(smdh);
				fsEndUseSession();
				return ret;
			}

			romfsUnmount(mount);
		}

		ret = FSUSER_CreateExtSaveData(extdatainfo, 10, 10, ~0, smdh_size, smdh);
		free(smdh);
		if(R_FAILED(ret))
		{
			log_printf(LOGTAR_ALL, "Extdata creation failed: 0x%08x.\n", (unsigned int)ret);
			fsEndUseSession();
			return ret;
		}
	}

	fsEndUseSession();

	log_printf(LOGTAR_ALL, "Running BOSS setup...\n");

	ret = bossInit(0, false);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossInit() failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = bossReinit(cur_programid);
	//TODO: Run this again except with the proper Home Menu programID once BOSS usage is finished.
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossReinit() failed: 0x%08x.\n", (unsigned int)ret);
		bossExit();
		return ret;
	}

	ret = bossSetStorageInfo(extdataID, 0x400000, MEDIATYPE_SD);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossSetStorageInfo() failed: 0x%08x.\n", (unsigned int)ret);
		bossExit();
		return ret;
	}

	memset(tmpstr, 0, sizeof(tmpstr));
	snprintf(tmpstr, sizeof(tmpstr)-1, "http://10.0.0.23/menuhax/bossbannerhax/%s_bossbannerhax.bin" /*"http://yls8.mtheall.com/menuhax/bossbannerhax/%s_bossbannerhax.bin"*/, menuhax_basefn);
	//HTTP is used here since it's currently unknown how to setup a non-default rootCA cert for BOSS.

	bossSetupContextDefault(&ctx, 60, tmpstr);

	ret = bossSendContextConfig(&ctx);
	if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossSendContextConfig returned 0x%08x.\n", (unsigned int)ret);

	if(R_SUCCEEDED(ret))
	{
		ret = bossDeleteTask(taskID, 0);
		ret = bossDeleteNsData(bossbannerhax_NsDataId);

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
					if(R_SUCCEEDED(ret))
					{
						log_printf(LOGTAR_ALL, "...\n");
						log_printf(LOGTAR_LOG, "bossGetTaskState: status=0x%x.\n", (unsigned int)status);
					}

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
	u64 cur_programid=0;

	ret = bossbannerhax_getprograminfo(&cur_programid, NULL);

	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossbannerhax_getprograminfo() failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	log_printf(LOGTAR_LOG, "cur_programid=0x%016llx.\n", (unsigned long long)cur_programid);

	ret = bossInit(0, false);
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossInit() failed: 0x%08x.\n", (unsigned int)ret);
		return ret;
	}

	ret = bossReinit(cur_programid);
	//TODO: Run this again except with the proper Home Menu programID once BOSS usage is finished.
	if(R_FAILED(ret))
	{
		log_printf(LOGTAR_ALL, "bossReinit() failed: 0x%08x.\n", (unsigned int)ret);
		bossExit();
		return ret;
	}

	ret = bossDeleteNsData(bossbannerhax_NsDataId);
	if(R_FAILED(ret))log_printf(LOGTAR_ALL, "bossDeleteNsData() returned: 0x%08x.\n", (unsigned int)ret);

	bossUnregisterStorage();

	bossExit();

	return 0;
}

