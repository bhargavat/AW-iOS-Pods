//
// VHProxyServerSocket.m
//
// Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyServerSocket.h"
#import "VHProxyServerSocketDelegate.h"
#import "VHProxyUtils.h"

#import "Fuji.h"
#import "VHFinally.h"

#import <CoreFoundation/CoreFoundation.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <netinet/in.h>
#import <sys/socket.h>
#import "VHDispatchSharedThreadQueue.h"

static void handleConnect(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info);

/**
 * \brief utility function to close and nil-out a CFSocketRef
 *
 * \param sock pointer to a possibly NULL CFSocket to close.
 */
static void
closeSocket(CFSocketRef *sock)
{
   if (*sock != NULL) {
      CFSocketInvalidate(*sock);
      CFRelease(*sock);
      *sock = NULL;
   }
}

static id<VHDispatchRunLoopQueuing> queue;

@interface VHProxyServerSocket ()
@property (nonatomic, retain, readwrite) NSString *boundHost;
@property (nonatomic, readwrite) NSInteger boundPort;
@property (nonatomic, retain) id<VHProxyServerSocketDelegate> delegate;
@property (nonatomic) CFSocketRef socket;
@end

/**
 * \brief Wrap a single loopback server socket
 */
@implementation VHProxyServerSocket

/**
 * \brief initialize object
 *
 * The server socket will be scheduled on the current run loop.
 *
 * \param delegate Delegate to which incoming accepted connections are dispatched. The delegate is retained
 *         until close is called or the server socket is destroyed.
 */
- (VHProxyServerSocket *)initWithDelegate:(id<VHProxyServerSocketDelegate>)delegate
{
   if (self = [super init]) {
      self.delegate = delegate;
   }
   return self;
}

/**
 * \brief destroy object
 */
- (void)dealloc
{
   //[_boundHost release];
   _boundHost = nil;
   //[_delegate release];
   _delegate = nil;
   closeSocket(&_socket);
   //[super dealloc];
}

/**
 * \brief create a socket, bind it and start listening on it
 *
 * \todo @knownjira={FUJI-1627} most of the NOT_IMPLEMENTED's below will be covered by a later
 *       "negative path" story.
 *
 * \param interface The IP address to which we should bind. The only values currently supported are
 *        numeric ipv4 and ipv6 addresses.
 * \param port The port to which the server socket should bind. IF 0 then the operating system will
 *        allocate an ephmeral port.
 * \return YES if a socket was successfully created, bound, and listened to. At that point the boundHost and
 *         boundPort properties are valid.
 */
