//
//  FNInet.c
//
//  Copyright (c) 2012-2013 VMware, Inc. All rights reserved.
//

#include <SystemConfiguration/SCNetworkReachability.h>
#include <resolv.h>
#include "FNInetPriv.h"


/*
 * Cached DNS and white lists and corresponding reader-writer locks.
 */

static FNInetAddress *dnsList;
static pthread_rwlock_t dnsListLock;

static bool whiteListDisabled;
static FNInetAddress *whiteList;
static pthread_rwlock_t whiteListLock;

static CFArrayRef policyHostList;
static pthread_rwlock_t policyHostListLock;

SCNetworkReachabilityRef inet4Reachability;
SCNetworkReachabilityRef inet6Reachability;


typedef struct ListIsEqualArgType {
    int family;
    void *addr;
} ListIsEqualArgType;


/**
 * Deallocator callback for FNInetAddress lists.
 * @param[in,out] arg an FNInetAddress element.
 * @param cbData callback data.
 * @return 0
 */

static int
ListDeallocCB(FNList *arg,
              void *cbData)
{
    (void)cbData;
    free(arg);
    return 0;
}


/**
 * Equality predicate callback for FNInetAddress lists.
 * @param arg an FNInetAddres element.
 * @param cbData callback data of type 'struct in[6]_addr *'.
 * @return 0 if the element does not match the address, != 0 otherwise.
 */

static int
ListIsEqualCB(FNList *arg,
              void *cbData)
{
    FNInetAddress *inetAddress = (FNInetAddress *)arg;
    ListIsEqualArgType *cbArg = cbData;
    
    if (!cbArg || (inetAddress->family != cbArg->family)) {
        return 0;
    }
    
    if (cbArg->family == AF_INET) {
        return (inetAddress->u.in4.s_addr ==
                ((struct in_addr *)(cbArg->addr))->s_addr);
    } else { // AF_INET6
        return !memcmp(&(inetAddress->u.in6), cbArg->addr,
                       sizeof inetAddress->u.in6);
    }
}


/**
 * Log callback for FNInetAddress lists.
 * @param arg an FNInetAddres element.
 * @param cbData callback data of type 'const char *'.
 * @return 0.
 */

/*
 * ListLogCB is not used
 *
static int
ListLogCB(FNList *arg,
          void *cbData)
{
    FNInetAddress *inetAddr = (FNInetAddress *)arg;
    const char *label = cbData;
    
    FNInetAddressLog(label, inetAddr);
    return 0;
}
 
 */


#if defined(FN_INET_LOG)

/**
 * Logs entries in a list to 'stderr'.
 * @param label text preceeding each list entry.
 * @param list an FNInetAddres list.
 */

void
FNInetAddressListLog(const char *label,
                     FNInetAddress *list)
{
    if (list) {
        (void)FNListApply(&list->listHead, ListLogCB, (void *)label);
    }
}

#endif


/**
 * Refreshes the list of DNS servers and caches it in 'dnsList'.
 * @return number of DNS servers if successful, < 0 otherwise.
 */

static int
BuildDNSList(void)
{
    int rc;
    struct __res_state state;
    union res_sockaddr_union dnsServers[MAXNS];
    FNInetAddress *current = NULL;
    
    memset(&state, 0, sizeof state);
    rc = res_ninit(&state);
    if (rc) {
        return (rc > 0 ? -1 : rc);
    }
    
    rc = res_getservers(&state, dnsServers, MAXNS);
    if (rc > 0) {
        FNInetAddress *elem;
        int dnsServersSize = rc;
        
        rc = 0;
        for (int i = 0; i < dnsServersSize; i++) {
            elem = malloc(sizeof *elem);
            if (!elem) {
                rc = -1;
                break;
            }
            
            FNInetAddressInit(elem);
            if (dnsServers[i].sin.sin_family == AF_INET) {
                FNInetAddressSet(elem, AF_INET, &dnsServers[i].sin.sin_addr);
            } else if (dnsServers[i].sin.sin_family == AF_INET6) {
                FNInetAddressSet(elem, AF_INET6, &dnsServers[i].sin6.sin6_addr);
            } else {
                free(elem);
                continue;
            }
            
            if (FNInetAddressListAppendUnique(current, elem)) {
                free(elem);
                continue;
            }
            
            current = elem;
            rc++;
        }
    }
    res_ndestroy(&state);
    
    if (rc > 0) {
        FNInetAddress *old;
        
        ASSERT(current);
        pthread_rwlock_wrlock(&dnsListLock);
        old = dnsList;
        dnsList = (FNInetAddress *)(current->listHead.next);
        FNInetAddressListLog("New DNS entry", dnsList);
        pthread_rwlock_unlock(&dnsListLock);
        if (old && OSAtomicDecrement32(&old->refCount) == 0) {
            FNListDeallocate(&old->listHead, ListDeallocCB, NULL);
        }
    } else {
        if (current) {
            FNListDeallocate(&current->listHead, ListDeallocCB, NULL);
        }
    }
    
    return rc;
}


