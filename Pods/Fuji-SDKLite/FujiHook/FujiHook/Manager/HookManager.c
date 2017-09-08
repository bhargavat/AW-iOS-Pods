//
//  HookManager.c
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//
#include <stdio.h>

//#include "HookCore/HookCore.h"
#include "HookManager.h"
#include "Stubs.h"
#include "HookCore.h"


#define EXPORT __attribute__((visibility("default")))

// tests for var being in [low,high), limits are evaluted exactly once
// should be in some top level file, don't know where
// Fuji.h seems not to be a right place
//
// \param var variable to check
// \param low low limit, inclusive
// \param high high limit, exclusive
// \return true if variabe is in the range, false otherwise
#define RANGE(var, low, high) \
({                                     \
   typeof (low) _low = (low);          \
   typeof (high) _high = (high);       \
   ((_low <= (var)) && ((var) < _high)); \
})

// check if hook index is a vaild one
#define HOOK_IDX_VALID(hookIdx) RANGE(hookIndex, 0, HOOK_MAX)

/**
 * Registers a second-level hook in global hook-context table.
 *
 * \param hookAddress Address of hook function.
 * \param hook enum value encoding library and name of function to be hooked.
 * \return 0 if success or < 0 for errors
 */
EXPORT
int
HookMgr_Register(void *hookAddress, HookStub hookIndex)
{
   // check arguments
   if (hookAddress == NULL || !HOOK_IDX_VALID(hookIndex)) {
      return ERROR_INVALID_ARG;
   }
   if (gHook[hookIndex].registeredFunc != NULL) {
      return ERROR_HOOK_ALREADY_REGISTERED;
   }

   // register function
   gHook[hookIndex].registeredFunc = hookAddress;
   return 0;
}

/**
 * UnRegisters a second-level hook in global hook-context table.
 *
 * \param hook enum value encoding library and name of function to be unhooked.
 * \return hooked function address if there was one, NULL otherwise
 */
EXPORT
void *
HookMgr_UnRegister(HookStub hookIndex)
{
   void *res = NULL;
   if (HOOK_IDX_VALID(hookIndex)) {
      res = gHook[hookIndex].registeredFunc;
      gHook[hookIndex].registeredFunc = NULL;
   }
   return res;
}

/**
 * Retrives the original address of a hooked function..
 *
 * \param hook enum value encoding library and name of the hooked function.
 * \return Original address of function if found else null.
 */
EXPORT
void *
HookMgr_GetOrigFunction(HookStub hookIndex)
{
   void *res = NULL;
   if (HOOK_IDX_VALID(hookIndex)) {
      res = gHook[hookIndex].origAddress;
   }
   return res;
}

/**
 * Retrieves hooked function
 * \param hook hook enumertion to work on
 * \return hooked address if there was one, NULL otherwise
 */
EXPORT
void *
HookMgr_GetHookedFunction(HookStub hookIndex)
{
   void *res = NULL;
   if (HOOK_IDX_VALID(hookIndex)) {
      res = gHook[hookIndex].registeredFunc;
   }
   return res;
}

/* there must be a better way to keep the linker from removing HookCore_Init! */
void
__ForceLinkerToIncludeHookCore_Init(void)
{
   extern void HookCore_Init(void);
   HookCore_Init();
}
