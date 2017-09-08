//
//  FNProxySupport.c
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#include <CFNetwork/CFProxySupport.h>
#include <Fuji/HookManager.h>
#include "FNProxySupportPriv.h"
#include "notify.h"
#include "ProxyAuthTokenHelper.h"

#include <CFNetwork/CFHTTPStream.h>
#include <SystemConfiguration/SystemConfiguration.h>

#include <regex.h>

#ifndef kCFCoreFoundationVersionNumber_iOS_7_1
#define kCFCoreFoundationVersionNumber_iOS_7_1 847.00
#endif


#ifndef NELEM
#define NELEM(a)  (sizeof(a) / sizeof(a)[0])
#endif

int (*shouldFilterContentForRequest)(const char *,const char *);
int (*shouldProxyHandleRequest)(const char *,const char *);

#pragma mark - XPC APIs imported

typedef void * xpc_object_t;

extern char *xpc_copy_description(xpc_object_t object);

/* Functions */
HOOK_libxpc_xpc_array_create_type orig_xpc_array_create;
HOOK_libxpc_xpc_int64_create_type orig_xpc_int64_create;
HOOK_libxpc_xpc_string_create_type orig_xpc_string_create;
HOOK_libxpc_xpc_dictionary_create_type orig_xpc_dictionary_create;
HOOK_libxpc_xpc_dictionary_get_string_type orig_xpc_dictionary_get_string;
HOOK_libxpc_xpc_dictionary_get_uint64_type orig_xpc_dictionary_get_uint64;
HOOK_libxpc_xpc_dictionary_set_value_type orig_xpc_dictionary_set_value;
HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type orig_CFNetworkSetOverrideSystemProxySettings;

 
/*
 * Reader-writer lock to coordinate access to cached information.
 */

pthread_rwlock_t _FNProxySupportLock;


/*
 * OSX/iOS system proxy settings store configuration for five types of
 * protocols, as defined in the SchemeType type below.
 * Each protocol configuration is represented in the settings dictionary,
 * by a set of keys and corresponding values. Key names are prefixed with
 * a protocol name followed by the name of their values. For example, the key
 * for the HTTP proxy host name value, is "HTTPProxy". The host name and
 * port are normally considered required values. For keys of a particular
 * protocol to be considered by other CFNetwork functions, the corresponding
 * '*Enable' key must be present and its value should be non-zero.
 * The '*Enable' and '*Port' keys have CFNumber values. All other keys have
 * CFString values.
 */

typedef enum KeyType {
    KeyTypeEnable = 0,
    KeyTypeHost,
    KeyTypePort,
    KeyTypeUser,
    KeyTypePassword,
    KeyTypeMax
} KeyType;


static const void *keys[][KeyTypeMax] = {
    [SchemeTypeHTTP] = {
        CFSTR("HTTPEnable"), CFSTR("HTTPProxy"), CFSTR("HTTPPort"),
        CFSTR("HTTPUser"), CFSTR("HTTPPassword")
    },
    [SchemeTypeHTTPS] = {
        CFSTR("HTTPSEnable"), CFSTR("HTTPSProxy"), CFSTR("HTTPSPort"),
        CFSTR("HTTPSUser"), CFSTR("HTTPSPassword")
    },
    [SchemeTypeFTP] = {
        CFSTR("FTPEnable"), CFSTR("FTPProxy"), CFSTR("FTPPort"),
        CFSTR("FTPUser"), CFSTR("FTPPassword")
    },
    [SchemeTypeSOCKS] = {
        CFSTR("SOCKSEnable"), CFSTR("SOCKSProxy"), CFSTR("SOCKSPort"),
        CFSTR("SOCKSUser"), CFSTR("SOCKSPassword")
    },
    [SchemeTypeRTSP] = {
        CFSTR("RTSPEnable"), CFSTR("RTSPProxy"), CFSTR("RTSPPort"),
        CFSTR("RTSPUser"), CFSTR("RTSPPassword")
    },
    [SchemeTypeFILE] = {
        CFSTR("ProxyAutoConfigEnable"), CFSTR("ProxyAutoConfigURLString"), CFSTR(""),
        CFSTR("HTTPProxyAuthenticated"), CFSTR("HTTPProxyUsername")
    }
};


/*
 * Cache proxy host names and ports, separately, in an array where
 * host values are stored at (index * schemeType + 0) and port values
 * at (index * schemeType + 1). The size of the array is SchemeTypeMax*2.
 *
 * This layout presents lower overhead when checking whether credentials
 * refer to our proxy configuration, than using the cached dictionaries
 * (the dictionary format is preserved for lower overhead when overwriting
 *  system functions whose return values are in that format).
 */

static CFMutableArrayRef proxyInfoArray = NULL;
static CFArrayRef cachedWhiteList = NULL;
static CFMutableArrayRef cachedForwardList = NULL;
static CFMutableArrayRef cachedContentFilterForwardList = NULL;
static CFDictionaryRef cachedSettings = NULL;
static CFDictionaryRef (*copySystemProxySettings)(void) = NULL;
static CFDictionaryRef (*dynamicStoreCopyProxies)(SCDynamicStoreRef) = NULL;
static CFReadStreamRef (*createStreamForHTTPRequest)(CFAllocatorRef, CFHTTPMessageRef) = NULL;

