
/* WARNING: Auto-generated from FujiHook/Metadata/Stubs.xml */

/*
 * This file has been manually modified to accommodate the changes in iOS 10 SDK Simulator
 * libraries for hooked function `tcp_connection_start` and `tcp_connection_cancel`.
 */
#include <TargetConditionals.h>
#include "Stubs.h"
#include "HookCore.h"


static void *
hook_CFURLCredentialStorageCopyAllCredentials(void * arg0)
{
   // call hook if implemented
   HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials_type hooked_CFURLCredentialStorageCopyAllCredentials =
      (HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials_type)(gHook[HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials].registeredFunc);
   if (hooked_CFURLCredentialStorageCopyAllCredentials) {
      return hooked_CFURLCredentialStorageCopyAllCredentials(arg0);
   }

   // call original implementation
   HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials_type orig_CFURLCredentialStorageCopyAllCredentials =
      (HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials_type)(gHook[HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials].origAddress);
   return orig_CFURLCredentialStorageCopyAllCredentials(arg0);
}

static void *
hook_CFURLCredentialStorageCopyCredentialsForProtectionSpace(void * arg0, void * arg1)
{
   // call hook if implemented
   HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace_type hooked_CFURLCredentialStorageCopyCredentialsForProtectionSpace =
      (HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace_type)(gHook[HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace].registeredFunc);
   if (hooked_CFURLCredentialStorageCopyCredentialsForProtectionSpace) {
      return hooked_CFURLCredentialStorageCopyCredentialsForProtectionSpace(arg0, arg1);
   }

   // call original implementation
   HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace_type orig_CFURLCredentialStorageCopyCredentialsForProtectionSpace =
      (HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace_type)(gHook[HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace].origAddress);
   return orig_CFURLCredentialStorageCopyCredentialsForProtectionSpace(arg0, arg1);
}

static void *
hook_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace(void * arg0, void * arg1)
{
   // call hook if implemented
   HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace_type hooked_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace =
      (HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace_type)(gHook[HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace].registeredFunc);
   if (hooked_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace) {
      return hooked_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace(arg0, arg1);
   }

   // call original implementation
   HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace_type orig_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace =
      (HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace_type)(gHook[HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace].origAddress);
   return orig_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace(arg0, arg1);
}

static void *
hook_CFNetworkCopySystemProxySettings(void)
{
   // call hook if implemented
   HOOK_CFNetwork_CFNetworkCopySystemProxySettings_type hooked_CFNetworkCopySystemProxySettings =
      (HOOK_CFNetwork_CFNetworkCopySystemProxySettings_type)(gHook[HOOK_CFNetwork_CFNetworkCopySystemProxySettings].registeredFunc);
   if (hooked_CFNetworkCopySystemProxySettings) {
      return hooked_CFNetworkCopySystemProxySettings();
   }

   // call original implementation
   HOOK_CFNetwork_CFNetworkCopySystemProxySettings_type orig_CFNetworkCopySystemProxySettings =
      (HOOK_CFNetwork_CFNetworkCopySystemProxySettings_type)(gHook[HOOK_CFNetwork_CFNetworkCopySystemProxySettings].origAddress);
   return orig_CFNetworkCopySystemProxySettings();
}

static void *
hook_SCDynamicStoreCopyProxies(void * arg0)
{
   // call hook if implemented
   HOOK_SystemConfiguration_SCDynamicStoreCopyProxies_type hooked_SCDynamicStoreCopyProxies =
      (HOOK_SystemConfiguration_SCDynamicStoreCopyProxies_type)(gHook[HOOK_SystemConfiguration_SCDynamicStoreCopyProxies].registeredFunc);
   if (hooked_SCDynamicStoreCopyProxies) {
      return hooked_SCDynamicStoreCopyProxies(arg0);
   }

   // call original implementation
   HOOK_SystemConfiguration_SCDynamicStoreCopyProxies_type orig_SCDynamicStoreCopyProxies =
      (HOOK_SystemConfiguration_SCDynamicStoreCopyProxies_type)(gHook[HOOK_SystemConfiguration_SCDynamicStoreCopyProxies].origAddress);
   return orig_SCDynamicStoreCopyProxies(arg0);
}

