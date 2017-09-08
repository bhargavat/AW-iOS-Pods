//
//  FNProxySupportCredFilters.c
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#include <Fuji/HookManager.h>
#include "FNProxySupportPriv.h"

#ifndef kCFCoreFoundationVersionNumber_iOS_7_1
#define kCFCoreFoundationVersionNumber_iOS_7_1 847.24
#endif

/*
 * Miscellaneous private Core foundation data and function prototypes.
 */

typedef enum FNProtSpaceType {
    kCFURLProtectionSpaceProxyBase = 5,
    kCFURLProtectionSpaceProxyHTTP = kCFURLProtectionSpaceProxyBase,
    kCFURLProtectionSpaceProxyHTTPS,
    kCFURLProtectionSpaceProxyFTP,
    kCFURLProtectionSpaceProxySOCKS,
    kCFURLProtectionSpaceProxyRTSP, /* Original doesn't seem to exist... */
    kCFURLProtectionSpaceProxyMax
} FNProtSpaceType;


HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type orig_CFURLProtectionSpaceGetHost;
HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type orig_CFURLProtectionSpaceGetPort;
HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type orig_CFURLProtectionSpaceGetServerType;



/*
 * Original, private function pointers to intercept.
 */

static CFMutableDictionaryRef (*copyAllCredentials)(CFTypeRef credStorage);

static CFMutableDictionaryRef
(*copyCredentialsForProtSpace)(CFTypeRef credStorage,
                               CFTypeRef protSpace);

static CFTypeRef
(*copyDefaultCredentialForProtSpace)(CFTypeRef credStorage,
                                     CFTypeRef protSpace);


/*
 * Only non-system callers should have returned credentials filtered.
 * Deciding whether to filter credentials could be based on the call stack,
 * if the wrapping mechanism doesn't allow us to specify how/when original
 * functions should be replaced.
 */

#define FN_CRED_SHOULD_FILTER() \
(1)


/**
 * Converts a protection space type to a supported scheme type.
 * @param protSpaceType protection space type.
 * @return a scheme type constant.
 */

static inline SchemeType
ProtSpaceTypeToScheme(FNProtSpaceType protSpaceType)
{
    if ((protSpaceType >= kCFURLProtectionSpaceProxyBase) &&
        (protSpaceType < kCFURLProtectionSpaceProxyMax)) {
        return (protSpaceType - kCFURLProtectionSpaceProxyBase);
    }
    
    return SchemeTypeMax;
}


/**
 * Checks whether a protection space refers to a proxy server.
 * @param proxyInfoArray proxy configuration information array.
 * @param protSpace protection space object.
 * @return != 0 if yes, 0 if no.
 */

static int
IsProxyCredential(CFArrayRef proxyInfoArray,
                  CFTypeRef protSpace)
{
    SchemeType scheme;
    CFStringRef hostName;
    CFNumberRef portNumber;
    int64_t port;
    
    if (!proxyInfoArray || !protSpace) {
        return 0;
    }
    
    scheme = ProtSpaceTypeToScheme(orig_CFURLProtectionSpaceGetServerType(protSpace));
    if (scheme >= SchemeTypeMax) {
        return 0;
    }
    
    hostName = CFArrayGetValueAtIndex(proxyInfoArray, scheme * 2 + 0);
    portNumber = CFArrayGetValueAtIndex(proxyInfoArray, scheme * 2 + 1);
    if (!hostName || !portNumber) {
        return 0;
    }
    
    CFNumberGetValue(portNumber, kCFNumberSInt64Type, &port);
    if (((int64_t)orig_CFURLProtectionSpaceGetPort(protSpace) == port) &&
        (CFStringCompare(orig_CFURLProtectionSpaceGetHost(protSpace),
                         hostName, kCFCompareCaseInsensitive) ==
         kCFCompareEqualTo)) {
            return 1;
        }
    
    return 0;
}


/*
 * Returns a copy of all server credentials; proxy ones potentially removed.
 * This wrapper intercepts the function
 *       'CFURLCredentialStorageCopyAllCredentials()'
 *    in Core foundation. The purpose of this functions is to filter out
 *    potential proxy credentials returned by the original function when
 *    called from non-system code.
 * @param credStorage credential storage parameter.
 * @return filtered system credentials.
 */

static CFDictionaryRef
CopyAllCredentials(CFTypeRef credStorage)
{
    CFMutableDictionaryRef result;
    
    result = copyAllCredentials(credStorage);
    if (result && FN_CRED_SHOULD_FILTER()) {
        CFTypeRef *keys;
        CFIndex count;
        CFIndex i;
        CFArrayRef proxyInfoArray;
        
        count = CFDictionaryGetCount(result);
        if (count <= 0) {
            goto out;
        }
        
        /*
         * In error cases, remove everything from the result dictionary
         * rather than leak information.
         */
        
        if (count >= (INT32_MAX / (sizeof *keys))) {
            /*
             * Safeguard against integer overflow in the 'malloc' call below.
             */
            
            CFDictionaryRemoveAllValues(result);
            goto out;
        }
        
        if (!(keys = malloc((sizeof *keys) * count))) {
            CFDictionaryRemoveAllValues(result);
            goto out;
        }
        
        CFDictionaryGetKeysAndValues(result, keys, NULL);
        
        proxyInfoArray = _FNProxySupportCopyProxyServers();
        if (proxyInfoArray) {
            for (i = 0; i < count; i++) {
                if (IsProxyCredential(proxyInfoArray, keys[i])) {
                    CFDictionaryRemoveValue(result, keys[i]);
                }
                
                /* Keys must not be released ('get' convention allocation rules). */
            }
            CFRelease(proxyInfoArray);
        }
        
        free(keys);
    }
    
out:
    return result;
}