static CFNumberRef enableValue = NULL;
static CFNumberRef __attribute__((unused)) monikerPortNumber = NULL;
static char * _proxyHostAddress = NULL;
static int64_t _proxyPort = 0;


/**
 * Adds required keys for a proxy scheme, to a proxy dictionary.
 * @param[in,out] dict dictionary to add keys to.
 * @param scheme scheme type.
 * @param hostName host name or IP address.
 * @param portNumber port number.
 * @param ftpPassive setting for passive mode FTP.
 * @return 0 if successful, < 0 otherwise.
 */

//static inline _FNProxySupportError
inline _FNProxySupportError
AddProxyEntry(CFMutableDictionaryRef dict,
              SchemeType scheme,
              CFStringRef hostName,
              CFNumberRef portNumber,
              int ftpPassive)
{
    static const CFStringRef ftpPassiveKey = CFSTR("FTPPassive");
    
    if (!dict || (scheme >= SchemeTypeMax) ||
        IsCFStringEmpty(hostName) || (!portNumber && (scheme != SchemeTypeFILE))) {
        return _kFNProxySupportErrorInvalidArguments;
    }
    
    CFDictionaryAddValue(dict, keys[scheme][KeyTypeEnable],
                         enableValue);
    CFDictionaryAddValue(dict, keys[scheme][KeyTypeHost], hostName);
    if(scheme != SchemeTypeFILE) {
        CFDictionaryAddValue(dict, keys[scheme][KeyTypePort], portNumber);
    }
    
    /*if (scheme == SchemeTypeHTTP) {
        int one = 1;
        CFNumberRef authenticated = CFNumberCreate(NULL, kCFNumberIntType, &one);
        CFDictionaryAddValue(dict,CFSTR("HTTPProxyAuthenticated"), authenticated);
        CFDictionaryAddValue(dict,CFSTR("HTTPProxyUsername"), CFSTR("user"));
    }*/
    
    if ((scheme == SchemeTypeFTP) && ftpPassive) {
        CFDictionaryAddValue(dict, ftpPassiveKey, enableValue);
    }
    
    return _kFNProxySupportErrorSuccess;
}


void _FNProxySupportUpdateProxyForwardList(CFArrayRef forwardList)
{
    if (forwardList) {
        if(cachedForwardList) {
            CFArrayAppendArray(cachedForwardList, forwardList, CFRangeMake(0, CFArrayGetCount(forwardList)));
        } else {
            cachedForwardList = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, forwardList);
        }
    } else if (cachedForwardList) {
        CFRelease(cachedForwardList);
        cachedForwardList = NULL;
    }
}

void _FNProxySupportUpdateContentFilteringForwardList(CFArrayRef forwardList)
{
    if (forwardList) {
        if(cachedContentFilterForwardList) {
            CFArrayAppendArray(cachedContentFilterForwardList, forwardList, CFRangeMake(0, CFArrayGetCount(forwardList)));
        } else {
            cachedContentFilterForwardList = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, forwardList);

        }
    } else if (cachedContentFilterForwardList){
        CFRelease(cachedContentFilterForwardList);
        cachedContentFilterForwardList = NULL;
    }
}


void _FNProxySetOverrideSystemProxySettings(CFDictionaryRef proxyDictionary)
{
    if (orig_CFNetworkSetOverrideSystemProxySettings) {
        orig_CFNetworkSetOverrideSystemProxySettings((void *)proxyDictionary);
    }
}


/**
 * Sets system proxy settings. If the list of URLs is empty, we zero out
 *    the cached settings dictionary so that CFNetworkCopySystemProxySettings()
 *    returns the actual system proxies.
 * @param proxyURLs array of CFStringRef proxy URL elements.
 * @param keepScoped flag whether to keep or not original __SCOPED__ value.
 * @param ftpPassive setting for passive mode FTP.
 * @param exceptionsList array of CFStringRef hosts excluded from proxying
 *        (this argument is optional; i.e., it may be NULL).
 * @return success or error code.
 */

