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

Result sdiconhax_install(char *menuhax_basefn)
{
	return 0;
}

Result sdiconhax_delete()
{
	return 0;
}

