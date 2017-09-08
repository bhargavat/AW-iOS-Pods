/* ********************************************************************
 * Copyright (C) 2012 VMware, Inc. All rights reserved.
 * -- VMware Confidential
 * ********************************************************************/

/* HookCore.h --
 *
 * Public Interface of HookCore.
 */

/*
 * WARNING:
 * This file should always be included last to ensure the assert()
 * definition is not stripped out (see end of file for details).
 */

#ifndef _HOOKING_CORE_H_
#define _HOOKING_CORE_H_

#include <sys/types.h>
#include <stdint.h>

#pragma mark - Hooking Internal State

/*
 * This structure to be partially initialized by generated stubs.
 *
 * WARNING:
 * Assembly shim code generation relies on this structure definition.
 * If the layout should ever change, then update shim code generation.
 */

typedef struct {
   void *origAddress;         // Original Address of function.
   void *registeredFunc;      // Address of second-level hook.
   const void *hookAddress;   // Address of first-level hook.
   const char *libName;       // Name of dylib in which exports function-to-hook.
   const char *funcName;      // Name of function to hook.
} HCHookContext;

/* Defined by generated stubs with the last entry as all zero */
extern HCHookContext gHook[];

#endif

/*
 * Keep these lines outside of the inclusion guard since <assert.h>
 * must be (re-)included with NDEBUG undefined.
 *
 */

#undef NDEBUG
#include <assert.h>

