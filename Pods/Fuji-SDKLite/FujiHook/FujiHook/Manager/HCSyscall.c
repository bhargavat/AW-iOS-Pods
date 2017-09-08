//
//  HCSyscall.c
//
//  Copyright (c) 2013 VMware. All rights reserved.
//

#include "HookManager.h"
#include "HCSyscall.h"

#define EXPORT __attribute__((visibility("default")))

HCSyscallTableEntry HCSyscallTable[SYS_MAXSYSCALL];


/**
 * Sets the syscall shim forwarding table by performing a copy and registers
 * the syscall shim with hookcore.
 * @param table syscall table to set.
 * @param tableEntryCount number of elements in the table.
 * @return 0 if successful. -1 if the tableEntryCount is too large or hook
 *           registration failed.
 */
EXPORT
int
HCSyscall_Register(const HCSyscallTableEntry table[],
                   unsigned int tableEntryCount)
{
#ifdef __arm__
   extern int HCSyscall_Shim(int, ...);

   if (tableEntryCount >= SYS_MAXSYSCALL) {
      return -1;
   }

   for (unsigned int i = 0; i < tableEntryCount; i++) {
      HCSyscallTable[i] = table[i];
   }

   return HookMgr_Register(HCSyscall_Shim, HOOK_libsystem_kernel_syscall);
#else // x86
   /* x86 support not implemented, yet; ignore, report success. */

   return 0;
#endif // __arm__
}
