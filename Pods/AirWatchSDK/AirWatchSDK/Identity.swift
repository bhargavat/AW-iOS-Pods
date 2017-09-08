//
//  Identity.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


extension CoderKeys {
    class Identity {
        static let enrollment = "enrollment"
        static let authorization = "authorization"
    }
}

public class Identity: NSObject, NSCoding {
    public var enrollment: EnrollmentInformation?
    public var authorization: AuthenticatonInfo?

    @objc required convenience public init(coder decoder: NSCoder) {
        self.init()
        self.enrollment = decoder.decodeObject(forKey: CoderKeys.Identity.enrollment) as? EnrollmentInformation
        self.authorization = decoder.decodeObject(forKey: CoderKeys.Identity.authorization) as? AuthenticatonInfo
    }
    convenience init(authorization: AuthenticatonInfo?, enrollment: EnrollmentInformation?) {
        self.init()
        self.enrollment = enrollment
        self.authorization = authorization
    }

    @objc open func encode(with coder: NSCoder) {
        if let enrollment = enrollment {
            coder.encode(enrollment, forKey: CoderKeys.Identity.enrollment)
        }

        if let authorization = authorization {
            coder.encode(authorization, forKey: CoderKeys.Identity.authorization)
        }
    }
}

extension Identity {

    open override func isEqual(_ object: Any?) -> Bool {
        if self === object as AnyObject? { return true }

        if let other = object as? Identity {
            return (self.enrollment == other.enrollment && self.authorization == other.authorization)
        }
        return false
    }

}