static void
hook_tcp_connection_start(void * arg0)
{
   // call hook if implemented
   HOOK_libsystem_network_tcp_connection_start_type hooked_tcp_connection_start =
      (HOOK_libsystem_network_tcp_connection_start_type)(gHook[HOOK_libsystem_network_tcp_connection_start].registeredFunc);
   if (hooked_tcp_connection_start) {
      return hooked_tcp_connection_start(arg0);
   }

   // call original implementation
   HOOK_libsystem_network_tcp_connection_start_type orig_tcp_connection_start =
      (HOOK_libsystem_network_tcp_connection_start_type)(gHook[HOOK_libsystem_network_tcp_connection_start].origAddress);
   return orig_tcp_connection_start(arg0);
}

static void
hook_tcp_connection_cancel(void * arg0)
{
   // call hook if implemented
   HOOK_libsystem_network_tcp_connection_cancel_type hooked_tcp_connection_cancel =
      (HOOK_libsystem_network_tcp_connection_cancel_type)(gHook[HOOK_libsystem_network_tcp_connection_cancel].registeredFunc);
   if (hooked_tcp_connection_cancel) {
      return hooked_tcp_connection_cancel(arg0);
   }

   // call original implementation
   HOOK_libsystem_network_tcp_connection_cancel_type orig_tcp_connection_cancel =
      (HOOK_libsystem_network_tcp_connection_cancel_type)(gHook[HOOK_libsystem_network_tcp_connection_cancel].origAddress);
   return orig_tcp_connection_cancel(arg0);
}

static void *
hook_xpc_dictionary_get_value(void * arg0, const char * arg1)
{
   // call hook if implemented
   HOOK_libxpc_xpc_dictionary_get_value_type hooked_xpc_dictionary_get_value =
      (HOOK_libxpc_xpc_dictionary_get_value_type)(gHook[HOOK_libxpc_xpc_dictionary_get_value].registeredFunc);
   if (hooked_xpc_dictionary_get_value) {
      return hooked_xpc_dictionary_get_value(arg0, arg1);
   }

   // call original implementation
   HOOK_libxpc_xpc_dictionary_get_value_type orig_xpc_dictionary_get_value =
      (HOOK_libxpc_xpc_dictionary_get_value_type)(gHook[HOOK_libxpc_xpc_dictionary_get_value].origAddress);
   return orig_xpc_dictionary_get_value(arg0, arg1);
}

static void *
hook_xpc_array_create(void * arg0, size_t arg1)
{
   // call hook if implemented
   HOOK_libxpc_xpc_array_create_type hooked_xpc_array_create =
      (HOOK_libxpc_xpc_array_create_type)(gHook[HOOK_libxpc_xpc_array_create].registeredFunc);
   if (hooked_xpc_array_create) {
      return hooked_xpc_array_create(arg0, arg1);
   }

   // call original implementation
   HOOK_libxpc_xpc_array_create_type orig_xpc_array_create =
      (HOOK_libxpc_xpc_array_create_type)(gHook[HOOK_libxpc_xpc_array_create].origAddress);
   return orig_xpc_array_create(arg0, arg1);
}

static void *
hook_xpc_int64_create(int64_t arg0)
{
   // call hook if implemented
   HOOK_libxpc_xpc_int64_create_type hooked_xpc_int64_create =
      (HOOK_libxpc_xpc_int64_create_type)(gHook[HOOK_libxpc_xpc_int64_create].registeredFunc);
   if (hooked_xpc_int64_create) {
      return hooked_xpc_int64_create(arg0);
   }

   // call original implementation
   HOOK_libxpc_xpc_int64_create_type orig_xpc_int64_create =
      (HOOK_libxpc_xpc_int64_create_type)(gHook[HOOK_libxpc_xpc_int64_create].origAddress);
   return orig_xpc_int64_create(arg0);
}

