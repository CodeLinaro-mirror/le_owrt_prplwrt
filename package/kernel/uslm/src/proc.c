#include <linux/proc_fs.h>
#include <linux/seq_file.h>

#include "proc.h"

int procfile_create(const char *fname,
#ifdef HAVE_PROC_OPS
		    const struct proc_ops *ops
#else
		    const struct file_operations *ops
#endif
)
{
	if (!fname || !ops)
		return 1;
	proc_create(fname, 0644, NULL, ops);
	return 0;
}

int procfile_destroy(const char *fname)
{
	if (!fname)
		return 1;
	remove_proc_entry(fname, NULL);
	return 0;
}
