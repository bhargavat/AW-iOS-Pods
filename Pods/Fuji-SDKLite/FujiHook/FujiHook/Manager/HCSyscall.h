//
//  HCSyscall.h
//
//  Copyright (c) 2013 VMware. All rights reserved.
//

#ifndef _HC_SYSCALL_H_
#define _HC_SYSCALL_H_

#include <sys/syscall.h>


typedef struct HCSyscallTableEntry {
   int syscall;
   void *function;
} HCSyscallTableEntry;


int
HCSyscall_Register(const HCSyscallTableEntry table[],
                   unsigned int tableEntryCount);

#endif // _HC_SYSCALL_H_

