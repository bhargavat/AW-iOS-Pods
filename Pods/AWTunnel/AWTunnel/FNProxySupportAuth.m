//
//  FNProxySupportAuth.c
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#include <Security/Security.h>
#include <Fuji/HookManager.h>
#include "FNProxySupportPriv.h"


//#define FN_AUTH_TRACE_ON 1

#if defined(FN_AUTH_TRACE_ON)
#include <stdio.h>

#define FN_AUTH_TRACE(cond, label, obj)                                \
do {                                                                \
if (cond) {                                                      \
CFLog(CFSTR("%s [%s] ********"), (label), __FUNCTION__);      \
CFShow((obj));                                                \
CFLog(CFSTR("********"));                                     \
}                                                                \
} while (0)
#else
#define FN_AUTH_TRACE(cond, label, obj)
#endif


static volatile int authEnabled;

static OSStatus (*secItemAdd)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*secItemCopyMatching)(CFDictionaryRef, CFTypeRef *);
static OSStatus (*secItemDelete)(CFDictionaryRef);
static OSStatus (*secItemUpdate)(CFDictionaryRef, CFDictionaryRef);


/*
 * Array of authentication attribute results for general proxy-related
 * keychain queries.
 * One or more entries may be returned by the ItemCopyMatching() wrapper
 * when 'r_Attributes' is present in the query argument.
 */

static CFDictionaryRef attrQuery[SchemeTypeMax];


/*
 * Array of authentication password results for proxy-related keychain
 * queries _specific_ to password retrieval.
 * An entry may be returned by the ItemCopyMatching() wrapper
 * when 'r_Data' is present in the query argument.
 */

static CFDataRef credQuery[SchemeTypeMax];


/**
 * Converts a protocol type to a supported scheme type.
 * @param protocol protocol type reference.
 * @return a scheme type constant.
 */

static inline SchemeType
ProtocolToScheme(CFTypeRef protocol)
{
    if (protocol == kSecAttrProtocolHTTPProxy) {
        return SchemeTypeHTTP;
    }
    if (protocol == kSecAttrProtocolHTTPSProxy) {
        return SchemeTypeHTTPS;
    }
    if (protocol == kSecAttrProtocolFTPProxy) {
        return SchemeTypeFTP;
    }
    if (protocol == kSecAttrProtocolSOCKS) {
        return SchemeTypeSOCKS;
    }
    if (protocol == kSecAttrProtocolRTSPProxy) {
        return SchemeTypeRTSP;
    }
    if (protocol == NULL) {
        /* Unspecified protocol means include everything. */
        
        return SchemeTypeAll;
    }
    return SchemeTypeMax;
}


/**
 * Converts a scheme type constant to a protocol type.
 * @param scheme a scheme type constant.
 * @return protocol type reference.
 */

static inline CFTypeRef
SchemeToProtocol(SchemeType scheme)
{
    if (scheme == SchemeTypeHTTP) {
        return kSecAttrProtocolHTTPProxy;
    }
    if (scheme == SchemeTypeHTTPS) {
        return kSecAttrProtocolHTTPSProxy;
    }
    if (scheme == SchemeTypeFTP) {
        return kSecAttrProtocolFTPProxy;
    }
    if (scheme == SchemeTypeSOCKS) {
        return kSecAttrProtocolSOCKS;
    }
    if (scheme == SchemeTypeRTSP) {
        return kSecAttrProtocolRTSPProxy;
    }
    if (scheme == SchemeTypeFILE) {
        return kSecAttrProtocolHTTPProxy;
    }
    return NULL;
}


/**
 * Frees credential security items.
 */

void
_FNProxySupportAuthItemReset(void)
{
    authEnabled = 0;
    
    for (int i = 0; i < SchemeTypeMax; i++) {
        if (attrQuery[i]) {
            CFRelease(attrQuery[i]);
            attrQuery[i] = NULL;
        }
        if (credQuery[i]) {
            CFRelease(credQuery[i]);
            credQuery[i] = NULL;
        }
    }
}


