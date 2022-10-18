#ifndef __CL_STA_PROC_H
#define __CL_STA_PROC_H
#include "proc.h"

#ifdef HAVE_PROC_OPS
extern struct proc_ops station_stats_ops;
#else
extern struct file_operations station_stats_ops;
#endif // HAVE_PROC_OPS

extern const char *station_procfs_name;

#endif // __CL_STA_PROC_H