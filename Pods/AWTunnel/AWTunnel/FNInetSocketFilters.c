//
//  FNInetSocketFilters.c
//
//  Copyright (c) 2012-2013 VMware, Inc. All rights reserved.
//

#if 0

#include <errno.h>
#include <HookManager/HookManager.h>
#include "FNInetPriv.h"


typedef enum AddressAllowedKind {
   kAddressAllowedKindDNS,
   kAddressAllowedKindWhiteList
} AddressAllowedKind;


/*
 * Functions to wrap: connect(), sendto(), sendmsg().
 */

static int (*connectOrig)(int, const struct sockaddr *, socklen_t);
static int (*sendMsgOrig)(int, const struct msghdr *, int);

static int
(*sendToOrig)(int,
              const void *,
              size_t,
              int,
              const struct sockaddr *,
              int);



/**
 * Tests whether traffic should be allowed on a given socket address.
 * @param addr socket address.
 * @param kind allowed address list to test against.
 * @return 0 if not allowed, != 0 otherwise.
 */

static int inline
IsAddressAllowed(const struct sockaddr *addr,
                 AddressAllowedKind kind)
{
   int rc;
   void *raw;
   FNInetAddress *list;

   ASSERT(addr);

   if (addr->sa_family == AF_INET) {
      raw = (void *)&((struct sockaddr_in *)addr)->sin_addr;
   } else if (addr->sa_family == AF_INET6) {
      raw = (void *)&((struct sockaddr_in6 *)addr)->sin6_addr;
   } else {
      /*
       * Hmm, restricting checks to AF_INET/AF_INET6 is probably
       * acceptable, but I don't think it's enough.
       */

      return 1;
   }

   switch (kind) {
   case kAddressAllowedKindDNS:
      list = FNInetGetDNSList();
      break;
   case kAddressAllowedKindWhiteList: {
      bool whiteListDisabled = false;
      list = FNInetGetWhiteList(&whiteListDisabled);
      if (whiteListDisabled) {
         ASSERT(!list);
         return 1;
      }
   }
      break;
   }

   if (!list) {
      return 0;
   }

   rc = FNInetAddressListDoesContainRaw(list, addr->sa_family, raw);

   switch (kind) {
   case kAddressAllowedKindDNS:
      FNInetPutDNSList(list);
      break;
   case kAddressAllowedKindWhiteList:
      FNInetPutWhiteList(list);
      break;
   }

   return rc;
}


/**
 * Wraps the standard 'connect()' function, checks if destination
 *    IPv{4|6} address should be allowed access.
 * @param sd socket descriptor.
 * @param addr destination address.
 * @param addrLen size of destination address structure.
 * @return value returned by the original function, or -1, with 'errno'
 *    set to EHOSTUNREACH if destination address is not allowed.
 */

static int
Connect(int sd,
        const struct sockaddr *addr,
        socklen_t addrLen)
{
   if (!addr) {
      return connectOrig(sd, addr, addrLen);
   }

   if (IsAddressAllowed(addr, kAddressAllowedKindWhiteList) ||
       IsAddressAllowed(addr, kAddressAllowedKindDNS)) {
      return connectOrig(sd, addr, addrLen);
   }

   errno = EHOSTUNREACH;
   return -1;
}


/**
 * Wraps the standard 'sendto()' function, checks if destination
 *    IPv{4|6} address should be allowed access.
 * @param sd socket descriptor.
 * @param msg bytes to send.
 * @param len number of bytes to send.
 * @param flags standard 'sendto()' send flags.
 * @param addr destination address.
 * @param addrLen size of destination address structure.
 * @return value returned by the original function, or -1, with 'errno'
 *    set to EHOSTUNREACH if destination address is not allowed.
 */

static int
SendTo(int sd,
       const void *msg,
       size_t len,
       int flags,
       const struct sockaddr *addr,
              int addrLen)
{
   if (!addr) {
      return sendToOrig(sd, msg, len, flags, addr, addrLen);
   }

   if (IsAddressAllowed(addr, kAddressAllowedKindWhiteList) ||
       IsAddressAllowed(addr, kAddressAllowedKindDNS)) {
      return sendToOrig(sd, msg, len, flags, addr, addrLen);
   }

   errno = EHOSTUNREACH;
   return -1;

}


/**
 * Wraps the standard 'sendmsg()' function, checks if destination
 *    IPv{4|6} address should be allowed access.
 * @param sd socket descriptor.
 * @param msg standard 'struct msghdr' 'sendmsg()' argument
 *    containing destination address and payload information.
 * @param flags standard 'sendmsg()' send flags.
 * @return value returned by the original function, or -1, with 'errno'
 *    set to EHOSTUNREACH if destination address is not allowed.
 */

static int
SendMsg(int sd,
        const struct msghdr *msg,
        int flags)
{
   struct sockaddr *addr;

   if (!msg || !(addr = msg->msg_name)) {
      return sendMsgOrig(sd, msg, flags);
   }

   if (IsAddressAllowed(addr, kAddressAllowedKindWhiteList) ||
       IsAddressAllowed(addr, kAddressAllowedKindDNS)) {
      return sendMsgOrig(sd, msg, flags);
   }

   errno = EHOSTUNREACH;
   return -1;
}


/**
 * One-time initialization of socket filters.
 * @return 0 if successful, != 0 otherwise.
 */

int
FNInetSocketFiltersInit(void)
{
   int rc = 0;

   connectOrig = HookMgr_GetOrigFunction(HOOK_libsystem_kernel_connect);
   sendToOrig = HookMgr_GetOrigFunction(HOOK_libsystem_kernel_sendto);
   sendMsgOrig = HookMgr_GetOrigFunction(HOOK_libsystem_kernel_sendmsg);

   if (!connectOrig || !sendToOrig || !sendMsgOrig) {
      rc = -1;
      goto out;
   }

   if (HookMgr_Register(Connect, HOOK_libsystem_kernel_connect) ||
       HookMgr_Register(SendTo, HOOK_libsystem_kernel_sendto) ||
       HookMgr_Register(SendMsg, HOOK_libsystem_kernel_sendmsg)) {
      rc = -1;
      goto out;
   }

out:
   if (rc) {
      CFLog(CFSTR("FATAL: Socket filter interceptors could not be installed."));
   }
   return rc;
}
#endif
