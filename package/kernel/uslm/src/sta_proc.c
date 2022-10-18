#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include "sta_proc.h"
#include "station.h"

const char *station_procfs_name = "uslm_proc";

static int uslm_proc_station_dump(struct seq_file *m, void *args)
{
	// TODO pass head of station lsit in via 'args'?
	int i;
	int sta_no = 0;
	struct station *sta = NULL;
	for (i = 0; i < station_get_station_table_size(); i++) {
		sta = station_get_at_idx(i);
		if (!sta)
			continue;
		spin_lock(&sta->lock);
		seq_printf(m, "--- ---\n");
		seq_printf(m, "Station_%d\n", sta_no++);
		seq_printf(m,
			   "MAC:             %02x:%02x:%02x:%02x:%02x:%02x\n",
			   sta->mac_addr[0], sta->mac_addr[1], sta->mac_addr[2],
			   sta->mac_addr[3], sta->mac_addr[4],
			   sta->mac_addr[5]);
		seq_printf(m, "ChannelNumber:   %d\n", sta->channel);
		seq_printf(m, "ChannelFreq:     %d\n", sta->freq);
		seq_printf(m, "AvgRssi:         %d\n", sta->avg_rssi);
		seq_printf(m, "NumSamples:      %d\n",
			   sta->n_rssi_measurements);
		seq_printf(m, "MaxMeasurements: %d\n",
			   sta->max_rssi_measurements);
		seq_printf(m, "--- ---\n");
		spin_unlock(&sta->lock);
	}
	if (!sta_no) {
		seq_printf(m, "No Stations!\n");
	}
	return 0;
}

static int uslm_proc_open(struct inode *inode, struct file *f)
{
	return single_open(f, uslm_proc_station_dump, NULL);
}

static int uslm_proc_close(struct inode *inode, struct file *f)
{
	return single_release(inode, f);
}

static ssize_t uslm_proc_read(struct file *f, char __user *buf, size_t cnt,
			      loff_t *off)
{
	return seq_read(f, buf, cnt, off);
}

static ssize_t uslm_proc_write(struct file *f, const char __user *buf,
			       size_t cnt, loff_t *off)
{
	return -ENOENT;
}

static loff_t uslm_proc_lseek(struct file *f, loff_t off, int cnt)
{
	return -ENOENT;
}

#ifdef HAVE_PROC_OPS
struct proc_ops station_stats_ops = { .proc_open = uslm_proc_open,
				      .proc_read = uslm_proc_read,
				      .proc_lseek = uslm_proc_lseek,
				      .proc_release = uslm_proc_close,
				      .proc_write = uslm_proc_write };
#else
struct file_operations station_stats_ops = { .owner = THIS_MODULE,
					     .open = uslm_proc_open,
					     .read = uslm_proc_read,
					     .llseek = uslm_proc_lseek,
					     .release = uslm_proc_close,
					     .write = uslm_proc_write };
#endif