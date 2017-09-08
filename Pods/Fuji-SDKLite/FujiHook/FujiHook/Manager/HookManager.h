//
//  HookManager.h
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#ifndef _HOOK_MANAGER_H_
#define _HOOK_MANAGER_H_

#import "Stubs.h"


#pragma mark - Hooking Errors codes

//Errors codes.
#define ERROR_SUCCESS 0
#define ERROR_INVALID_ARG -1
#define ERROR_HOOK_ALREADY_REGISTERED -2
#define ERROR_LIBRARY_ALREADY_HOOKED -3

extern int HookMgr_Register(void *hookAddress, HookStub hookIndex);
extern void *HookMgr_UnRegister(HookStub hookIndex);
extern void *HookMgr_GetOrigFunction(HookStub hookIndex);
extern void *HookMgr_GetHookedFunction(HookStub hookIndex);
#define ERROR_INVALID_ARG -1
#define ERROR_HOOK_ALREADY_REGISTERED -2
#endif