static void *
hook_xpc_string_create(const char * arg0)
{
   // call hook if implemented
   HOOK_libxpc_xpc_string_create_type hooked_xpc_string_create =
      (HOOK_libxpc_xpc_string_create_type)(gHook[HOOK_libxpc_xpc_string_create].registeredFunc);
   if (hooked_xpc_string_create) {
      return hooked_xpc_string_create(arg0);
   }

   // call original implementation
   HOOK_libxpc_xpc_string_create_type orig_xpc_string_create =
      (HOOK_libxpc_xpc_string_create_type)(gHook[HOOK_libxpc_xpc_string_create].origAddress);
   return orig_xpc_string_create(arg0);
}

static void *
hook_xpc_dictionary_create(const char * const * arg0, void ** arg1, size_t arg2)
{
   // call hook if implemented
   HOOK_libxpc_xpc_dictionary_create_type hooked_xpc_dictionary_create =
      (HOOK_libxpc_xpc_dictionary_create_type)(gHook[HOOK_libxpc_xpc_dictionary_create].registeredFunc);
   if (hooked_xpc_dictionary_create) {
      return hooked_xpc_dictionary_create(arg0, arg1, arg2);
   }

   // call original implementation
   HOOK_libxpc_xpc_dictionary_create_type orig_xpc_dictionary_create =
      (HOOK_libxpc_xpc_dictionary_create_type)(gHook[HOOK_libxpc_xpc_dictionary_create].origAddress);
   return orig_xpc_dictionary_create(arg0, arg1, arg2);
}

static const char *
hook_xpc_dictionary_get_string(void * arg0, const char * arg1)
{
   // call hook if implemented
   HOOK_libxpc_xpc_dictionary_get_string_type hooked_xpc_dictionary_get_string =
      (HOOK_libxpc_xpc_dictionary_get_string_type)(gHook[HOOK_libxpc_xpc_dictionary_get_string].registeredFunc);
   if (hooked_xpc_dictionary_get_string) {
      return hooked_xpc_dictionary_get_string(arg0, arg1);
   }

   // call original implementation
   HOOK_libxpc_xpc_dictionary_get_string_type orig_xpc_dictionary_get_string =
      (HOOK_libxpc_xpc_dictionary_get_string_type)(gHook[HOOK_libxpc_xpc_dictionary_get_string].origAddress);
   return orig_xpc_dictionary_get_string(arg0, arg1);
}

static uint64_t
hook_xpc_dictionary_get_uint64(void * arg0, const char * arg1)
{
   // call hook if implemented
   HOOK_libxpc_xpc_dictionary_get_uint64_type hooked_xpc_dictionary_get_uint64 =
      (HOOK_libxpc_xpc_dictionary_get_uint64_type)(gHook[HOOK_libxpc_xpc_dictionary_get_uint64].registeredFunc);
   if (hooked_xpc_dictionary_get_uint64) {
      return hooked_xpc_dictionary_get_uint64(arg0, arg1);
   }

   // call original implementation
   HOOK_libxpc_xpc_dictionary_get_uint64_type orig_xpc_dictionary_get_uint64 =
      (HOOK_libxpc_xpc_dictionary_get_uint64_type)(gHook[HOOK_libxpc_xpc_dictionary_get_uint64].origAddress);
   return orig_xpc_dictionary_get_uint64(arg0, arg1);
}

static void
hook_xpc_dictionary_set_value(void * arg0, const char * arg1, void * arg2)
{
   // call hook if implemented
   HOOK_libxpc_xpc_dictionary_set_value_type hooked_xpc_dictionary_set_value =
      (HOOK_libxpc_xpc_dictionary_set_value_type)(gHook[HOOK_libxpc_xpc_dictionary_set_value].registeredFunc);
   if (hooked_xpc_dictionary_set_value) {
      return hooked_xpc_dictionary_set_value(arg0, arg1, arg2);
   }

   // call original implementation
   HOOK_libxpc_xpc_dictionary_set_value_type orig_xpc_dictionary_set_value =
      (HOOK_libxpc_xpc_dictionary_set_value_type)(gHook[HOOK_libxpc_xpc_dictionary_set_value].origAddress);
   return orig_xpc_dictionary_set_value(arg0, arg1, arg2);
}

