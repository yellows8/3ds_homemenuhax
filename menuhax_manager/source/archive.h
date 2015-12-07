typedef enum {
	HomeMenu_Extdata,
	Theme_Extdata,
	TotalExtdataArchives,
	SDArchive = TotalExtdataArchives
} Archive;

Result open_extdata();
void close_extdata();
Result archive_deletefile(Archive archive, char *path);
Result archive_getfilesize(Archive archive, char *path, u32 *outsize);
Result archive_readfile(Archive archive, char *path, u8 *buffer, u32 size);
Result archive_writefile(Archive archive, char *path, u8 *buffer, u32 size, u32 createsize);
Result archive_copyfile(Archive inarchive, Archive outarchive, char *inpath, char *outpath, u8* buffer, u32 size, u32 maxbufsize, u32 createsize, char *display_filepath);

