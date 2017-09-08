//
//  UIDevice+Networking.m
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


#import "UIDevice+Networking.h"

#import <arpa/inet.h>
#import <sys/socket.h>
#import <netdb.h>
#import <sys/types.h>
#import <ifaddrs.h>
#import <net/if_var.h>
#import <net/if_dl.h>
#import <net/if.h>

NSString *const AWReachabilityDidChangeNotification = @"AWReachabilityDidChangeNotification";

@implementation AWNetworkAdapter

-(instancetype) init {
    if (self =[super init]) {
        self.family = 0;
        self.name = @"N/A";
        self.ipV4Address = nil;
        self.ipV6Address = nil;
        self.MACAddress = nil;
        self.sentBytes = 0;
        self.sentPackets = 0;
        self.receivedBytes = 0;
        self.receivedPackets = 0;
        self.isLoopback = NO;
    }
    return self;
}

-(NSString*) description {

    return [NSString stringWithFormat:@"<%@, %p >\n{\tName: %@\n}{\tMAC Address: %@\n}{\tBytes Sent: %ld\n}{\tBytes Received: %ld\n}", NSStringFromClass(self.class), self, self.name, self.MACAddress, (long)self.sentBytes, (long)self.receivedBytes];

}
-(NSDictionary*)getInfo {
    NSMutableDictionary *map = [NSMutableDictionary dictionaryWithCapacity:3];

    if (self.ipV4Address.length > 0 ) {
        map[@"IPv4 Address"] = self.ipV4Address;
    }

    if (self.ipV6Address.length > 0 ) {
        map[@"IPv6 Address"] = self.ipV6Address;
    }
    if (self.MACAddress.length > 0 ) {
        map[@"MAC Address"] =  self.MACAddress;
    }

    return map.copy;
}


@end
@implementation UIDevice (Networking)

- (NSArray *)AW_networkAdapters {
    
    struct ifaddrs *ifaddr, *ifa;
    int result = getifaddrs(&ifaddr);
    int family, s;
    char host[NI_MAXHOST];
    NSMutableArray *networkAdapters;
    
    if (result != 0) {
        // TODO: Add error handling code here
        return nil;
    }
    
    networkAdapters = [[NSMutableArray alloc] init];
    
    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr == NULL)
            continue;
        
        AWNetworkAdapter *adapter = nil;
        
        NSString *adapterName = [[NSString alloc] initWithBytes:ifa->ifa_name length:(strlen(ifa->ifa_name) * sizeof(char)) encoding:NSUTF8StringEncoding];
        
        for (AWNetworkAdapter *adap in networkAdapters) {
            if ([[adap name] isEqualToString:adapterName]) {
                adapter = adap;
            }
        }
        
        if (adapter == nil) {
            
            adapter = [[AWNetworkAdapter alloc] init];
            
            [adapter setName:adapterName];
            [networkAdapters addObject:adapter];

        }
        
        
        family = ifa->ifa_addr->sa_family;
        [adapter setFamily:family];
        
        if (family == AF_INET || family == AF_INET6) {
            s = getnameinfo(ifa->ifa_addr, (family == AF_INET) ? sizeof(struct sockaddr_in) :  sizeof(struct sockaddr_in6), host, NI_MAXHOST, NULL, 0, NI_NUMERICHOST);
            if (s != 0) {
                // TODO: Add error handling code here
                exit(EXIT_FAILURE);
            }
            
//            NSString *hostString = [[NSString alloc] initWithBytes:host length:sizeof(host) encoding:NSUTF8StringEncoding];
            NSString *hostString = [[NSString alloc] initWithCString:host encoding:NSUTF8StringEncoding];
            if (family == AF_INET) {
                [adapter setIpV4Address:hostString];
            } else if (family == AF_INET6) {
                [adapter setIpV6Address:hostString];
            }

        }
        
        struct if_data *data = ifa->ifa_data;
        if (data != NULL) {
            [adapter setSentBytes:data->ifi_obytes];
            [adapter setReceivedBytes:data->ifi_ibytes];
            [adapter setSentPackets:data->ifi_opackets];
            [adapter setReceivedPackets:data->ifi_ipackets];
        }
        
        //Can't retrieve MAC Address from iOS7 onwards
        [adapter setMACAddress:nil];
        
        if (ifa->ifa_flags & IFF_LOOPBACK) {
        
            [adapter setIsLoopback:YES];    
        
        }
    }
    
    freeifaddrs(ifaddr);
    
    return networkAdapters;
}

@end
