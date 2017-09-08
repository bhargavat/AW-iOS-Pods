//
//  DataSamplerDelegate.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
     The delegate functions would be called on main thread
 */
public protocol DataSamplerDelegate {
    func DataSamplerSamplingErrorNotify(_ sampler: DataSampler, error: NSError)
    func DataSamplerDidSendSamples(_ sampler: DataSampler)
    func DataSamplerFailedSendingSamples(_ sampler: DataSampler, error: NSError)
}