/**
 * Safely retrieves the DNS list, incrementing its reference count. A DNS
 *    list retrieved in this manner, must be put back (see below).
 * @return DNS list or NULL.
 */

FNInetAddress *
FNInetGetDNSList(void)
{
    FNInetAddress *res;
    
    pthread_rwlock_rdlock(&dnsListLock);
    res = dnsList;
    if (res) {
        OSAtomicIncrement32(&res->refCount);
    }
    pthread_rwlock_unlock(&dnsListLock);
    return res;
}


/**
 * Puts back a previously retrieved  DNS list, decrementing its reference
 *    count; the list is deallocated when the reference count drops to zero.
 * @param[in,out] dnsListArg previously retrieved DNS list.
 */

void
FNInetPutDNSList(FNInetAddress *dnsListArg)
{
    if (dnsListArg && OSAtomicDecrement32(&dnsListArg->refCount) == 0) {
        FNListDeallocate(&dnsListArg->listHead, ListDeallocCB, NULL);
    }
}


/**
 * Resolves a host name and appends its addresses to the list argument.
 * @param hostName host name string.
 * @param[in,out] current current position in list.
 * @return number of resolved addresses if successful, < 0 otherwise.
 */

static inline int
HostNameResolve(const char *hostName,
                FNInetAddress **current)
{
    int rc;
    FNInetAddress *elem;
    struct addrinfo *entries;
    struct addrinfo *entry;
    
    ASSERT(hostName && current);
    
    entries = NULL;
    rc = getaddrinfo(hostName, NULL, NULL, &entries);
    if (rc) {
        return -1;
    }
    
    for (entry = entries; entry; entry = entry->ai_next) {
        if ((entry->ai_family != AF_INET) && (entry->ai_family != AF_INET6)) {
            continue;
        }
        
        elem = malloc(sizeof *elem);
        if (!elem) {
            /* Attempt best effort rather than just fail. */
            
            continue;
        }
        
        FNInetAddressInit(elem);
        if (entry->ai_family == AF_INET) {
            FNInetAddressSet(elem, entry->ai_family,
                             &((struct sockaddr_in *)entry->ai_addr)->sin_addr);
        } else { // AF_INET6
            FNInetAddressSet(elem, entry->ai_family,
                             &((struct sockaddr_in6 *)entry->ai_addr)->sin6_addr);
        }
        
        if (FNInetAddressListAppendUnique(*current, elem)) {
            free(elem);
            continue;
        }
        
        *current = elem;
        rc++;
    }
    
    return rc;
}


/**
 * Refreshes the list of specified host names or IP addresses, and caches
 *    all corresponding addresses in 'whiteList'.
 * @param hostListArg array of CFStringRef-s containing host names or addresses.
 * @return NULL;
 */