static void *
hook_CFURLProtectionSpaceGetHost(const void * arg0)
{
   // call hook if implemented
   HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type hooked_CFURLProtectionSpaceGetHost =
      (HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type)(gHook[HOOK_CFNetwork_CFURLProtectionSpaceGetHost].registeredFunc);
   if (hooked_CFURLProtectionSpaceGetHost) {
      return hooked_CFURLProtectionSpaceGetHost(arg0);
   }

   // call original implementation
   HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type orig_CFURLProtectionSpaceGetHost =
      (HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type)(gHook[HOOK_CFNetwork_CFURLProtectionSpaceGetHost].origAddress);
   return orig_CFURLProtectionSpaceGetHost(arg0);
}

static int32_t
hook_CFURLProtectionSpaceGetPort(const void * arg0)
{
   // call hook if implemented
   HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type hooked_CFURLProtectionSpaceGetPort =
      (HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type)(gHook[HOOK_CFNetwork_CFURLProtectionSpaceGetPort].registeredFunc);
   if (hooked_CFURLProtectionSpaceGetPort) {
      return hooked_CFURLProtectionSpaceGetPort(arg0);
   }

   // call original implementation
   HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type orig_CFURLProtectionSpaceGetPort =
      (HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type)(gHook[HOOK_CFNetwork_CFURLProtectionSpaceGetPort].origAddress);
   return orig_CFURLProtectionSpaceGetPort(arg0);
}

static int
hook_CFURLProtectionSpaceGetServerType(const void * arg0)
{
   // call hook if implemented
   HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type hooked_CFURLProtectionSpaceGetServerType =
      (HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type)(gHook[HOOK_CFNetwork_CFURLProtectionSpaceGetServerType].registeredFunc);
   if (hooked_CFURLProtectionSpaceGetServerType) {
      return hooked_CFURLProtectionSpaceGetServerType(arg0);
   }

   // call original implementation
   HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type orig_CFURLProtectionSpaceGetServerType =
      (HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type)(gHook[HOOK_CFNetwork_CFURLProtectionSpaceGetServerType].origAddress);
   return orig_CFURLProtectionSpaceGetServerType(arg0);
}

static void *
hook__CFNetworkSetOverrideSystemProxySettings(void * arg0)
{
   // call hook if implemented
   HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type hooked__CFNetworkSetOverrideSystemProxySettings =
      (HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type)(gHook[HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings].registeredFunc);
   if (hooked__CFNetworkSetOverrideSystemProxySettings) {
      return hooked__CFNetworkSetOverrideSystemProxySettings(arg0);
   }

   // call original implementation
   HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type orig__CFNetworkSetOverrideSystemProxySettings =
      (HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type)(gHook[HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings].origAddress);
   return orig__CFNetworkSetOverrideSystemProxySettings(arg0);
}

static void *
hook_CFReadStreamCreateForHTTPRequest(void * arg0, void * arg1)
{
   // call hook if implemented
   HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest_type hooked_CFReadStreamCreateForHTTPRequest =
      (HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest_type)(gHook[HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest].registeredFunc);
   if (hooked_CFReadStreamCreateForHTTPRequest) {
      return hooked_CFReadStreamCreateForHTTPRequest(arg0, arg1);
   }

   // call original implementation
   HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest_type orig_CFReadStreamCreateForHTTPRequest =
      (HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest_type)(gHook[HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest].origAddress);
   return orig_CFReadStreamCreateForHTTPRequest(arg0, arg1);
}

extern void HCHook_syscall(void);