_FNProxySupportError
_FNProxySupportSetProxySettings(CFArrayRef proxyURLs,
                                int keepScoped,
                                int ftpPassive,
                                CFArrayRef exceptionsList,
                                CFMutableArrayRef forwardList,
                                CFMutableArrayRef contentFilterForwardList)
{
#ifdef ENABLE_PROXY

#ifdef DEBUG // proxy settings contain secrets
    FNStringArrayLog(__FUNCTION__, proxyURLs);
#endif
    
    static const CFStringRef exceptionsListKey = CFSTR("ExceptionsList");
    static const CFStringRef forwardListKey = CFSTR("ForwardList");
    static const CFStringRef contentFilterForwardListKey = CFSTR("ContentFilteringForwardList");
    static const CFStringRef monikerHostName = CFSTR("");
    
    static const CFStringRef httpScheme = CFSTR("http");
    static const CFStringRef httpsScheme = CFSTR("https");
    static const CFStringRef ftpScheme = CFSTR("ftp");
    static const CFStringRef socksScheme = CFSTR("socks");
    static const CFStringRef rtspScheme = CFSTR("rtsp");
    static const CFStringRef fileScheme = CFSTR("file");
    
    static const CFStringRef sysSettingsPreserveKey = CFSTR("__SCOPED__");
    CFTypeRef sysSettingsPreserveValue = NULL;
    
    CFDictionaryRef sysSettings = NULL;
    CFMutableDictionaryRef settings = NULL;
    //CFDictionaryRef tmp = NULL;
    bool unset = false;
    _FNProxySupportError rc = _kFNProxySupportErrorSuccess;
    if(_proxyHostAddress) free(_proxyHostAddress);
    _proxyHostAddress = NULL;
    _proxyPort = 0;
    
    pthread_rwlock_wrlock(&_FNProxySupportLock);
    
    if (!proxyURLs || (CFArrayGetCount(proxyURLs) < 1)) {
        unset = true;
        rc = _kFNProxySupportErrorInvalidArguments;
        goto out;
    }
    
    /*
     * Get the original proxy settings and create a copy that may need to
     * preserve the __SCOPED__ value.
     */
    
    sysSettings = copySystemProxySettings();
    if (!sysSettings) {
        rc = _kFNProxySupportErrorInternal;
        goto out;
    }
    
    settings =
    CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, sysSettings);
    if (!settings) {
        rc = _kFNProxySupportErrorOutOfMemory;
        goto out;
    }
    
    ReleaseIfNotNULL(proxyInfoArray);
    proxyInfoArray = CFArrayCreateMutable(kCFAllocatorDefault,
                                          (SchemeTypeMax * 2),
                                          &kCFTypeArrayCallBacks);
    if (!proxyInfoArray) {
        rc = _kFNProxySupportErrorOutOfMemory;
        goto out;
    }
    
    /*
     * Compensate for lack of functionality in CFArray: the array is zero-sized
     * after creation so we must explicitly grow it with dummy values up to the
     * specified capacity.
     */
    
    for (int i = 0; i < (SchemeTypeMax * 2); i += 2) {
        CFArrayAppendValue(proxyInfoArray, monikerHostName);
        CFArrayAppendValue(proxyInfoArray, monikerPortNumber);
    }
    
    /*
     * Remove everything, but add the original __SCOPED__ value,
     * if the argument requires it.
     */
    
    CFDictionaryRemoveAllValues(settings);
    if (keepScoped) {
        if (CFDictionaryGetValueIfPresent(sysSettings,
                                          sysSettingsPreserveKey,
                                          &sysSettingsPreserveValue)) {
            CFDictionaryAddValue(settings, sysSettingsPreserveKey,
                                 sysSettingsPreserveValue);
        }
    }
    
    /* Prepare proxy credential data structures and proxy info array. */
    
    _FNProxySupportAuthItemReset();
    
    for (int i = 0;
         (rc == _kFNProxySupportErrorSuccess) &&
         (i < CFArrayGetCount(proxyURLs));
         i++) {
        CFURLRef proxyURL;
        CFStringRef scheme;
        CFStringRef hostName;
        SInt64 port;
        CFNumberRef portNumber;
        CFStringRef userName;
        CFStringRef password;
        SchemeType schemeType = SchemeTypeMax;
        
        proxyURL = CFArrayGetValueAtIndex(proxyURLs, i);
        if ((proxyURL == NULL) ||
            ((proxyURL = CFURLCreateWithString(kCFAllocatorDefault,
                                               (CFStringRef)proxyURL,
                                               NULL)) == NULL)) {
            rc = _kFNProxySupportErrorInvalidArguments;
            break;
        }
        
        scheme = CFURLCopyScheme(proxyURL);
        if (IsCFStringEmpty(scheme)) {
            ReleaseIfNotNULL(proxyURL);
            ReleaseIfNotNULL(scheme);
            rc = _kFNProxySupportErrorInvalidArguments;
            break;
        }
        
        port = CFURLGetPortNumber(proxyURL);
        portNumber =
        CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &port);
        if ((CFStringCompare(fileScheme, scheme, kCFCompareCaseInsensitive)
             != kCFCompareEqualTo) && ((port < 0) || !portNumber)) {
            ReleaseIfNotNULL(proxyURL);
            ReleaseIfNotNULL(scheme);
            ReleaseIfNotNULL(portNumber);
            rc = _kFNProxySupportErrorInvalidArguments;
            break;
        }
        
        hostName = CFURLCopyHostName(proxyURL);
        userName = CFURLCopyUserName(proxyURL);
        password = CFURLCopyPassword(proxyURL);
        
        CFIndex length = CFStringGetLength(hostName);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length,
                                          kCFStringEncodingUTF8);
        
        if(_proxyHostAddress) free(_proxyHostAddress);
        _proxyHostAddress = (char *)malloc(maxSize);
        BOOL didGetCStringOfHostAddress = false;
        if (_proxyHostAddress != NULL) {
            didGetCStringOfHostAddress = CFStringGetCString(hostName,
                                                            _proxyHostAddress,
                                                            maxSize,
                                                            kCFStringEncodingUTF8);
        }
        if (didGetCStringOfHostAddress == false) {
            ReleaseIfNotNULL(proxyURL);
            ReleaseIfNotNULL(scheme);
            ReleaseIfNotNULL(portNumber);
            ReleaseIfNotNULL(hostName);
            ReleaseIfNotNULL(userName);
            ReleaseIfNotNULL(password);
            if(_proxyHostAddress) free(_proxyHostAddress);
            rc = _kFNProxySupportErrorOutOfMemory;
            break;
        }
        
        _proxyPort = (int64_t)CFURLGetPortNumber(proxyURL);
        
        if (CFStringCompare(httpScheme, scheme, kCFCompareCaseInsensitive)
            == kCFCompareEqualTo) {
            schemeType = SchemeTypeHTTP;
        } else if (CFStringCompare(httpsScheme, scheme, kCFCompareCaseInsensitive)
                   == kCFCompareEqualTo) {
            schemeType = SchemeTypeHTTPS;
        } else if (CFStringCompare(ftpScheme, scheme, kCFCompareCaseInsensitive)
                   == kCFCompareEqualTo) {
            schemeType = SchemeTypeFTP;
        } else if (CFStringCompare(socksScheme, scheme, kCFCompareCaseInsensitive)
                   == kCFCompareEqualTo) {
            schemeType = SchemeTypeSOCKS;
        } else if (CFStringCompare(rtspScheme, scheme, kCFCompareCaseInsensitive)
                   == kCFCompareEqualTo) {
            schemeType = SchemeTypeRTSP;
        }  else if (CFStringCompare(fileScheme, scheme, kCFCompareCaseInsensitive)
                    == kCFCompareEqualTo) {
            ReleaseIfNotNULL(hostName);
            hostName = CFURLGetString(proxyURL);
            schemeType = SchemeTypeFILE;
        }
        
        rc = AddProxyEntry(settings, schemeType,
                           hostName, portNumber, ftpPassive);
        if (rc == _kFNProxySupportErrorSuccess) {
            /* Set the host and port values for the scheme in proxyInfoArray. */
            
            CFArraySetValueAtIndex(proxyInfoArray, schemeType * 2 + 0, hostName);
            CFArraySetValueAtIndex(proxyInfoArray, schemeType * 2 + 1, portNumber);
            
            /* Add proxy credential security items related to 'schemeType'. */
            
            if(schemeType != SchemeTypeFILE)
            {
                rc = _FNProxySupportAuthItemAdd(schemeType, hostName, portNumber,
                                            userName, password);
            }
        }
        
        ReleaseIfNotNULL(proxyURL);
        ReleaseIfNotNULL(scheme);
        ReleaseIfNotNULL(portNumber);
        ReleaseIfNotNULL(hostName);
        ReleaseIfNotNULL(userName);
        ReleaseIfNotNULL(password);
    }
    
    if (exceptionsList) {
        CFDictionaryAddValue(settings, exceptionsListKey, exceptionsList);
        cachedWhiteList = CFArrayCreateCopy(kCFAllocatorDefault, exceptionsList);
    }else if (cachedWhiteList != NULL){
        CFRelease(cachedWhiteList);
   }
    
    if (forwardList) {
        CFDictionaryAddValue(settings, forwardListKey, forwardList);
        cachedForwardList = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, forwardList);
    } else if (cachedForwardList != NULL) {
        CFRelease(cachedForwardList);
    }
    
    if (contentFilterForwardList) {
        CFDictionaryAddValue(settings, contentFilterForwardListKey, contentFilterForwardList);
        cachedContentFilterForwardList = CFArrayCreateMutableCopy(kCFAllocatorDefault, 0, contentFilterForwardList);
    } else if (cachedContentFilterForwardList != NULL) {
        CFRelease(cachedContentFilterForwardList);
    }
    
    /*
     * If successful, make the dictionary immutable, assign the 'cached'
     * variable.
     * Clean up, release remaining objects.
     */
    
