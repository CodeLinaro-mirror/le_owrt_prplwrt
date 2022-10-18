#ifndef __CL_PROC_H
#define __CL_PROC_H
#include <linux/version.h>

#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 6, 0)
#define HAVE_PROC_OPS
#endif

struct file_operations;
struct proc_ops;

#ifdef HAVE_PROC_OPS
int procfile_create(const char *fname, const struct proc_ops *props);
#else
int procfile_create(const char *fname, const struct file_operations *fops);
#endif

int procfile_destroy(const char *fname);

#endif // __CL_PROC_H