//
//  FujiRPCConst.h
//
//  Common constants for wrapped app <-> fuji communication.
//
//  See https://wiki.eng.vmware.com/Fuji/SecureIPC for further details.
//
//  Copyright (c) 2012 VMware, Inc. All rights reserved.
//

/**
 * RPC dictionary keys
 */
static NSString * const kFujiRPCCmd          = @"kFujiRPCCmd";
static NSString * const kFujiRPCReply        = @"kFujiRPCReply";

/**
 * RPC dictionary values for key kFujiRPCCmd
 */
static NSString * const kFujiRPCPINUnlock    = @"kFujiRPCPINUnlock";
static NSString * const kFujiRPCCrashData    = @"kFujiRPCCrashData";
static NSString * const kFujiRPCInvalidToken = @"kFujiRPCInvalidToken";
static NSString * const kFujiRPCWipe         = @"kFujiRPCWipe";
static NSString * const kFujiRPCRestoreSharedData = @"kFujiRPCRestoreSharedData";

/**
 * RPC dictionary values for key kFujiRPCReply
 */
static NSString * const kFujiRPCPolicyCred   = @"kFujiRPCPolicyCred";
static NSString * const kFujiRPCPolicies     = @"kFujiRPCPolicies";
static NSString * const kFujiRPCAck          = @"kFujiRPCAck";

/**
 * Wipe message prefix
 */
static NSString * const kWipeMessagePrefix    = @"wipe-";

/**
 * The key for the lib horizon version info.
 */
static NSString * const kHorizonLibVersionType = @"libHorizonVersion";