static void *
DoBuildWhiteList(void *hostListArg)
{
    char hostListElemStr[FN_HOST_NAME_LEN_MAX];
    CFIndex hostListSize;
    CFArrayRef hostList = hostListArg;
    int listSize = 0;
    FNInetAddress *old;
    FNInetAddress *current = NULL;
    
    if (!hostList) {
        pthread_rwlock_wrlock(&whiteListLock);
        whiteListDisabled = false;
        old = whiteList;
        whiteList = NULL;
        pthread_rwlock_unlock(&whiteListLock);
        if (old && OSAtomicDecrement32(&old->refCount) == 0) {
            FNInetAddressListLog("Deleted white list entry", old);
            FNListDeallocate(&old->listHead, ListDeallocCB, NULL);
        }
        
        return NULL;
    }
    
    hostListSize = CFArrayGetCount(hostList);
    listSize = 0;
    for (int i = 0; i < hostListSize; i++) {
        CFStringRef hostListElem;
        const char *hostListElemPtr;
        FNInetAddress *elem;
        
        hostListElem = CFArrayGetValueAtIndex(hostList, i);
        if (!hostListElem) {
            continue;
        }
        
        hostListElemPtr =
        CFStringGetCStringPtr(hostListElem, kCFStringEncodingUTF8);
        if (!hostListElemPtr) {
            if (!CFStringGetCString(hostListElem, hostListElemStr,
                                    sizeof hostListElemStr,
                                    kCFStringEncodingUTF8)) {
                continue;
            }
            hostListElemPtr = hostListElemStr;
        }
        
        elem = malloc(sizeof *elem);
        if (!elem) {
            continue;
        }
        
        FNInetAddressInit(elem);
        if (!FNInetHostNameToAddress(hostListElemPtr, elem)) {
            if (FNInetAddressListAppendUnique(current, elem)) {
                free(elem);
                continue;
            }
            
            current = elem;
            listSize++;
            continue;
        }
        
        {
            int tmp;
            
            /*
             * Didn't parse as either AF_INET or AF_INET6, must resolve.
             *
             * DNS resolution may fail because of no connectivity. This will be
             * compensated by the reachability callback, which will (re-)resolve
             * when DNS is available.
             */
            
            free(elem);
            if ((tmp = HostNameResolve(hostListElemPtr, &current)) > 0) {
                listSize += tmp;
            }
        }
    }
    
    if (listSize > 0) {
        ASSERT(current);
        current = (FNInetAddress *)(current->listHead.next);
    } else {
        ASSERT(!current);
    }
    
    FNInetAddressListLog("New white list entry", current);
    
    pthread_rwlock_wrlock(&whiteListLock);
    whiteListDisabled = false;
    old = whiteList;
    whiteList = current;
    pthread_rwlock_unlock(&whiteListLock);
    
    if (old && OSAtomicDecrement32(&old->refCount) == 0) {
        FNInetAddressListLog("Deleted white list entry", old);
        FNListDeallocate(&old->listHead, ListDeallocCB, NULL);
    }
    CFRelease(hostList);
    return NULL;
}


/**
 * Resolves the list of policy specified host names or IP addresses, and caches
 *    all corresponding addresses in 'whiteList'.
 *    This function performs its task asynchronously to avoid potentially
 *    blocking an application's main thread during DNS resolution.
 * @return 0 if successful, < 0 otherwise.
 */

static int
BuildWhiteList(void)
{
    int rc;
    pthread_t thr;
    CFArrayRef list;
    
    pthread_rwlock_rdlock(&policyHostListLock);
    list = policyHostList;
    if (list) {
        CFRetain(list);
    }
    pthread_rwlock_unlock(&policyHostListLock);
    
    /*
     * \todo There is a race here. Two DoBuildWhiteList invocations can complete
     * and write to to the whiteList out of order. This is especiallly likely
     * when the first list includes a DNS name and the second one does not.
     */
    
    rc = pthread_create(&thr, NULL, DoBuildWhiteList, (void *)list);
    if (rc && list) {
        CFRelease(list);
        return -1;
    }
    
    return 0;
}


/**
 * Disables the white list allowing all connections
 */

void
FNInetDisableWhiteList()
{
    FNInetAddress *old;
    
    pthread_rwlock_wrlock(&whiteListLock);
    whiteListDisabled = true;
    old = whiteList;
    whiteList = NULL;
    pthread_rwlock_unlock(&whiteListLock);
    
    if (old && OSAtomicDecrement32(&old->refCount) == 0) {
        FNInetAddressListLog("Deleted white list entry", old);
        FNListDeallocate(&old->listHead, ListDeallocCB, NULL);
    }
}


