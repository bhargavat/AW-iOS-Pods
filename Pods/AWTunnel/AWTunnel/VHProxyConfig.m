//
//  VHProxyConfig.m
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import "VHProxyConfig.h"

#import "Fuji.h"
//#import <vmShared/vmPolicies.h>

@interface VHProxyConfig ()

@property (nonatomic, retain) NSArray *proxyURLs;

@end


/**
 * \brief Proxy configuration settings
 */
@implementation VHProxyConfig

/**
 * \brief Initialize configruation based on vmPolicies
 *
 * \param policies policy object used to build configuration
 * \return valid configuration or nil on failure.
 */
- (VHProxyConfig *)initWithPolicies:(void *)policies
{
    /*
   self = [super init];
   if (self == nil) {
      return nil;
   }
   self.proxyURLs = [policies getProxyURLs];
   if (self.proxyURLs.count == 0) {
      LOG_ERROR(@"proxyURLs empty");
      //[self release];
      return nil;
   }
   // extract host:port from first proxy URL.
   NSURL *url = [NSURL URLWithString:self.proxyURLs[0]];
   self.proxyHost = url.host;
   if (self.proxyHost.length == 0) {
      LOG_ERROR(@"Unable to parse proxyHost");
      //[self release];
      return nil;
   }
   self.proxyPort = url.port.integerValue;
   if (self.proxyPort <= 0) {
      LOG_ERROR(@"Unable to parse proxyPort: %d", self.proxyPort);
      [self release];
      return nil;
   }

   // verify that we can rewrite local urls correctly
   NSArray *dummyLocalURLs = [self localURLsForHost:@"127.0.0.1" port:1];
   if (dummyLocalURLs == nil) {
      LOG_ERROR(@"Unable to rewrite proxy URLs");
      [self release];
      return nil;
   }

   NSArray *exceptionsList = [policies getProxyExceptionsList];
   _whiteList = [[policies getWhiteList] mutableCopy];
   if (self.whiteList == nil) {
      self.whiteList = [NSMutableArray arrayWithCapacity:exceptionsList.count];
   }
   if (exceptionsList.count > 0) {
      [self.whiteList addObjectsFromArray:exceptionsList];
   }

   self.authenticateCertificates = [policies isProxyAuthenticateCertificates];
   self.scoped = [policies isProxyScoped];
   self.ftpPassive = [policies isProxyFTPPassive];
   return self;
     */
    return nil;
}

/**
 * \brief destructor
 */
- (void)dealloc
{
   self.proxyURLs = nil;
   self.proxyHost = nil;
   self.whiteList = nil;
   self.localURLs = nil;
   self.exceptionsList = nil;
   //[super dealloc];
}

/**
 * \brief Build a list of local URLs by rewriting proxy URLs from vmPolicies
 *
 * \param localHost local host (from VHProxyService)
 * \param localPort local port (from VHProxyService)
 * \return URLs from vmPolicies rewritten to use the local host and port.
 */
- (NSArray *)localURLsForHost:(NSString *)localHost
                         port:(NSInteger)localPort
{
   NSMutableArray *localURLs = [[NSMutableArray alloc] initWithCapacity:self.proxyURLs.count];
   for (NSString *urlString in self.proxyURLs) {
      NSURL *url = [NSURL URLWithString:urlString];
      NSString *host = url.host;
      if (![host isEqualToString:self.proxyHost]) {
         LOG_ERROR(@"Inconsistent host. Expected: %@, found:%@", self.proxyHost, host);
         //[localURLs release];
         return nil;
      }
      NSInteger port = url.port.integerValue;
      if (port != self.proxyPort) {
         LOG_ERROR(@"Inconsistent port. Expected: %ld, found:%ld", (long)self.proxyPort, (long)port);
         //[localURLs release];
         return nil;
      }
      NSString *scheme = url.scheme; // note: defaults to "http"
      NSString *user = url.user;
      if (user.length == 0) {
         LOG_ERROR(@"Missing user");
         //[localURLs release];
         return nil;
      }
      NSString *password = url.password;
      if (password.length == 0) {
         LOG_ERROR(@"Missing password");
         //[localURLs release];
         return nil;
      }
      NSString *localUrl = [NSString stringWithFormat:@"%@://%@:%@@%@:%ld",
                            scheme, user, password, localHost, (long)localPort];
      [localURLs addObject:localUrl];
   }
   return localURLs;
}

/**
 * \brief Complete configuration with local host and port from VHProxyService
 *
 * This method must be called to complete configuration before accessing the localURLs and whiteList
 * properties.
 *
 * \param localHost local host (from VHProxyService)
 * \param localPort local port (from VHProxyService)
 * \return YES on success; NO on failure.
 */
- (BOOL)configureLocalHost:(NSString *)localHost
                 localPort:(NSInteger)localPort
{
   /*
    * @knownjira{FUJI-2406} adding loopback to the whitelist allows wrapped apps
    * to potentially communicate with non-workspace applications.
    */
   [self.whiteList addObject:localHost];

   _localURLs = [self localURLsForHost:localHost port:localPort];
   return _localURLs != nil;
}

@end
