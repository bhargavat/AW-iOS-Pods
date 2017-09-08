//
//  SharedConstants.swift
//  AWSecureSharedStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


public enum KeyValueStoreItemStoreType: String {

    case ServiceURL                 = "AWApplicationServerURLAccount"
    case GroupID                    = "kAWApplicationGroupIDAccount"
    case SharedEnrollmentInfo       = "com.air-watch.ios.application"

    case CommonDetails              = "com.anchor"
    case SSODetails                 = "com.shared.context.anchor"
    case CommonIdentity             = "com.aw.common.hmac.account"
    case LegacyCommonIdentity       = "com.auth.master.account"

    case AuthenticationPayload      = "com.authentication.payload.account"
    case BootTime                   = "com.boottime.account"
    case GlobalLockStatus           = "com.unlock.account"
    case NonShared                  = "com.app.default"
    
    case CommonAuthenticationGroup  = "AWCommonAuthenticationGroup.account"

}