- (BOOL)bindAndListenOnAddress:(NSString *)address
                          port:(NSInteger)port
{
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [VHDispatchSharedThreadQueue new];
    });

    
   // place a non-retained pointer to self in the socket context. We retrieve this in handleContext below.
   CFSocketContext context = { 0 };
   context.info = (__bridge void *)self;

   struct addrinfo hint = { 0 };
   hint.ai_family = PF_UNSPEC;
   hint.ai_flags = AI_NUMERICHOST;
   struct addrinfo *resolvedAddrInfo = NULL;
   if (getaddrinfo([address cStringUsingEncoding:NSUTF8StringEncoding], NULL, &hint, &resolvedAddrInfo) != 0) {
      return NO;
   }
    struct addrinfo *tcpAddrInfo = resolvedAddrInfo;

   for (; tcpAddrInfo != NULL; tcpAddrInfo = tcpAddrInfo->ai_next) {
      if (tcpAddrInfo->ai_socktype != SOCK_STREAM) {
         continue;
      }
      if (tcpAddrInfo->ai_protocol != IPPROTO_TCP) {
         continue;
      }
      if (tcpAddrInfo->ai_family == PF_INET) {
         struct sockaddr_in *addr = (struct sockaddr_in*)tcpAddrInfo->ai_addr;
         ASSERT(addr->sin_len == sizeof (struct sockaddr_in));
         addr->sin_port = htons(port);
         break;
      }
      if (tcpAddrInfo->ai_family == PF_INET6) {
         struct sockaddr_in6 *addr = (struct sockaddr_in6*)tcpAddrInfo->ai_addr;
         ASSERT(addr->sin6_len == sizeof (struct sockaddr_in6));
         addr->sin6_port = htons(port);
         break;
      }
   }

    if (tcpAddrInfo == NULL) {
        NOT_IMPLEMENTED();                
        return NO;
    }
    
    self.socket = CFSocketCreate(kCFAllocatorDefault,
                                 tcpAddrInfo->ai_family,
                                 tcpAddrInfo->ai_socktype,
                                 tcpAddrInfo->ai_protocol,
                                 kCFSocketAcceptCallBack,
                                 handleConnect,
                                 &context);
    
    setsockopt(CFSocketGetNative(self.socket), SOL_SOCKET, SO_REUSEADDR, &(int){ 1 }, sizeof(int));
    
    CFDataRef bindData = CFDataCreate(kCFAllocatorDefault, (UInt8 *)tcpAddrInfo->ai_addr, tcpAddrInfo->ai_addrlen);
    CFSocketError err = CFSocketSetAddress(self.socket, bindData);
    CFRelease(bindData);
    if (err != kCFSocketSuccess) {
        return NO;
    }

    dispatch_semaphore_t addSource = dispatch_semaphore_create(0);
    
    [queue enqueue: ^{
        CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, self.socket, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        CFRelease(source);
        dispatch_semaphore_signal(addSource);
        
    }];
    
    
    dispatch_semaphore_wait(addSource, DISPATCH_TIME_FOREVER);

   if (tcpAddrInfo->ai_family == PF_INET) {
      struct sockaddr_in boundAddr = { 0 };
      socklen_t boundAddrLen = sizeof boundAddr;
      if (getsockname(CFSocketGetNative(self.socket), (struct sockaddr *)&boundAddr, &boundAddrLen) < 0) {
         NOT_IMPLEMENTED();
      }

      char boundAddrBuf[INET_ADDRSTRLEN];
      if (inet_ntop(AF_INET, &boundAddr.sin_addr, boundAddrBuf, (socklen_t)sizeof boundAddrBuf) == NULL) {
         NOT_IMPLEMENTED();
      }
      self.boundHost = [NSString stringWithCString:boundAddrBuf encoding:NSASCIIStringEncoding];
      self.boundPort = ntohs(boundAddr.sin_port);
   } else {
      ASSERT(tcpAddrInfo->ai_family == PF_INET6);
      struct sockaddr_in6 boundAddr = { 0 };
      socklen_t boundAddrLen = sizeof boundAddr;
      if (getsockname(CFSocketGetNative(self.socket), (struct sockaddr *)&boundAddr, &boundAddrLen) < 0) {
         NOT_IMPLEMENTED();
      }

      char boundAddrBuf[INET6_ADDRSTRLEN];
      if (inet_ntop(AF_INET6, &boundAddr.sin6_addr, boundAddrBuf, (socklen_t)sizeof boundAddrBuf) == NULL) {
         NOT_IMPLEMENTED();
      }
      self.boundHost = [NSString stringWithCString:boundAddrBuf encoding:NSASCIIStringEncoding];
      self.boundPort = ntohs(boundAddr.sin6_port);
   }
    [VHFinally newFinally:^{
        freeaddrinfo(resolvedAddrInfo);
    }];
   return YES;
}

/**
 * \brief Close the server socket and stop accepting new connections.
 *
 * Existing connections continue to stay up and forward data.
 */
- (void)close
{
   closeSocket(&_socket);
   //[_delegate release];
   _delegate = nil;
}

@end

/**
 * \brief CFSocketCallBack function to handle an incoming connection.
 *
 * \param sock The CFSocket corresponding to the event that occurred.
 * \param callbackType The enumerated value for the callback.
 * \param address A CFData object containing the lower-level sockaddr information (not used here).
 * \param data For an accept event, a pointer to a CFSocketNativeHandle.
 * \param info The .info pointer supplied to the CFSocketContext structure associated with the socket.
 *        This will contain a (un-retained) pointer to the VHProxyServerSocket instance.
 */
static void
handleConnect(CFSocketRef sock,
              CFSocketCallBackType type,
              CFDataRef address,
              const void *data,
              void *info)
{
   PROXY_TRACE(@"type:%d", (int)type);
   if (type != kCFSocketAcceptCallBack) {
      return;
   }

   VHProxyServerSocket *localProxy =  (__bridge id)info;
   CFSocketNativeHandle localRequest = *(CFSocketNativeHandle *)data;
   [localProxy.delegate forwardLocalSocket:localRequest];
}
