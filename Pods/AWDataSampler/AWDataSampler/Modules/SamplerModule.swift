//
//  SamplerModule.swift
//  AWDataSampler
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


protocol DataSamplerModule: class {
    func startSampling(_ sampleInterval: TimeInterval,
                       receiveSamples: @escaping (_ samples: [DataSample], _ error: NSError?) -> Void)
    func stopSampling()

    func sample() throws -> [DataSample]
}


class DataSamplerBaseModule: DataSamplerModule {

    fileprivate var queue: DispatchQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.utility)
    fileprivate var shouldStopSampling: Bool = false
    fileprivate var sampleingStarted: Bool = false

    fileprivate func sampling(_ sampleInterval: TimeInterval,
                          receiveSamples: @escaping (_ samples: [DataSample], _ error: NSError?) -> Void) {
        do {
            let samples = try self.sample()
            receiveSamples(samples, nil)
            if (!self.shouldStopSampling) {
                let after = DispatchTime.now() + Double(Int64(sampleInterval * 1e9)) / Double(NSEC_PER_SEC)
                self.queue.asyncAfter(deadline: after, execute: {
                    [unowned self] in
                    self.sampling(sampleInterval, receiveSamples: receiveSamples)
                })
            }
        } catch let err {
            receiveSamples([], err as NSError)
        }
    }

    func startSampling(_ sampleInterval: TimeInterval,
                       receiveSamples: @escaping (_ samples: [DataSample], _ error: NSError?) -> Void) {
        queue.async {
            if !self.sampleingStarted {
                self.shouldStopSampling = false
                self.sampling(sampleInterval, receiveSamples: receiveSamples)
                self.sampleingStarted = true
            }
        }
    }

    func stopSampling() {
        queue.async { 
            self.shouldStopSampling = true
            self.sampleingStarted = false
        }
    }

    func sample() throws -> [DataSample] {
        preconditionFailure("sample() should be only called on subclasses")
    }
}