out:
    //tmp = cachedSettings;
    if (rc == _kFNProxySupportErrorSuccess) {
        cachedSettings = CFDictionaryCreateCopy(kCFAllocatorDefault, settings);
    } else {
        _FNProxySupportAuthItemReset();
        ReleaseIfNotNULL(proxyInfoArray);
        proxyInfoArray = NULL;
        ReleaseIfNotNULL(cachedSettings);
        cachedSettings = NULL;
        if (unset) {
            /*
             * If the array of proxy URLs was NULL, this is the intended behavior.
             */
            
            rc = _kFNProxySupportErrorSuccess;
        }
    }
    //ReleaseIfNotNULL(tmp);
    ReleaseIfNotNULL(settings);
    ReleaseIfNotNULL(sysSettings);
    
    pthread_rwlock_unlock(&_FNProxySupportLock);
    
    /*
     * Notify the CFNetwork layer that the network configuration has changed
     * and that it needs to flush any cached configuration that it has.
     */
    notify_post("com.apple.system.config.network_change");
    
    return rc;
    
#else
    //Proxy not enabled
    return _kFNProxySupportErrorSuccess;
#endif
}


//static CFReadStreamRef
CFReadStreamRef
CreateStreamsForHTTPRequest(CFAllocatorRef allooc, CFHTTPMessageRef request)
{
    CFReadStreamRef readStream = NULL;
    if (createStreamForHTTPRequest) {
        readStream = createStreamForHTTPRequest(allooc, request);
        CFDictionaryRef proxySettings= CFNetworkCopySystemProxySettings();
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        CFReadStreamSetProperty(readStream, kCFStreamPropertyHTTPProxy, proxySettings);
#warning "FIXME: 💡Using deprecated stuff... Needed A fix. 🔧"
#pragma GCC diagnostic pop
        
        CFRelease(proxySettings);
    }

    return readStream;
}

