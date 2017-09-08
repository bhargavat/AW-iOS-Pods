//
//  FNInetPriv.h
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

#ifndef _FN_INET_PRIV_H_
#define _FN_INET_PRIV_H_

#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <resolv.h>
#include <arpa/nameser.h>
#include <arpa/inet.h>
#include <netinet/in.h>

#include <CoreFoundation/CFString.h>
#include <CoreFoundation/CFArray.h>
#include "FNPriv.h"


#define FN_INET_ADDR_STR_LEN_MAX 40
#define FN_HOST_NAME_LEN_MAX 128
#define FN_INET_DNS_SERVERS_MAX MAXDNS

/*
 * Build with -DFN_INET_LOG to enable succint logging of added/deleted
 * DNS and white list entries. Should not be used in production builds.
 */

//#define FN_INET_LOG 1



typedef struct FNInetAddress {
    FNList listHead;
    volatile int32_t refCount;
    int rank;
    int family;
    union {
        struct in_addr in4;
        struct in6_addr in6;
    } u;
} FNInetAddress;


/**
 * Initializes an inet address structure;
 * @param[in,out] inetAddr address structure to initialize.
 */

static inline void
FNInetAddressInit(FNInetAddress *inetAddr)
{
    ASSERT(inetAddr);
    memset(inetAddr, 0, sizeof *inetAddr);
    FNListInit(&inetAddr->listHead);
    inetAddr->refCount = 1;
}


/**
 * Retrieves a reference to the binary address of an address structure.
 * @param inetAddr address structure to use.
 * @return reference to binary address.
 */

static inline void *
FNInetAddressGet(const FNInetAddress *inetAddr)
{
    ASSERT(inetAddr &&
           ((inetAddr->family == AF_INET) || (inetAddr->family == AF_INET6)));
    return (inetAddr->family == AF_INET ?
            (void *)&(inetAddr->u.in4) :
            (void *)&(inetAddr->u.in6));
}


/**
 * Stores a binary address in an address structure.
 * @param[in,out] inetAddr address structure to use.
 * @param family address family.
 * @param addr address in binary format according to speficied family.
 */

static inline void
FNInetAddressSet(FNInetAddress *inetAddr,
                 int family,
                 void *addr)
{
    ASSERT(inetAddr &&
           ((family == AF_INET) || (family == AF_INET6)));
    if (family == AF_INET) {
        inetAddr->u.in4 = *((struct in_addr *)addr);
        inetAddr->family = family;
    } else {
        inetAddr->u.in6 = *((struct in6_addr *)addr);
        inetAddr->family = family;
    }
}


/**
 * Converts an address structure to a NUL-terminated string.
 * @param inetAddr address structure to use.
 * @param[out] hostName destination buffer.
 * @param hostNameLen destination buffer length.
 * @return buffer address if successful, NULL otherwise.
 */

static inline const char *
FNInetAddressToHostName(const FNInetAddress *inetAddr,
                        char *hostName,
                        unsigned int hostNameLen)
{
    ASSERT(inetAddr && hostName && (hostNameLen != 0));
    memset(hostName, 0, hostNameLen);
    return inet_ntop(inetAddr->family, FNInetAddressGet(inetAddr),
                     hostName, hostNameLen);
}


#if defined(FN_INET_LOG)

/**
 * Prints out specified address structure to 'stderr'.
 * @param label message label.
 * @param inetAddr address structure.
 */

static inline void
FNInetAddressLog(const char *label,
                 const FNInetAddress *inetAddr)
{
    char hostName[FN_INET_ADDR_STR_LEN_MAX];
    const char *str;
    
    if (!label) {
        label = "";
    }
    str = FNInetAddressToHostName(inetAddr, hostName, sizeof hostName);
    CFLog(CFSTR("%s: [%s]"), label, str ? str : "<null>");
}

void FNInetAddressListLog(const char *label, FNInetAddress *list);

#else

#define FNInetAddressLog(label, inetAddr) ((void)(label), (void)(inetAddr))
#define FNInetAddressListLog(label, list) ((void)(label), (void)(list))

#endif // FN_INET_LOG


/**
 * Converts a NUL-terminated string to an address structure.
 * @param hostName host name in external IPv4 or IPv6 format.
 * @param[out] inetAddr address structure to use.
 * @return 0 if successful, < 0 otherwise.
 */

static inline int
FNInetHostNameToAddress(const char *hostName,
                        FNInetAddress *inetAddr)
{
    int rc = 0;
    
    ASSERT(hostName && inetAddr);
    
    for (inetAddr->family = AF_INET;
         (inetAddr->family == AF_INET) || (inetAddr->family == AF_INET6);
         ) {
        rc = inet_pton(inetAddr->family, hostName, FNInetAddressGet(inetAddr));
        if (rc == 0) {
            /*
             * If it failed to parse as an AF_INET address, try it as an AF_INET6.
             */
            
            inetAddr->family = (inetAddr->family == AF_INET ? AF_INET6 : AF_UNSPEC);
            rc = -1;
            continue;
        } else {
            if (rc < 0) {
                inetAddr->family = AF_UNSPEC;
            } else {
                /* It parsed correctly; return Ok. */
                
                rc = 0;
            }
            break;
        }
    }
    
    return rc;
}


/*
 * One-time initialization function.
 */

void FNInetInit(void);


/*
 * Policy code must call FNInetSetWhiteList() or FNDisableWhiteList() when
 * whitelist settings change.
 */

int FNInetSetWhiteList(CFArrayRef hostList);
void FNInetDisableWhiteList();


/*
 * FNInet{Get|Put}*List() functions are called from the socket filter wrappers.
 */

FNInetAddress *FNInetGetDNSList(void);
void FNInetPutDNSList(FNInetAddress *dnsList);

FNInetAddress *FNInetGetWhiteList(bool *disabled);
void FNInetPutWhiteList(FNInetAddress *whiteList);

int
FNInetAddressListDoesContainRaw(FNInetAddress *list,
                                int family,
                                void *addr);


/**
 * Tests if the list argument contains the address element argument.
 *    Note that this function is of O(N) complexity, having to enumerate
 *    the list; it is not suitable for use with large sets.
 * @param list list of address elements.
 * @param addr address element to test.
 * @return != 0 if the list contains the element, 0 otherwise.
 */

static inline int
FNInetAddressListDoesContain(FNInetAddress *list,
                             FNInetAddress *addr)
{
    ASSERT(list && addr);
    return FNInetAddressListDoesContainRaw(list, addr->family,
                                           FNInetAddressGet(addr));
}


/**
 * Appends an address element to a list, if not already present.
 *    Note that this function is of O(N) complexity, having to search the
 *    list for uniqueness; it is not suitable for use with large sets.
 * @param[in,out] current list element to append to, may be NULL for new lists.
 * @param[in,out] elem list element to be appended.
 * @return 0 if successful, != 0 otherwise.
 */

static inline int
FNInetAddressListAppendUnique(FNInetAddress *current,
                              FNInetAddress *elem)
{
    ASSERT(elem && FNListIsEmpty(&elem->listHead));
    
    if (current) {
        if (FNInetAddressListDoesContain(current, elem)) {
            return -1;
        }
        FNListAppend(&current->listHead, &elem->listHead);
    }
    
    return 0;
}

#endif // _FN_INET_PRIV_H_

