//
//  HCSyscall.S
//
//  Copyright (c) 2013 VMware. All rights reserved.
//

#ifdef __arm__

#define HCSyscallEntrySize 8
#define HCSyscallEntryFunctionOffset 4

.text
.p2align 4

/*
 * Shim function installed as the Fuji hook for the syscall() API.
 * It searches through the syscall table listing the syscall numbers
 * to intercept. The search stops when the syscall number matches, or
 * the table entry is zero. The call is forwarded to the corresponding
 * function address.
 *
 * The syscall table must be an array of HCSyscallTableEntry elements
 * (see HCSyscallShim.h).
 */

.global _HCSyscall_Shim
_HCSyscall_Shim:
   push {r11}

   movw r12, :lower16:(syscallTable-(LPC0+8))
   movt r12, :upper16:(syscallTable-(LPC0+8))
LPC0:
   ldr r12, [pc, r12]                         // r12 := <table address>

1:
   ldr r11, [r12]
   cmp r11, #0
   beq 2f
   cmp r11, r0                                // r0 := <syscall number>
   beq 2f
   add r12, r12, #HCSyscallEntrySize
   b 1b

2:
   ldr r12, [r12, #HCSyscallEntryFunctionOffset]
   pop {r11}
   bx r12

   .section __DATA,__nl_symbol_ptr,non_lazy_symbol_pointers
   .align  2

syscallTable:
   .indirect_symbol _HCSyscallTable
   .long   0

.subsections_via_symbols

#endif