/**
 * Retrieves system proxy settings; CFNetwork API hook.
 * @return proxy settings CF dictionary, or NULL on failure.
 */

//static CFDictionaryRef
CFDictionaryRef
CopySystemProxySettings(void)
{
    CFDictionaryRef result;
    
    pthread_rwlock_rdlock(&_FNProxySupportLock);
    
    if (!cachedSettings) {
        /*
         * If _FNProxySupportSetProxySettings() hasn't been called yet, or it
         * zeroed out 'cached', chain to the original function to return the
         * actual system proxy settings.
         */
        
        result = copySystemProxySettings();
    } else {
        result = CFRetain(cachedSettings);
    }
    
    pthread_rwlock_unlock(&_FNProxySupportLock);
    return result;
}


/**
 * Retrieves system proxy settings; SystemConfiguration API hook.
 *    This additional hook is installed, such that, in the event the 'normal'
 *    CF hook is missed, this one is (for now, at least) hit. This happens
 *    because the current original CF implementation calls this SC function.
 *    This is a workaround for a wrapping limitation; see FUJI-104 for details.
 * @param store opaque, passed to actual implementation.
 * @return proxy settings CF dictionary, or NULL on failure.
 */

//static CFDictionaryRef
CFDictionaryRef
DynamicStoreCopyProxies(SCDynamicStoreRef store)
{
    CFDictionaryRef result;
    
    pthread_rwlock_rdlock(&_FNProxySupportLock);
    
    if (!cachedSettings) {
        result = dynamicStoreCopyProxies(store);
    } else {
        result = CFRetain(cachedSettings);
    }
    
    pthread_rwlock_unlock(&_FNProxySupportLock);
    return result;
}


/**
 * Returns a copy of the proxy server host and port information array.
 * @return proxy information array or NULL.
 */

CFArrayRef
_FNProxySupportCopyProxyServers(void)
{
    CFArrayRef result = NULL;
    
    pthread_rwlock_rdlock(&_FNProxySupportLock);
    
    if (proxyInfoArray && (CFArrayGetCount(proxyInfoArray) > 0)) {
        result = CFRetain(proxyInfoArray);
    }
    
    pthread_rwlock_unlock(&_FNProxySupportLock);
    return result;
}



/*****************************************/

#pragma mark - Create a proxy configuration

#define NUM_PROXY_ITEMS 5

typedef enum {
    proxy_type_direct = 1,
    proxy_type_http = 2001,
    proxy_type_https = 2002,
    //  2001 == HTTP Proxy
    //  2002 ?
    //  3001 ?   transparent
    //  3002 == socks5 transparent
    //  1 == direct
} proxy_type_t;


/**
 * Generate the necessary proxy configuration data structure used by the tcp_connection_* layer.
 */
static xpc_object_t
get_proxy_config(proxy_type_t type, const char *host, uint16_t port,
                 const char *username, const char *password)
{
    const char *keys[NUM_PROXY_ITEMS];
    xpc_object_t values[NUM_PROXY_ITEMS];
    int cnt = 0;
    
    // sanity checks
    assert(type != 0);
    assert(host != NULL);
    assert(port > 0);
    
    // must always have type
    keys[cnt] = "proxy_type";
    values[cnt] = orig_xpc_int64_create(type);
    cnt++;
    
    // must always have host
    keys[cnt] = "proxy_host";
    values[cnt] = orig_xpc_string_create(host);
    cnt++;
    
    // must always have port
    keys[cnt] = "proxy_port";
    values[cnt] = orig_xpc_int64_create(htons(port));
    cnt++;
    
    // username is optional
    if (username) {
        keys[cnt] = "proxy_user";
        values[cnt] = orig_xpc_string_create(username);
        cnt++;
    }
    
    // password is optional
    if (password) {
        assert(username != NULL);
        keys[cnt] = "proxy_password";
        values[cnt] = orig_xpc_string_create(password);
        cnt++;
    }
    
    // create a dictionary out of these settings
    xpc_object_t xdict = orig_xpc_dictionary_create(keys, values, cnt);
    
    // only support a single proxy
    
    xpc_object_t xarray = orig_xpc_array_create(&xdict, 1);
    
    return xarray;
}


#pragma mark - libsystem_network APIs interfaces


typedef struct OS_network_proxy OS_network_proxy;
typedef struct OS_tcp_connection OS_tcp_connection;
typedef struct OS_tcp_connection_destination OS_tcp_connection_destination;

#ifdef __LP64__