/**
 * Sets and enables the list of policy specified host names or IP addresses
 *
 * The addresses are subsequently resolved and cached in 'whiteList'.
 *
 * @param hostListArg array of CFStringRef-s containing host names or addresses.
 *    @note If this paramter is NULL or points to an empty list the effect is to
 *    disable all connectivity.
 * @return 0 if successful, < 0 otherwise.
 */

int
FNInetSetWhiteList(CFArrayRef hostListArg)
{
    FNStringArrayLog(__FUNCTION__, hostListArg);
    
    CFArrayRef old;
    
    if (hostListArg) {
        CFRetain(hostListArg);
    }
    
    pthread_rwlock_wrlock(&policyHostListLock);
    old = policyHostList;
    policyHostList = hostListArg;
    pthread_rwlock_unlock(&policyHostListLock);
    if (old) {
        CFRelease(old);
    }
    
    return BuildWhiteList();
}


/**
 * Safely retrieves the white list, incrementing its reference count. A white
 *    list retrieved in this manner, must be put back (see below).
 * @param [out] disabled Ignored if NULL. If not NULL set to @c true if the
 *    white list is disabled. In this case the return value is always NULL.
 *    Otherwise set to @c false.
 * @return white list or NULL.
 */

FNInetAddress *
FNInetGetWhiteList(bool *disabledOut)
{
    FNInetAddress *res;
    
    bool disabled;
    pthread_rwlock_rdlock(&whiteListLock);
    disabled = whiteListDisabled;
    res = whiteList;
    if (res) {
        OSAtomicIncrement32(&res->refCount);
    }
    pthread_rwlock_unlock(&whiteListLock);
    
    ASSERT(!disabled || !res);
    if (disabledOut) {
        *disabledOut = disabled;
    }
    return res;
}


/**
 * Puts back a previously retrieved white list, decrementing its reference
 *    count; the list is deallocated when the reference count drops to zero.
 * @param [in,out] whiteListArg previously retrieved white list.
 */

void
FNInetPutWhiteList(FNInetAddress *whiteListArg)
{
    if (whiteListArg && OSAtomicDecrement32(&whiteListArg->refCount) == 0) {
        FNListDeallocate(&whiteListArg->listHead, ListDeallocCB, NULL);
    }
}


/**
 * Tests if the list argument contains the address argument.
 *    Note that this function is of O(N) complexity, having to enumerate
 *    the list; it is not suitable for use with large sets.
 * @param list list of address elements.
 * @param family address family of 'addr'.
 * @param addr pointer to an IPv4 or IPv6 address in network representation.
 * @return != 0 if the list contains the address, 0 otherwise.
 */

int
FNInetAddressListDoesContainRaw(FNInetAddress *list,
                                int family,
                                void *addr)
{
    ListIsEqualArgType arg = { .family = family, .addr = addr };
    
    ASSERT(list && addr && (family == AF_INET || family == AF_INET6));
    return FNListApply(&list->listHead, ListIsEqualCB, &arg);
}





/*
 * Data and callback to detect basic reachability.
 */


/**
 * Called when network reachability changes. It rebuilds the DNS list and
 *    verifies reachability of any one of the DNS server addresses. It then
 *    rebuilds the whitelist.
 * @param target associated target object.
 * @param flags changed state.
 * @param info callback data.
 */

static void
ReachabilityCB(SCNetworkReachabilityRef target,
               SCNetworkReachabilityFlags flags,
               void *info)
{
    (void)target;
    (void)info;
    
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        FNInetAddress *dnsList;
        SCNetworkReachabilityRef reachability;
        SCNetworkReachabilityFlags flags2;
        struct sockaddr *addr;
        struct sockaddr_in in4 = {
            .sin_family = AF_INET,
            .sin_len = sizeof in4
        };
        struct sockaddr_in6 in6 = {
            .sin6_family = AF_INET6,
            .sin6_len = sizeof in6
        };
        
        BuildDNSList();
        
        dnsList = FNInetGetDNSList();
        if (dnsList) {
            if (dnsList->family == AF_INET) {
                in4.sin_addr = dnsList->u.in4;
                addr = (struct sockaddr *)&in4;
            } else { // AF_INET6
                in6.sin6_addr = dnsList->u.in6;
                addr = (struct sockaddr *)&in6;
            }
            
            reachability =
            SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, addr);
            if (reachability &&
                SCNetworkReachabilityGetFlags(reachability, &flags2) &&
                (flags2 & kSCNetworkReachabilityFlagsReachable)) {
                /*
                 * Rebuild the whitelist cache since:
                 * a) this may have failed when FNInetSetWhiteList() was called, or
                 * b) some specified host names may have their DNS entries changed.
                 */
                
                BuildWhiteList();
            }
            
            if (reachability) {
                CFRelease(reachability);
            }
            
            FNInetPutDNSList(dnsList);
        }
    }
}


