Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Check Kernelfaults root datamodel:

  $ R "ba-cli KernelFaults.? | sed 's|[>,]||g'"
   KernelFaults.?
  KernelFaults.
  KernelFaults.KernelFaultNumberOfEntries=0
  KernelFaults.LastUpgradeCount=[0-9]* (re)
  KernelFaults.MaxKernelFaultEntries=[0-9]* (re)
  KernelFaults.MinFreeSpace=[0-9]* (re)
  KernelFaults.PreviousBootCount=[0-9]* (re)
  KernelFaults.StoragePath="/data/oops"
  