struct OS_tcp_connection
{
    uint8_t OS_object_opaque[4];
    uint32_t data0;
    uint32_t data1;
    xpc_object_t config_xdict;
    uint32_t data3;
    uint64_t data4;
    uint64_t data5;
    uint64_t data6;
    uint64_t data7;
    uint64_t data8;
    uint64_t tls_session_id;
    uint64_t data10;
    void *data11;
    void *host_dnssec;
    OS_tcp_connection_destination *destination;
    uint32_t client_queue;
    void *data15;
    void *event_handler;
    void *data17;
    uint32_t queue;
    uint64_t data19;
    uint64_t data20;
    uint64_t data21;
    uint64_t data22;
    uint64_t data23;
    uint64_t data24;
    uint64_t data25;
    uint64_t data26;
    uint64_t data27;
    uint64_t data28;
    uint64_t data29;
    uint32_t data30;
    uint32_t data31;
    OS_network_proxy *network_proxy;
    uint32_t bonjour_list;
    uint32_t hosts;
    OS_tcp_connection_destination *destination_list0;
    OS_tcp_connection_destination *destination_inbound;
    uint32_t messages;
    uint32_t data38;
    xpc_object_t reach_xdict;           // contains proxy configuration
    xpc_object_t proxies_xarray;        // currently set proxies
    uint32_t data41;
    uint32_t mask;
    uint64_t connection_id;
    uint64_t start_mach_time;
    uint32_t data47;
    uint32_t data48;
    uint32_t last_error;
    uint32_t data50;
    uint8_t state;
    uint8_t data51b;
    uint8_t data51c;
    uint8_t data51d;
    uint64_t data52;
    uint32_t keepalivecnt;
    uint32_t data55;
    uint32_t data56;
    uint32_t read_timeout;
    uint32_t write_timeout;
    uint32_t data59;
    uint32_t data60;
    uint32_t data61;
    uint32_t data62;
};

#else

struct OS_tcp_connection
{
    uint8_t OS_object_opaque[4];
    uint32_t data0;
    uint32_t data1;
    xpc_object_t config_xdict;
    uint32_t data3;
    uint32_t data4;
    uint32_t data5;
    uint32_t data6;
    uint32_t data7;
    uint32_t data8;
    uint32_t tls_session_id;
    uint32_t data10;
    void *data11;
    void *host_dnssec;
    OS_tcp_connection_destination *destination;
    uint32_t client_queue;
    void *data15;
    void *event_handler;
    void *data17;
    uint32_t queue;
    uint32_t data19;
    uint32_t data20;
    uint32_t data21;
    uint32_t data22;
    uint32_t data23;
    uint32_t data24;
    uint32_t data25;
    uint32_t data26;
    uint32_t data27;
    uint32_t data28;
    uint32_t data29;
    uint32_t data30;
    uint32_t data31;
    OS_network_proxy *network_proxy;
    uint32_t bonjour_list;
    uint32_t hosts;
    OS_tcp_connection_destination *destination_list0;
    OS_tcp_connection_destination *destination_inbound;
    uint32_t messages;
    uint32_t data38;
    xpc_object_t reach_xdict;           // contains proxy configuration
    xpc_object_t proxies_xarray;        // currently set proxies
    uint32_t data41;
    uint32_t mask;
    uint64_t connection_id;
    uint64_t start_mach_time;
    uint32_t data47;
    uint32_t data48;
    uint32_t last_error;
    uint32_t data50;
    uint8_t state;
    uint8_t data51b;
    uint8_t data51c;
    uint8_t data51d;
    uint64_t data52;
    uint32_t keepalivecnt;
    uint32_t data55;
    uint32_t data56;
    uint32_t read_timeout;
    uint32_t write_timeout;
    uint32_t data59;
    uint32_t data60;
    uint32_t data61;
    uint32_t data62;
};

#endif

/**
 * Sets "custom proxies" which are implemented by the layer(s) above tcp_connection and
 * so this setting effectively disables proxy support in the tcp_connection layer
 */
extern void tcp_connection_set_proxies(OS_tcp_connection *connection, xpc_object_t xdict);

/**
 * Just enables a couple prints
 */
extern void tcp_connection_set_debug_reachability(OS_tcp_connection *connection, bool enabled);


#pragma mark - Function hook implementations


/**
 * List of connection id's that should be proxied
 */
static uint64_t proxiable_endpoints[64];
static proxy_type_t proxiable_endpoint_type[64];


/**
 * Intercept the reachability replies from networkd to the application and inject
 * the proxy connection.
 */