/**
 * Adds a credential security item for a proxy scheme.
 * @param scheme scheme type.
 * @param hostName host name or IP address.
 * @param portNumber port number.
 * @param userName user name for proxy authentication.
 * @param password password for proxy authentication.
 * @return success or error code.
 */

_FNProxySupportError
_FNProxySupportAuthItemAdd(SchemeType scheme,
                           CFStringRef hostName,
                           CFNumberRef portNumber,
                           CFStringRef userName,
                           CFStringRef password)
{
    static const CFStringRef emptyStr = CFSTR("");
    CFDataRef cred = NULL;
    CFDateRef date = NULL;
    CFMutableDictionaryRef attr = NULL;
    CFMutableStringRef label = NULL;
    
    if ((scheme >= SchemeTypeMax) || !hostName || !portNumber || !userName) {
        return _kFNProxySupportErrorInvalidArguments;
    }
    
    if (password) {
        cred = CFStringCreateExternalRepresentation(kCFAllocatorDefault, password,
                                                    kCFStringEncodingUTF8, 0);
        if (!cred) {
            goto err;
        }
    }
    
    date = CFDateCreate(kCFAllocatorDefault, CFAbsoluteTimeGetCurrent());
    if (!date) {
        goto err;
    }
    
    attr = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
                                     &kCFTypeDictionaryKeyCallBacks,
                                     &kCFTypeDictionaryValueCallBacks);
    if (!attr) {
        goto err;
    }
    
    label = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, hostName);
    if (!label) {
        goto err;
    }
    
    CFStringAppend(label, CFSTR(" ("));
    CFStringAppend(label, userName);
    CFStringAppend(label, CFSTR(")"));
    CFDictionaryAddValue(attr, kSecAttrLabel, label);
    CFRelease(label);
    
    CFDictionaryAddValue(attr, kSecAttrCreationDate, date);
    CFDictionaryAddValue(attr, kSecAttrModificationDate, date);
    CFRelease(date);
    
    CFDictionaryAddValue(attr, kSecAttrServer, hostName);
    CFDictionaryAddValue(attr, kSecAttrPort, portNumber);
    CFDictionaryAddValue(attr, kSecAttrAccount, userName);
    CFDictionaryAddValue(attr, kSecAttrProtocol, SchemeToProtocol(scheme));
    CFDictionaryAddValue(attr, kSecAttrSecurityDomain, emptyStr);
    CFDictionaryAddValue(attr, kSecAttrPath, emptyStr);
    CFDictionaryAddValue(attr, kSecAttrAuthenticationType,
                         kSecAttrAuthenticationTypeHTTPBasic);
    CFDictionaryAddValue(attr, kSecAttrComment, CFSTR("default"));
    
    if (attrQuery[scheme]) {
        CFRelease(attrQuery[scheme]);
    }
    attrQuery[scheme] = CFDictionaryCreateCopy(kCFAllocatorDefault, attr);
    CFRelease(attr);
    
    if (credQuery[scheme]) {
        CFRelease(credQuery[scheme]);
    }
    credQuery[scheme] = cred;
    
    authEnabled = 1;
    return _kFNProxySupportErrorSuccess;
    
err:
    if (cred) {
        CFRelease(cred);
    }
    if (date) {
        CFRelease(date);
    }
    if (attr) {
        CFRelease(attr);
    }
    if (label) {
        CFRelease(label);
    }
    return _kFNProxySupportErrorOutOfMemory;
}


/**
 * Scheme type (protocol) if passed attributes specify a proxy-related item.
 * @param attrs item attributes.
 * @return scheme type if item is proxy-related, SchemeTypeMax otherwise.
 */

