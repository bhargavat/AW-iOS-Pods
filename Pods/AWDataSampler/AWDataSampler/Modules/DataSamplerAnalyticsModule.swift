//
//  DataSamplerAnalyticsModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


class DataSamplerAnalyticsModule: DataSamplerBaseModule {
    override func sample() throws -> [DataSample] {
        /// The analytics samples would be added out of band upon events received
        return []
    }
}