//static void *
void *
proxy_xpc_dictionary_get_value(void *xdict, const char *key)
{
    // call original implementation
    HOOK_libxpc_xpc_dictionary_get_value_type orig_xpc_dictionary_get_value =
    (HOOK_libxpc_xpc_dictionary_get_value_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_dictionary_get_value);
    xpc_object_t value = orig_xpc_dictionary_get_value(xdict, key);
    
    // intercept the dispatch of reachability information being returned from networkd
    if (value && strcmp(key, "reachability") == 0) {
        
        // check for the existance of an endpoint_id to remove some false positives
        uint64_t endpoint_id = orig_xpc_dictionary_get_uint64(xdict, "endpoint_id");
        if (endpoint_id) {
#if 0
            printf("xpc_dictionary_get_value(%p, %s) %s\n", xdict, key, xpc_copy_description(xdict));
#endif
            // check that the endpoint_id is proxiable
            bool should_proxy = false;
            proxy_type_t proxy_type = proxy_type_direct;
            for (int i = 0; i < NELEM(proxiable_endpoints); i++) {
                if (proxiable_endpoints[i] == endpoint_id) {
                    should_proxy = true;
                    proxy_type = proxiable_endpoint_type[i];
                    break;
                }
            }
            
            if (should_proxy && _proxyHostAddress && _proxyPort) {
                // add proxy information
                value = orig_xpc_dictionary_get_value(xdict, key);
                orig_xpc_dictionary_set_value(value, "proxies",
                                          get_proxy_config(proxy_type, _proxyHostAddress, _proxyPort, NULL, NULL));
            }
        }
    }
    
    // Call the original function
    return value;
}

void set_content_filter_function(void * callback)
{
    shouldFilterContentForRequest = callback;
}


void set_proxy_handler_function(void * callback)
{
    shouldProxyHandleRequest = callback;
}

static int
should_proxy_host_url(const char *hostname, const char *url)
{
    int doesHostMatch = 0;
    CFIndex whiteListCount = CFArrayGetCount(cachedWhiteList);;
    
    
    /* First check if host is in white list if so return */
    for (int w = 0; w < whiteListCount; w++)
    {
        if (hostname)
        {
             CFStringRef wHost = CFArrayGetValueAtIndex(cachedWhiteList, w);
            
            /* First two entries are always device services url and proxy */
            CFStringRef host = CFStringCreateWithCString(kCFAllocatorDefault, hostname, kCFStringEncodingUTF8);
            
            if((NULL != wHost) && CFStringCompare(wHost, host, kCFCompareCaseInsensitive) == kCFCompareEqualTo)
            {
                CFRelease(host);
                return 0;
            }
            
            CFRelease(host);
            continue;
        }
    }
    
    
    /* If we got this far then we need to check the forward list */
    if(shouldProxyHandleRequest) {
        doesHostMatch = shouldProxyHandleRequest(url, hostname);
    }
    
    /* Now lets check the content filter forward list */
    if (!doesHostMatch && shouldFilterContentForRequest) {
        doesHostMatch = shouldFilterContentForRequest(url, hostname);
    }
    
    return doesHostMatch;
}


/**
 * Examine new connections to see if they should be proxied
 */
//static void
void
proxy_tcp_connection_start(void *a0)
{
    OS_tcp_connection *connection = a0;
    
#if 0
    printf("proxy_tcp_connection_start(%p)\n", a0);
    printf("config_xdict = %s\n", xpc_copy_description(connection->config_xdict));
    if (connection->reach_xdict) {
        printf("reachability_xdict = %s\n", xpc_copy_description(connection->reach_xdict));
    } else {
        printf("reachability_xdict = NULL\n");
    }
#endif
    
    if (connection->config_xdict) {
        
    // where is this connection going?
    const char *hostname = orig_xpc_dictionary_get_string(connection->config_xdict, "hostname");
    const char *url = orig_xpc_dictionary_get_string(connection->config_xdict, "url");

    uint64_t connection_id = connection->connection_id;
    
    // check if hostname should be proxied
    printf("hostname = %s, connection id = %llu\n", hostname, connection_id);
    
    if (should_proxy_host_url(hostname, url) && _proxyHostAddress && _proxyPort) {
        // save connection id as proxiable
        for (int i = 0; i < NELEM(proxiable_endpoints); i++) {
            if (proxiable_endpoints[i] == 0) {
                proxiable_endpoints[i] = connection_id;
                proxiable_endpoint_type[i] = proxy_type_http;
                
                //const char *url = orig_xpc_dictionary_get_string(connection->config_xdict, "url");
                if ( (NULL != url) &&
                    (strlen(url) >= 5) &&
                    (strncasecmp(url, "https", 5) == 0)) {
                        proxiable_endpoint_type[i] = proxy_type_https;
                    }
                
                break;
            }
        }
    }
    }
    
    // Call the original function
    HOOK_libsystem_network_tcp_connection_start_type orig_tcp_connection_start =
    (HOOK_libsystem_network_tcp_connection_start_type)HookMgr_GetOrigFunction(HOOK_libsystem_network_tcp_connection_start);
    orig_tcp_connection_start(a0);
}


/**
 * Remove the connection from the proxied connection table
 */
//static void
void
proxy_tcp_connection_cancel(void *a0)
{
    OS_tcp_connection *connection = a0;
    
    // free slot if present
    for (int i = 0; i < NELEM(proxiable_endpoints); i++) {
        if (proxiable_endpoints[i] == connection->connection_id) {
            proxiable_endpoints[i] = 0;
            break;
        }
    }
    
    // Call the original function
    HOOK_libsystem_network_tcp_connection_cancel_type orig_tcp_connection_cancel =
    (HOOK_libsystem_network_tcp_connection_cancel_type)HookMgr_GetOrigFunction(HOOK_libsystem_network_tcp_connection_cancel);
    orig_tcp_connection_cancel(a0);
}
#pragma mark Init

