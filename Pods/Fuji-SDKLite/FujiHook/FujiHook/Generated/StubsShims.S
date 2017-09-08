
/* WARNING: Auto-generated from FujiHook/Metadata/Stubs.xml */

/*
 * WARNING:
 * This implementation uses the "gHook" global array and it assumes
 * that its entries are of the structure type "HCHookContext" defined
 * in "HookCore.h", as follows:
 *    typedef struct {
 *       void *origAddress;
 *       void *registeredFunc;
 *       const void *hookAddress;
 *       const char *libName;
 *       const char *funcName;
 *    } HCHookContext;
 *
 * If the layout should ever change, then this implementation will need
 * to be updated.
 * It is assumed that no entry may ever have 'origAddress' uninitialized.
 */

#include "StubsConstants.h"

#ifdef __arm__

#define HCHookContextSize 20
#define HCHookContextRegisteredFuncOff 4

   .section __TEXT,__text,regular,pure_instructions
   .align 4

   .global _HCHook_syscall
_HCHook_syscall:
   mov r12, #HOOK_libsystem_kernel_syscall
   b 0f

0:
   push {r11}
   mov r11, #HCHookContextSize ;                 // r11 := <'registered' offset>
   mul r11, r11, r12
   add r11, r11, #HCHookContextRegisteredFuncOff

1:
   movw r12, :lower16:(hookTable-(LPC0+8))       // r12 := <table address>
   movt r12, :upper16:(hookTable-(LPC0+8))
LPC0:
   ldr r12, [pc, r12]
   ldr r12, [r12, r11]                           // r12 := <function address>
   cmp r12, #0
   bne 2f                                        // Found valid function.
   sub r11, r11, #HCHookContextRegisteredFuncOff // r11 := <'original' offset>
   b 1b                                          // 'registered' == NULL, retry.
2:
   pop {r11}
   bx r12                                        // Forward call.

   .section __DATA,__nl_symbol_ptr,non_lazy_symbol_pointers
   .align  2
hookTable:
   .indirect_symbol _gHook
   .long   0

.subsections_via_symbols

#endif // __arm__

