//
//  MultiQueueProcessor.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
    This class is originally written by Deep Singh to support multiple prioritized operations.
 */
open class MultiQueueProcessor: NSObject {
    
    fileprivate let kOPERATIONS = "operations"
    fileprivate let queues : [OperationQueue]
    fileprivate var observing : Bool = false
    
    public convenience init(maxConcurrentOperationCount : Int){
        self.init(maxConcurrentOperationCounts: [1,maxConcurrentOperationCount])
    }
    
    public init(maxConcurrentOperationCounts: [Int]){
        assert(maxConcurrentOperationCounts.count > 1,"Alteast two operation counts needed")
        var queues = [OperationQueue]()
        for maxConcurrentOperationCount in maxConcurrentOperationCounts {
            let queue = OperationQueue()
            queue.maxConcurrentOperationCount = maxConcurrentOperationCount
            queue.isSuspended = true
            queues.append(queue)
        }
        self.queues = queues
        
        super.init()
        
        for queue in self.queues {
            queue.addObserver(self, forKeyPath: kOPERATIONS, options: NSKeyValueObservingOptions([.new, .old]), context: nil)
        }
        self.observing = true
    }
    
    deinit {
        for queue in self.queues {
            queue.removeObserver(self, forKeyPath: kOPERATIONS)
        }
    }
    
    open func addOperation(_ queueIndex : Int, operation : Operation){
        assert(queueIndex < self.queues.count)
        self.queues[queueIndex].addOperation(operation)
    }
    
    open var operationCount: Int {
        get {
            var count = 0
            for queue in self.queues {
                count += queue.operationCount
            }
            return count
        }
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            self.startProcessingOperations();
        }
        
    }
    
    func startProcessingOperations() {
        for queue in self.queues {
            if (queue.operationCount > 0) {
                if (queue.isSuspended) {
                    suspendAllExcept(queue)
                    queue.isSuspended = false
                }
                break
            }
        }
    }
    
    func suspendAllExcept(_ queue : OperationQueue) {
        for squeue in self.queues {
            if squeue != queue {
                squeue.isSuspended = true
            }
        }
    }
    
}
