# Unassociated STA Link Metrics Module

## Reads the injected radiotap information for all traffic on an interface in monitor or promiscuous mode. Meant to target Qualcomm radios.

## Building:

Ensure you have the kernel headers installed, and then --

`make clean && make`

## Running:

First, put your interface of choice into either monitor or promiscuous mode. Then,

`insmod uslm_mod nic_name=<your_nic_here>`

Link metrics data will be logged to dmesg.

## Coding guidelines:

Don't crash the kernel. Past that, please `./clang-format.sh` before submitting patches.

## Userspace Interface

Currently, station stats are exposed via a procfs entry, `/proc/uslm_proc`
