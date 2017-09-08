//
//  EnrollmentServicesEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWNetwork

internal class EnrollmentServicesEndpoint: CTLService {
    internal var config: EnrollmentServicesConfig
    internal var serviceEndpoint: String = ""
    internal var hostUrlString: String { return config.airWatchServerURL }

    required init(config: EnrollmentServicesConfig) {
        self.config = config
        super.init()
        self.validator = AirWatchHeaderValidator()        
    }
}

extension EnrollmentServicesEndpoint: RestfulServiceEndPoint { }