static inline SchemeType
ProxyScheme(CFDictionaryRef attrs)
{
    if (!authEnabled || !attrs ||
        (CFDictionaryGetValue(attrs, kSecClass) != kSecClassInternetPassword)) {
        return SchemeTypeMax;
    }
    
    return ProtocolToScheme(CFDictionaryGetValue(attrs, kSecAttrProtocol));
}


/**
 * Adds a security item.
 * This wrapper ensures that items representing proxy credentials are not
 * stored, such that application code may not retrieve them.
 * @param attrs item attributes.
 * @param[out] result newly created item.
 * @return errSecSuccess if successful, error code otherwise.
 */

//static OSStatus
OSStatus
ItemAdd(CFDictionaryRef attrs,
        CFTypeRef *result)
{
    OSStatus rc;
    
    if (ProxyScheme(attrs) == SchemeTypeMax) {
        /* Not a proxy authentication item. */
        
        rc = secItemAdd(attrs, result);
    } else {
        /* Must return an error since 'result' cannot be set. */
        
        rc = errSecAllocate;
    }
    
    FN_AUTH_TRACE(1, "\n\nATTRS", attrs);
    return rc;
}


/**
 * Retrieves a security item.
 * This wrapper retrieves items representing proxy credentials associated
 * with the proxy configucation.
 * @param query item attributes specifying the search.
 * @param[out] result found item.
 * @return errSecSuccess if successful, error code otherwise.
 */

//static OSStatus
OSStatus
ItemCopyMatching(CFDictionaryRef query,
                 CFTypeRef *result)
{
    OSStatus rc;
    SchemeType scheme;
    
    if ((scheme = ProxyScheme(query)) == SchemeTypeMax) {
        /* Not a proxy authentication item. */
        
        rc = secItemCopyMatching(query, result);
    } else {
        if (!query || !result) {
            rc = errSecParam;
            goto out;
        }
        
        rc = errSecSuccess;
        pthread_rwlock_rdlock(&_FNProxySupportLock);
        
        if (CFDictionaryContainsKey(query, kSecReturnAttributes)) {
            /* Query relates to the scheme's attributes, only. */
            
            if (scheme == SchemeTypeAll) {
                const void *attrs[SchemeTypeMax];
                int i;
                int j;
                
                for (i = 0, j = 0; j < SchemeTypeMax; j++) {
                    if (attrQuery[j]) {
                        attrs[i++] = attrQuery[j];
                    }
                }
                if (i == 0) {
                    goto zeroSizedResult;
                }
                *result = CFArrayCreate(kCFAllocatorDefault, attrs, i,
                                        &kCFTypeArrayCallBacks);
            } else if (attrQuery[scheme]) {
                *result = CFArrayCreate(kCFAllocatorDefault,
                                        (const void **)&attrQuery[scheme], 1,
                                        &kCFTypeArrayCallBacks);
            } else {
            zeroSizedResult:
                *result = CFArrayCreate(kCFAllocatorDefault, NULL, 0,
                                        &kCFTypeArrayCallBacks);
            }
        } else if (CFDictionaryContainsKey(query, kSecReturnData)) {
            /* Query relates to the scheme's credential (password), only. */
            
            if (credQuery[scheme]) {
                *result = CFRetain(credQuery[scheme]);
            } else {
                CFDataRef nothing =
                CFStringCreateExternalRepresentation(kCFAllocatorDefault,
                                                     CFSTR(""),
                                                     kCFStringEncodingUTF8, 0);
                
                *result = CFRetain(nothing);
            }
        } else {
            rc = errSecNotAvailable;
        }
        
        pthread_rwlock_unlock(&_FNProxySupportLock);
    }
    
    if (!*result) {
        rc = errSecNotAvailable;
    }
    
out:
    FN_AUTH_TRACE(1, "\n\nQUERY", query);
    FN_AUTH_TRACE((rc == errSecSuccess), "RESULT", *result);
    return rc;
}


/**
 * Deletes a security item.
 * This wrapper deletes items other than those representing proxy credentials
 * associated with the proxy configucation.
 * @param query item attributes specifying the search.
 * @return errSecSuccess if successful, error code otherwise.
 */

