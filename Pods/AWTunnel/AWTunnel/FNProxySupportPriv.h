//
//  FNProxySupportPriv.h
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#ifndef _FN_PROXY_SUPPORT_PRIV_H_
#define _FN_PROXY_SUPPORT_PRIV_H_

#include <CoreFoundation/CFNumber.h>
#include <CoreFoundation/CFDictionary.h>
#include <CoreFoundation/CFURL.h>
#include <CFNetwork/CFHTTPMessage.h>
#include <SystemConfiguration/SCDynamicStoreCopySpecific.h>
#include "FNPriv.h"


typedef enum _FNProxySupportError {
    _kFNProxySupportErrorSuccess = 0,
    _kFNProxySupportErrorInvalidArguments = -1,
    _kFNProxySupportErrorOutOfMemory = -2,
    _kFNProxySupportErrorInternal = -3
} _FNProxySupportError;


void set_content_filter_function(void * callback);
void set_proxy_handler_function(void * callback);

void _FNProxySupportInit(void);
_FNProxySupportError _FNProxySupportSetProxySettings(CFArrayRef proxyURLs,
                                                     int keepScoped,
                                                     int ftpPassive,
                                                     CFArrayRef exceptionsList,
                                                     CFMutableArrayRef forwardList,
                                                     CFMutableArrayRef contentFilterForwardList);

void _FNProxySetOverrideSystemProxySettings(CFDictionaryRef proxyDictionary);

void _FNProxySupportUpdateProxyForwardList(CFArrayRef forwardList);
void _FNProxySupportUpdateContentFilteringForwardList(CFArrayRef forwardList);

/*
 * Data, types and functions shared between FN source files, only.
 */

/*
 * Reader-writer lock used to protect internal data structures holding
 * proxy and authentication information:
 * - 'proxyInfoArray'                  -- defined in FNProxySupport.c.
 * - 'cachedSettings'                  -- defined in FNProxySupport.c.
 * - 'attrQuery' and 'credQuery'       -- defined in FNProxySupportAuth.c.
 *
 * Writers:
 * - _FNProxySupportSetProxySettings() -- all data structures.
 * Readers:
 * - _FNProxySupportCopyProxyServers() -- 'proxyInfoArray'.
 * - CopySystemProxySettings()         -- 'cachedSettings'.
 * - DynamicStoreCopyProxies()         -- 'cachedSettings'.
 * - ItemCopyMatching()                -- 'attrQuery' and 'credQuery'.
 */

extern pthread_rwlock_t _FNProxySupportLock;


/*
 * OSX/iOS system proxy settings store configuration for five types of
 * protocols, as defined in the SchemeType type below.
 */

typedef enum SchemeType {
    SchemeTypeHTTP = 0,
    SchemeTypeHTTPS,
    SchemeTypeFTP,
    SchemeTypeSOCKS,
    SchemeTypeRTSP,
    SchemeTypeFILE,
    SchemeTypeMax,
    SchemeTypeAll
} SchemeType;


/*
 * FN implementation-private functions.
 */

CFArrayRef _FNProxySupportCopyProxyServers(void);

_FNProxySupportError _FNProxySupportCredFiltersInit(void);

_FNProxySupportError _FNProxySupportAuthInit(void);

void _FNProxySupportAuthItemReset(void);

_FNProxySupportError
_FNProxySupportAuthItemAdd(SchemeType schemeType,
                           CFStringRef hostName,
                           CFNumberRef port,
                           CFStringRef userName,
                           CFStringRef password);


extern inline _FNProxySupportError
AddProxyEntry(CFMutableDictionaryRef dict,
              SchemeType scheme,
              CFStringRef hostName,
              CFNumberRef portNumber,
              int ftpPassive);

extern CFReadStreamRef
CreateStreamsForHTTPRequest(CFAllocatorRef allooc, CFHTTPMessageRef request);

extern CFDictionaryRef
CopySystemProxySettings(void);

extern CFDictionaryRef
DynamicStoreCopyProxies(SCDynamicStoreRef store);

extern void *
proxy_xpc_dictionary_get_value(void *xdict, const char *key);

extern void
proxy_tcp_connection_start(void *a0);

extern void
proxy_tcp_connection_cancel(void *a0);

extern OSStatus
ItemAdd(CFDictionaryRef attrs,
        CFTypeRef *result);
extern OSStatus
ItemCopyMatching(CFDictionaryRef query,
                 CFTypeRef *result);
extern OSStatus
ItemDelete(CFDictionaryRef query);
extern OSStatus
ItemUpdate(CFDictionaryRef query,
           CFDictionaryRef attrs);


#endif // _FN_PROXY_SUPPORT_PRIV_H_

