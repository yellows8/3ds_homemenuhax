#pragma once

#define LOGTAR_CON (1<<0)
#define LOGTAR_LOG (1<<1)
#define LOGTAR_ALL (LOGTAR_CON | LOGTAR_LOG)

int log_init(const char *path);
void log_shutdown(void);
int log_printf(int target, const char *format, ...);

