//
//  VHError.h
//
//  Copyright (c) 2013 VMware, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString *const kVHErrorDomain;

/*
 * \brief Common errors
 *
 * These "VHErrors" are a small set of "common" errors that apply across libraries and applications.
 *
 * VHErrors are not intended to be "user presentable" or "localized". They must be translated by the
 * hosting application (or possibly some shared error policy library) before they are presented to the user.
 *
 * \todo other possible VHErrors include timeout, already exists, invalid state, etc. These should be added
 *       when a good motivating use case arises.
 */
typedef enum VHErrorCode : NSInteger {
   // Do not allow a 0 error code value as it is the result of ((NSError *)nil).code

   /**
    * An operation was cancelled intentionally.
    *
    * This error may be used for the completion callback of cancelled operations.
    */
   VH_ERROR_CANCELLED = 1,

   /**
    * The server (remote end) generated an unexpected response.
    *
    * This may indicate a failure at the server end or a protocol or version mis-match between client and server.
    */
   VH_ERROR_SERVER_PROTOCOL,

   /**
    * The client failed to connect to the server.
    *
    * This may indicate a client configuration, or network configuration issue.
    */
   VH_ERROR_SERVER_CONNECTION,

} VHErrorCode;

@interface VHError : NSObject
+ (NSError *)errorWithCode:(VHErrorCode)code;
+ (NSError *)errorWithCode:(VHErrorCode)code reason:(NSString *)reason, ...
NS_FORMAT_FUNCTION(2,3);
+ (BOOL)fill:(NSError **)error withCode:(VHErrorCode)code;
+ (BOOL)fill:(NSError **)error withCode:(VHErrorCode)code reason:(NSString *)reason, ...
NS_FORMAT_FUNCTION(3,4);
@end