HCHookContext gHook[HOOK_MAX+1] = {
   [HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials] = {
      .hookAddress = hook_CFURLCredentialStorageCopyAllCredentials,
      .libName = "CFNetwork",
      .funcName = "_CFURLCredentialStorageCopyAllCredentials"
   },
   [HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace] = {
      .hookAddress = hook_CFURLCredentialStorageCopyCredentialsForProtectionSpace,
      .libName = "CFNetwork",
      .funcName = "_CFURLCredentialStorageCopyCredentialsForProtectionSpace"
   },
   [HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace] = {
      .hookAddress = hook_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace,
      .libName = "CFNetwork",
      .funcName = "_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace"
   },
   [HOOK_CFNetwork_CFNetworkCopySystemProxySettings] = {
      .hookAddress = hook_CFNetworkCopySystemProxySettings,
      .libName = "CFNetwork",
      .funcName = "_CFNetworkCopySystemProxySettings"
   },
   [HOOK_SystemConfiguration_SCDynamicStoreCopyProxies] = {
      .hookAddress = hook_SCDynamicStoreCopyProxies,
      .libName = "SystemConfiguration",
      .funcName = "_SCDynamicStoreCopyProxies"
   },
   [HOOK_libsystem_network_tcp_connection_start] = {
      .hookAddress = hook_tcp_connection_start,
#if TARGET_OS_SIMULATOR && defined(__IPHONE_10_0)
      .libName = "libnetwork",
#else
      .libName = "libsystem_network",
#endif
      .funcName = "_tcp_connection_start"
   },
   [HOOK_libsystem_network_tcp_connection_cancel] = {
      .hookAddress = hook_tcp_connection_cancel,
#if TARGET_OS_SIMULATOR && defined(__IPHONE_10_0)
      .libName = "libnetwork",
#else
      .libName = "libsystem_network",
#endif
      .funcName = "_tcp_connection_cancel"
   },
   [HOOK_libxpc_xpc_dictionary_get_value] = {
      .hookAddress = hook_xpc_dictionary_get_value,
      .libName = "libxpc",
      .funcName = "_xpc_dictionary_get_value"
   },
   [HOOK_libxpc_xpc_array_create] = {
      .hookAddress = hook_xpc_array_create,
      .libName = "libxpc",
      .funcName = "_xpc_array_create"
   },
   [HOOK_libxpc_xpc_int64_create] = {
      .hookAddress = hook_xpc_int64_create,
      .libName = "libxpc",
      .funcName = "_xpc_int64_create"
   },
   [HOOK_libxpc_xpc_string_create] = {
      .hookAddress = hook_xpc_string_create,
      .libName = "libxpc",
      .funcName = "_xpc_string_create"
   },
   [HOOK_libxpc_xpc_dictionary_create] = {
      .hookAddress = hook_xpc_dictionary_create,
      .libName = "libxpc",
      .funcName = "_xpc_dictionary_create"
   },
   [HOOK_libxpc_xpc_dictionary_get_string] = {
      .hookAddress = hook_xpc_dictionary_get_string,
      .libName = "libxpc",
      .funcName = "_xpc_dictionary_get_string"
   },
   [HOOK_libxpc_xpc_dictionary_get_uint64] = {
      .hookAddress = hook_xpc_dictionary_get_uint64,
      .libName = "libxpc",
      .funcName = "_xpc_dictionary_get_uint64"
   },
   [HOOK_libxpc_xpc_dictionary_set_value] = {
      .hookAddress = hook_xpc_dictionary_set_value,
      .libName = "libxpc",
      .funcName = "_xpc_dictionary_set_value"
   },
   [HOOK_CFNetwork_CFURLProtectionSpaceGetHost] = {
      .hookAddress = hook_CFURLProtectionSpaceGetHost,
      .libName = "CFNetwork",
      .funcName = "_CFURLProtectionSpaceGetHost"
   },
   [HOOK_CFNetwork_CFURLProtectionSpaceGetPort] = {
      .hookAddress = hook_CFURLProtectionSpaceGetPort,
      .libName = "CFNetwork",
      .funcName = "_CFURLProtectionSpaceGetPort"
   },
   [HOOK_CFNetwork_CFURLProtectionSpaceGetServerType] = {
      .hookAddress = hook_CFURLProtectionSpaceGetServerType,
      .libName = "CFNetwork",
      .funcName = "_CFURLProtectionSpaceGetServerType"
   },
   [HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings] = {
      .hookAddress = hook__CFNetworkSetOverrideSystemProxySettings,
      .libName = "CFNetwork",
      .funcName = "__CFNetworkSetOverrideSystemProxySettings"
   },
   [HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest] = {
      .hookAddress = hook_CFReadStreamCreateForHTTPRequest,
      .libName = "CFNetwork",
      .funcName = "_CFReadStreamCreateForHTTPRequest"
   },
#ifdef __arm__
   [HOOK_libsystem_kernel_syscall] = {
      .hookAddress = HCHook_syscall,
      .libName = "libsystem_kernel",
      .funcName = "_syscall"
   },
#endif
};