/**
 * Installs the reachability callback.
 * @return 0 if successful, != 0 otherwise.
 */

int
ReachabilityInit(void)
{
    struct sockaddr *addr;
    struct sockaddr_in in4 = {
        .sin_family = AF_INET,
        .sin_len = sizeof in4
    };
    struct sockaddr_in6 in6 = {
        .sin6_family = AF_INET6,
        .sin6_len = sizeof in6
    };
    
    addr = (struct sockaddr *)&in4;
    inet4Reachability =
    SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, addr);
    
    addr = (struct sockaddr *)&in6;
    inet6Reachability =
    SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, addr);
    
    if (!inet4Reachability ||
        !inet6Reachability ||
        !SCNetworkReachabilitySetCallback(inet4Reachability,
                                          ReachabilityCB, NULL) ||
        !SCNetworkReachabilitySetCallback(inet6Reachability,
                                          ReachabilityCB, NULL) ||
        !SCNetworkReachabilityScheduleWithRunLoop(inet4Reachability,
                                                  CFRunLoopGetMain(),
                                                  kCFRunLoopDefaultMode) ||
        !SCNetworkReachabilityScheduleWithRunLoop(inet6Reachability,
                                                  CFRunLoopGetMain(),
                                                  kCFRunLoopDefaultMode)) {
            CFLog(CFSTR("FATAL: Reachability callback could not be installed."));
            return -1;
        }
    
    return 0;
}


/**
 * Uninstalls the reachability callback.
 */

static void
ReachabilityExit(void)
{
    ASSERT(inet4Reachability);
    ASSERT(inet6Reachability);
    
    SCNetworkReachabilityUnscheduleFromRunLoop(inet4Reachability,
                                               CFRunLoopGetMain(),
                                               kCFRunLoopDefaultMode);
    SCNetworkReachabilitySetCallback(inet4Reachability, NULL, NULL);
    CFRelease(inet4Reachability);
    
    SCNetworkReachabilityUnscheduleFromRunLoop(inet6Reachability,
                                               CFRunLoopGetMain(),
                                               kCFRunLoopDefaultMode);
    SCNetworkReachabilitySetCallback(inet6Reachability, NULL, NULL);
    CFRelease(inet6Reachability);
}


/**
 * One-time initialization function.
 * Failure is fatal and translates to the wrapped application being killed.
 */

void
FNInetInit(void)
{
    //extern int FNInetSocketFiltersInit(void);
    static pthread_rwlockattr_t lockAttr;
    int rc = 0;
    
    if (pthread_rwlockattr_init(&lockAttr) ||
        pthread_rwlock_init(&dnsListLock, &lockAttr) ||
        pthread_rwlock_init(&whiteListLock, &lockAttr) ||
        pthread_rwlock_init(&policyHostListLock, &lockAttr)) {
        rc = -1;
        CFLog(CFSTR("FATAL: Inet filters/interceptors could not be installed."));
        goto out;
    }
    
    rc = ReachabilityInit();
    if (rc) {
        goto out;
    }
    
    //rc = FNInetSocketFiltersInit();
    //if (rc) {
    //    goto out;
   // }
    
    atexit(ReachabilityExit);
    
    /*
     * Attempt to immediately build the DNS list, in case there is connectivity.
     * If this fails, we have already initialized the reachability callback,
     * which ensures that both the DNS and white lists are rebuilt on demand.
     */
    
    BuildDNSList();
    
out:
    if (rc) {
        //TODO::CHECK FNHalt();
    }
}