/**
 * One-time initialization function.
 * Failure is fatal and translates to the wrapped application being killed.
 */

void
_FNProxySupportInit(void)
{
#ifdef ENABLE_PROXY
    static pthread_rwlockattr_t lockAttr;
    static const SInt32 enable = 1;
    static const SInt64 monikerPort = 1;
    
    if (enableValue) {
        /* Already initialized. */
        
        return;
    }
    
    if (pthread_rwlockattr_init(&lockAttr) ||
        pthread_rwlock_init(&_FNProxySupportLock, &lockAttr)) {
        goto initErr;
    }
    
    if (_FNProxySupportAuthInit() != _kFNProxySupportErrorSuccess) {
        goto initErr;
    }
    
    if (_FNProxySupportCredFiltersInit() != _kFNProxySupportErrorSuccess) {
        goto initErr;
    }
    
    /*
     * It seems the value for '*Enabled' keys is SInt32, so don't use
     * the built-in Infinity constants.
     */
    
    enableValue =
    CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &enable);
    if (!enableValue) {
        goto initErr;
    }
    
    monikerPortNumber =
    CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt64Type, &monikerPort);
    if (!monikerPortNumber) {
        goto initErr;
    }
    
    copySystemProxySettings =
    HookMgr_GetOrigFunction(HOOK_CFNetwork_CFNetworkCopySystemProxySettings);
    if (!copySystemProxySettings) {
        goto initErr;
    }
    if (HookMgr_Register(CopySystemProxySettings,
                         HOOK_CFNetwork_CFNetworkCopySystemProxySettings)) {
        goto initErr;
    }
    
    dynamicStoreCopyProxies =
    HookMgr_GetOrigFunction(HOOK_SystemConfiguration_SCDynamicStoreCopyProxies);
    if (!dynamicStoreCopyProxies) {
        goto initErrUnregister;
    }
    if (HookMgr_Register(DynamicStoreCopyProxies,
                         HOOK_SystemConfiguration_SCDynamicStoreCopyProxies)) {
        goto initErrUnregister;
    }
    
    
    //TODO: IF iOS 9
    createStreamForHTTPRequest =
    HookMgr_GetOrigFunction(HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest);
    if (!createStreamForHTTPRequest) {
        goto initErrUnregister;
    }
    if (HookMgr_Register(CreateStreamsForHTTPRequest,
                         HOOK_CFNetwork_CFReadStreamCreateForHTTPRequest)) {
        goto initErrUnregister;
    }
    
    
    //initialize token generator
    initTokenGenerator();
    
    int ourVersionNumber = (int) floor(kCFCoreFoundationVersionNumber);
    int iOS7VersionNumber = (int) floor(kCFCoreFoundationVersionNumber_iOS_7_1);
    if (ourVersionNumber > iOS7VersionNumber) {
        // start clean
        memset(proxiable_endpoints, 0, sizeof(proxiable_endpoints));
    
        // install hooks
        HookMgr_Register(proxy_tcp_connection_start,
                         HOOK_libsystem_network_tcp_connection_start);
        HookMgr_Register(proxy_tcp_connection_cancel,
                         HOOK_libsystem_network_tcp_connection_cancel);
        HookMgr_Register(proxy_xpc_dictionary_get_value,
                         HOOK_libxpc_xpc_dictionary_get_value);
        
        //Get original function pointers
        orig_xpc_array_create = (HOOK_libxpc_xpc_array_create_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_array_create);
        orig_xpc_int64_create = (HOOK_libxpc_xpc_int64_create_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_int64_create);
        orig_xpc_string_create = (HOOK_libxpc_xpc_string_create_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_string_create);
        orig_xpc_dictionary_create = (HOOK_libxpc_xpc_dictionary_create_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_dictionary_create);
        orig_xpc_dictionary_get_string = (HOOK_libxpc_xpc_dictionary_get_string_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_dictionary_get_string);
        orig_xpc_dictionary_get_uint64 = (HOOK_libxpc_xpc_dictionary_get_uint64_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_dictionary_get_uint64);
        orig_xpc_dictionary_set_value = (HOOK_libxpc_xpc_dictionary_set_value_type)HookMgr_GetOrigFunction(HOOK_libxpc_xpc_dictionary_set_value);
        orig_CFNetworkSetOverrideSystemProxySettings = (HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings_type)HookMgr_GetOrigFunction(HOOK_CFNetwork__CFNetworkSetOverrideSystemProxySettings);
        
    }
    return;
    
initErrUnregister:
    HookMgr_UnRegister(HOOK_CFNetwork_CFNetworkCopySystemProxySettings);
    
initErr:
    ReleaseIfNotNULL(enableValue);
    enableValue = NULL;
    ReleaseIfNotNULL(monikerPortNumber);
    monikerPortNumber = NULL;
    copySystemProxySettings = NULL;
    dynamicStoreCopyProxies = NULL;
    CFLog(CFSTR("FATAL: Proxy support interceptors could not be installed."));
    //TODO:CHECK FNHalt();
    
#else
    return;
#endif
}




