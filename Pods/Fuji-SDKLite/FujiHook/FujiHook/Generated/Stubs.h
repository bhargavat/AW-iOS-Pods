
/* WARNING: Auto-generated from FujiHook/Metadata/Stubs.xml */
#ifndef _STUBS_H_
#define _STUBS_H_

#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <sys/types.h>

#include "StubsConstants.h"

typedef unsigned int HookStub;


typedef void * (*HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials_type)(void * arg0);
typedef void * (*HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace_type)(void * arg0, void * arg1);
typedef void * (*HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace_type)(void * arg0, void * arg1);
typedef void * (*HOOK_CFNetwork_CFNetworkCopySystemProxySettings_type)(void);
typedef void * (*HOOK_SystemConfiguration_SCDynamicStoreCopyProxies_type)(void * arg0);
typedef void (*HOOK_libsystem_network_tcp_connection_start_type)(void * arg0);
typedef void (*HOOK_libsystem_network_tcp_connection_cancel_type)(void * arg0);
typedef void * (*HOOK_libxpc_xpc_dictionary_get_value_type)(void * arg0, const char * arg1);
typedef void * (*HOOK_libxpc_xpc_array_create_type)(void * arg0, size_t arg1);
typedef void * (*HOOK_libxpc_xpc_int64_create_type)(int64_t arg0);
typedef void * (*HOOK_libxpc_xpc_string_create_type)(const char * arg0);
typedef void * (*HOOK_libxpc_xpc_dictionary_create_type)(const char * const * arg0, void ** arg1, size_t arg2);
typedef const char * (*HOOK_libxpc_xpc_dictionary_get_string_type)(void * arg0, const char * arg1);
typedef uint64_t (*HOOK_libxpc_xpc_dictionary_get_uint64_type)(void * arg0, const char * arg1);
typedef void (*HOOK_libxpc_xpc_dictionary_set_value_type)(void * arg0, const char * arg1, void * arg2);
typedef void * (*HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type)(const void * arg0);
typedef int32_t (*HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type)(const void * arg0);
typedef int (*HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type)(const void * arg0);
typedef void * (*HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type)(void * arg0);
typedef void * (*HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest_type)(void * arg0, void * arg1);
typedef int (*HOOK_libsystem_kernel_syscall_type)(int arg0);
#endif