/*
 * Returns a copy of server credentials for a given protection space;
 * proxy credentials are potentially removed.
 * This wrapper intercepts the function
 *       'CFURLCredentialStorageCopyCredentialsForProtectionSpace()'
 *    in Core foundation. The purpose of this functions is to filter out
 *    potential proxy credentials returned by the original function when
 *    called from non-system code.
 * @param credStorage credential storage object.
 * @param protSpace protection space object.
 * @return filtered system credentials.
 */

static CFDictionaryRef
CopyCredentialsForProtSpace(CFTypeRef credStorage,
                            CFTypeRef protSpace)
{
    CFMutableDictionaryRef result;
    
    result = copyCredentialsForProtSpace(credStorage, protSpace);
    if (result && FN_CRED_SHOULD_FILTER()) {
        CFArrayRef proxyInfoArray = _FNProxySupportCopyProxyServers();
        if (proxyInfoArray) {
            if (IsProxyCredential(proxyInfoArray, protSpace)) {
                CFDictionaryRemoveAllValues(result);
            }
            CFRelease(proxyInfoArray);
        }
    }
    
    return result;
}


/*
 * Returns a copy of the default credential for a given protection space;
 * if a valid default proxy credential is returned by the original function,
 * the wrapper returns NULL (non-existent).
 * This function intercepts the function
 *       'CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace()'
 *    in Core foundation. The purpose of this functions is to filter out
 *    potential proxy credentials returned by the original function when
 *    called from non-system code.
 * @param credStorage credential storage object.
 * @param protSpace protection space object.
 * @return default credential or NULL, if filtered.
 */

static CFTypeRef
CopyDefaultCredentialForProtSpace(CFTypeRef credStorage,
                                  CFTypeRef protSpace)
{
    CFTypeRef result;
    
    result = copyDefaultCredentialForProtSpace(credStorage, protSpace);
    if (result && FN_CRED_SHOULD_FILTER()) {
        CFArrayRef proxyInfoArray = _FNProxySupportCopyProxyServers();
        if (proxyInfoArray) {
            if (IsProxyCredential(proxyInfoArray, protSpace)) {
                CFRelease(result);
                result = NULL;
            }
            CFRelease(proxyInfoArray);
        }
    }
    
    return result;
}


/**
 * One-time initialization function.
 * @return success or error code.
 */

_FNProxySupportError
_FNProxySupportCredFiltersInit(void)
{
    HookStub hookIndex;
    
    if (copyAllCredentials) {
        /* Already initialized. */
        
        return _kFNProxySupportErrorSuccess;
    }
    
    hookIndex =
    HOOK_CFNetwork_CFURLCredentialStorageCopyAllCredentials;
    copyAllCredentials = HookMgr_GetOrigFunction(hookIndex);
    if (!copyAllCredentials) {
        goto initErr;
    }
    if (HookMgr_Register(CopyAllCredentials, hookIndex)) {
        goto initErr;
    }
    
    hookIndex =
    HOOK_CFNetwork_CFURLCredentialStorageCopyCredentialsForProtectionSpace;
    copyCredentialsForProtSpace = HookMgr_GetOrigFunction(hookIndex);
    if (!copyCredentialsForProtSpace) {
        goto initErr;
    }
    if (HookMgr_Register(CopyCredentialsForProtSpace, hookIndex)) {
        goto initErr;
    }
    
    hookIndex =
    HOOK_CFNetwork_CFURLCredentialStorageCopyDefaultCredentialForProtectionSpace;
    copyDefaultCredentialForProtSpace = HookMgr_GetOrigFunction(hookIndex);
    if (!copyDefaultCredentialForProtSpace) {
        goto initErr;
    }
    if (HookMgr_Register(CopyDefaultCredentialForProtSpace, hookIndex)) {
        goto initErr;
    }
    
    orig_CFURLProtectionSpaceGetHost = (HOOK_CFNetwork_CFURLProtectionSpaceGetHost_type)HookMgr_GetOrigFunction(HOOK_CFNetwork_CFURLProtectionSpaceGetHost);
    orig_CFURLProtectionSpaceGetPort = (HOOK_CFNetwork_CFURLProtectionSpaceGetPort_type)HookMgr_GetOrigFunction(HOOK_CFNetwork_CFURLProtectionSpaceGetPort);
    orig_CFURLProtectionSpaceGetServerType = (HOOK_CFNetwork_CFURLProtectionSpaceGetServerType_type)HookMgr_GetOrigFunction(HOOK_CFNetwork_CFURLProtectionSpaceGetServerType);

    
    return _kFNProxySupportErrorSuccess;
    
initErr:
    return _kFNProxySupportErrorInternal;
}

