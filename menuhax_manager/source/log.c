#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdarg.h>
#include <errno.h>

#include "log.h"

static FILE *flog;

int log_init(const char *path)
{
	if(flog)return 0;

	unlink(path);

	flog = fopen(path, "w");
	if(flog==NULL)return errno;

	return 0;
}

void log_shutdown(void)
{
	if(flog==NULL)return;

	fclose(flog);
	flog = NULL;
}

int log_printf(int target, const char *format, ...)
{
	int ret=0;
	va_list args;

	va_start(args, format);

	if(target & LOGTAR_CON)ret = vprintf(format, args);
	if((target & LOGTAR_LOG) && flog!=NULL)ret = vfprintf(flog, format, args);

	va_end(args);

	return ret;
}