//static OSStatus
OSStatus
ItemDelete(CFDictionaryRef query)
{
    OSStatus rc;
    
    if (ProxyScheme(query) == SchemeTypeMax) {
        /* Not a proxy authentication item. */
        
        rc = secItemDelete(query);
    } else {
        rc = errSecSuccess;
    }
    
    FN_AUTH_TRACE(1, "QUERY", query);
    return rc;
}


/**
 * Updates a security item.
 * This wrapper updates items other than those representing proxy credentials
 * associated with the Fuji proxy configucation.
 * @param query item attributes specifying the search.
 * @param attrs attributes to update.
 * @return errSecSuccess if successful, error code otherwise.
 */

//static OSStatus
OSStatus
ItemUpdate(CFDictionaryRef query,
           CFDictionaryRef attrs)
{
    OSStatus rc;
    
    if (ProxyScheme(query) == SchemeTypeMax) {
        /* Not a proxy authentication item. */
        
        rc = secItemUpdate(query, attrs);
    } else {
        rc = errSecSuccess;
    }
    
    FN_AUTH_TRACE(1, "\n\nQUERY", query);
    FN_AUTH_TRACE(1, "ATTRS", attrs);
    return rc;
}


/**
 * One-time initialization function.
 * @return success or error code.
 */

_FNProxySupportError
_FNProxySupportAuthInit(void)
{
    if (secItemAdd) {
        /* Already initialized. */
        
        return _kFNProxySupportErrorSuccess;
    }

#if 0
    // Removing Security related Hooks.
    secItemAdd =
    HookMgr_GetOrigFunction(HOOK_Security_SecItemAdd);
    if (!secItemAdd) {
        goto initErr;
    }
    if (HookMgr_Register(ItemAdd, HOOK_Security_SecItemAdd)) {
        goto initErr;
    }
    
    secItemCopyMatching =
    HookMgr_GetOrigFunction(HOOK_Security_SecItemCopyMatching);
    if (!secItemCopyMatching) {
        goto initErr;
    }
    if (HookMgr_Register(ItemCopyMatching,
                         HOOK_Security_SecItemCopyMatching)) {
        goto initErr;
    }
    
    secItemDelete =
    HookMgr_GetOrigFunction(HOOK_Security_SecItemDelete);
    if (!secItemDelete) {
        goto initErr;
    }
    if (HookMgr_Register(ItemDelete,
                         HOOK_Security_SecItemDelete)) {
        goto initErr;
    }
    
    secItemUpdate =
    HookMgr_GetOrigFunction(HOOK_Security_SecItemUpdate);
    if (!secItemUpdate) {
        goto initErr;
    }
    if (HookMgr_Register(ItemUpdate,
                         HOOK_Security_SecItemUpdate)) {
        goto initErr;
    }
#endif
    /*
     * Disable core network interaction with the AuthBroker component such
     * that proxy credentials aren't a) exposed, and b) globally shared.
     */
    
    setenv("AUTHBROKER_SERVICE_NAME", "Inexistent", 1);
    return _kFNProxySupportErrorSuccess;
    
initErr:
#if 0
    // Removing Security related Hooks.
    
    if (secItemAdd) {
        HookMgr_UnRegister(HOOK_Security_SecItemAdd);
        secItemAdd = NULL;
    }
    if (secItemCopyMatching) {
        HookMgr_UnRegister(HOOK_Security_SecItemCopyMatching);
        secItemCopyMatching = NULL;
    }
    if (secItemDelete) {
        HookMgr_UnRegister(HOOK_Security_SecItemDelete);
        secItemDelete = NULL;
    }
    if (secItemUpdate) {
        HookMgr_UnRegister(HOOK_Security_SecItemUpdate);
        secItemUpdate = NULL;
    }
#endif
    return _kFNProxySupportErrorInternal;
}

