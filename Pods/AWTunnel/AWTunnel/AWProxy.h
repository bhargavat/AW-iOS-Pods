
/*
 Copyright © 2016 VMware, Inc. All rights reserved.
 This product is protected by copyright and intellectual property laws in the United States and other countries as well as by international treaties.
 AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
 */
/*! \file AWProxy.h */

#import <Foundation/Foundation.h>

typedef enum
{
    AWProxyServerTypeUnknown = -1,
    AWProxyServerTypeStandard = 0,
    AWproxyServerTypeMAG = 1,
    AWproxyServerTypeF5 = 2,
    AWPRoxyServerTypeFuji = 3
}AWProxyServerType;

typedef enum {
	AWProxyFailureReasonUnrecoverable = -1,		// There is a major problem
	AWProxyFailureReasonBadCredentials,			// Standard Proxy requires user/pass. Set the username and password properties on AWProxy sharedInstance
	AWProxyFailureReasonBadCertificate,		// Using an invalid certificate. request a new one using -fetchMAGCertificate:
	AWProxyFailureReasonDeviceNotCompliant,		// The device is not compliant. Tell the user they need to become compliant to use the MAG.
	AWProxyFailureReasonDeviceNotManaged,		// The device is not managed.
} AWProxyFailureReason;

typedef void (^certificateFetchCallback)(BOOL success, NSError*  _Nullable error);


@protocol AWProxyDelegate <NSObject>

@required
- (void)proxyConnectionFailed:(AWProxyFailureReason)reason;

@optional

- (BOOL)proxyShouldHandleRequest:(NSURLRequest * _Nullable)request;

@end

@class AWProxyCertService;

@interface AWProxy : NSObject

@property (nonatomic, unsafe_unretained, nullable) id<AWProxyDelegate> delegate;

@property (nonatomic, assign) AWProxyServerType type;

/** Property to indicate if traffic is currently routed through the proxy. **/
@property(nonatomic, assign, readonly)BOOL isEnabled;

/**
 The hostname of proxy.
 */
@property(nonatomic, copy, nullable) NSString *host;

@property(nonatomic, assign)NSInteger httpPort;


/* 
 HTTPS port is not used for standard proxy.
 */
@property(nonatomic, assign)NSInteger httpsPort;

/* Properties associated with standard proxy. */

/**
 Set to true if the proxy will require authentication. Only used for standard proxy.
 */
@property(nonatomic, assign) BOOL requiresAuth;

@property (nonatomic, copy, nullable) NSString *username;

@property (nonatomic, copy, nullable) NSString *password;

/*
 URL to a pac file. If this property is set, all settings from the PAC file will take precedence over manully set 
 properties.
 */
@property (nonatomic, strong, nullable) NSURL *autoConfigURL;


/* Properties associated with MAG proxy. */

/** 
 Property to indicate whether it supports Public SSL certificate or Airwatch Internal certificate. 
 Default is Airwatch Internal Certificate /. 
 */
@property (nonatomic, assign) BOOL usePublicMAGCert;


/**
	Defaults to YES.
 */
@property (nonatomic, assign) BOOL shouldSignRequests;


/* App tunnel domains */
@property (nonatomic, strong, nullable) NSArray *appTunnelDomains;

/**
    Proxy cert Service to deal with cert fetching and storing
 */
@property (nonatomic, nullable, retain) AWProxyCertService *proxyCertService;

/**  Gets the shared instance of the MAG Proxy module.
 Method should be called when other classes need to access the MAGProxy instance.
 @return a pointer to the AWProxy object.
 */
+ (AWProxy * _Nonnull)sharedInstance;

/*!
 @method configure 
 @abstract Configure the AirWatch Proxy 
 @discussion Configure Airwatch Proxy with host, http port, https port and server type.
 */
- (void)configureWithHost: (NSString * _Nullable)host
                 httpPort: (NSInteger)http
                httpsPort: (NSInteger)https
               serverType: (AWProxyServerType)type;


/*!
 @method fetchMAGCertificate
 @abstract Fetches certificate required for MAG Proxy
 */
- (void)fetchMAGCertificate:(certificateFetchCallback _Nullable)callback;

/*!
 @method start
 @abstract This method registers the AirWatch Proxy implementation
 to hook all calls through NSURLConnection, and route via the proxy.
 @discussion If your applications makes calls at the CFNetwork layer
 instead of the NSURL* layer, the calls will not be intercepted for
 proxy. Only connections at the NSURL* layer will be intercepted.
 @param error - will be set to a NSError object indicating an error occurred.
 @return BOOL indicating if the service was started.
 */
- (BOOL)start:(NSError * _Nullable * _Nullable)error;

/*!
 @method stop
 @abstract Stop using the AirWatch Proxy.
 @discussion After stopping, the AirWatch proxy is no longer used
 to route traffic via the Proxy.
 */
- (void)stop;

/**
	RSA Adaptive Auth.
 */
@property (nonatomic, assign) BOOL magRSAAdaptiveAuthEnabled;

@end