//
//  TasksPriorityQueues.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation


/**
    Tasks might have different priorities. Instead of dispatching them randomly and rely on the underlying
    GCD schedule policy, some prioritized queuing algorithm could be applied to make the tasks scheduling order
    more determined. For example, some heavy large file download tasks might need lower priority than ordinary
    HTTP post tasks.

    Priority would be within the range of [0, UInt.max] with 0 for default priority queue. Larger number means
    higher priority. So UInt.max would have the maximum priority. This is mainly based on 1) implementation
    convenience; 2) considering standard gaussian (normal) distribution, most of the prioritiy picks would be
    around mean; 3) use 1 as highest priority would look weirder than using UInt.max cause 0 would be the default
    priority.
 */
class TasksPriorityQueues: MultiQueueProcessor {
    //MARK: FIXME: Default to 12 which is always my lucky number
    static let sharedQueues = TasksPriorityQueues(maxConcurrentQueues: 12)
    
    /// the first queue (zero index) is the queue for default priority
    fileprivate let defaultQueue = DispatchQueue(label: "awcorenetwork.priority.queue.default", attributes: DispatchQueue.Attributes.concurrent)
    fileprivate var maxNumOfQueues: UInt = 12

    fileprivate var priorityQueues: PriorityDispatchQueues

    init(maxConcurrentQueues: UInt) {
        if (maxConcurrentQueues > 0) {
            self.maxNumOfQueues = maxConcurrentQueues
        }

        self.priorityQueues = PriorityDispatchQueues(maxConcurrentQueues: self.maxNumOfQueues)

        super.init(maxConcurrentOperationCounts: [1, 1])
    }


    func getQueue(priority: UInt) -> DispatchQueue {
        if (priority == 0) {
            return defaultQueue
        }

        let queue: DispatchQueue

        objc_sync_enter(priorityQueues)
        queue = priorityQueues.getQueue(priority: priority)
        objc_sync_exit(priorityQueues)

        return queue
    }

    //MARK: Internal implementation of priority queue (heap) algorithm
    internal class PriorityDispatchQueues {
        
        fileprivate static let qosClassMapping: [DispatchQoS.QoSClass] = [DispatchQoS.QoSClass.background, DispatchQoS.QoSClass.utility, DispatchQoS.QoSClass.userInitiated, DispatchQoS.QoSClass.userInteractive]
        fileprivate var concurrentQueues: [(UInt, DispatchQueue)] = []
        fileprivate var queuesSorted = false

        fileprivate let maxNumOfQueues: UInt
        fileprivate var currentNumOfQueues: UInt = 0


        /**
            The actual target queues for 12 priority tiers.
            Picking 12 is because invert CDF transform would produce random variables between [-6, 6]. See
            discussions [here](http://stackoverflow.com/questions/75677/converting-a-uniform-distribution-to-a-normal-distribution)
         */
        fileprivate var targetQueues: [DispatchQueue?] = [DispatchQueue?](repeating: nil, count: 12)

        init(maxConcurrentQueues: UInt) {
            maxNumOfQueues = maxConcurrentQueues
        }

        fileprivate func setupTargetQueues() {
            for index in 0...11 {
                
                let qosClz:DispatchQoS.QoSClass = PriorityDispatchQueues.qosClassMapping[index / 3]
                
                /// relative priority would be 0, -1, -2
                let relPriority = -index % 3
                
                let queue = DispatchQueue(label: "awcorenetwork.priority.target.\(index)",
                                          qos: DispatchQoS(qosClass: qosClz, relativePriority: Int(relPriority)),
                                          attributes: DispatchQueue.Attributes.concurrent,
                                          autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                          target: nil)
                
                targetQueues[index] = queue
            }
        }

        /**
            Use inverse CDF transform to transform local priority to native relative priorty.
            The equation can be found [here](http://www.johndcook.com/blog/normal_cdf_inverse/).
            For inverse transform sampling, it's explained [here](https://en.wikipedia.org/wiki/Inverse_transform_sampling)
         
            There's no particular reason for choosing transform, and it might have other better fit transforming function.
         */
        fileprivate func targetTierForPriority(_ priority: UInt) -> Int {
            /// Default relative priority is 0
            var tier: Int = 0
            if (priority > 0 && priority < UInt.max) {
                let p = Double(priority) / Double(UInt.max)
                let t = PriorityDispatchQueues.normalInverseCDF(p)
                /// t would be in [-6, 6], so transform it to [0, 12]
                tier = Int(t + 6)
                /// make sure tier is in range [0, 11]  (12 tiers)
                tier = min(tier, 11)
                tier = max(0, tier)
            }

            return tier
        }

        func getQueue(priority: UInt) -> DispatchQueue {
            if (currentNumOfQueues < maxNumOfQueues) {
                /// Create a queue and insert to the priority heap
                let queue = DispatchQueue(label: "awcorenetwork.priority.queue.\(priority)", attributes: [])
                let tier = targetTierForPriority(priority)
                if let queue = targetQueues[tier] {
                    queue.setTarget(queue: queue)
                }
                
                insertQueue(queue, priority: priority)
                return queue
            } else {
                /// pool is filled up and search for an existing queue with closest priority
                if !queuesSorted {
                    concurrentQueues.sort(by: { (a: (UInt, DispatchQueue),  b:(UInt, DispatchQueue)) -> Bool in
                        return a.0 < b.0
                    })
                }
                for (index, element) in concurrentQueues.enumerated() {
                    if (element.0 > priority) {
                        return index == 0 ? concurrentQueues[0].1 : concurrentQueues[index - 1].1
                    }
                }

                /// return last
                return concurrentQueues.last!.1
            }
        }

        //MARK: priority queue using heap
        fileprivate func insertQueue(_ queue: DispatchQueue, priority: UInt) {
            currentNumOfQueues += 1
            concurrentQueues.append((priority, queue))
        }

        //MARK: random number generator using inverse CDF function
        class func rationalApproximation(_ t: Double) -> Double {
            /**
                Abramowitz and Stegun formula 26.2.23.
                The absolute value of the error should be less than 4.5 e-4.
             */
            let c: [Double] = [2.515517, 0.802853, 0.010328]
            let d: [Double] = [1.432788, 0.189269, 0.001308]
            return t - ((c[2] * t + c[1]) * t + c[0]) / (((d[2] * t + d[1]) * t + d[0]) * t + 1.0);
        }

        class func normalInverseCDF(_ p: Double) -> Double {
            guard (p > 0.0 && p < 1.0) else {
                ///Invalid input
                fatalError("inverse CDF transform expects input between (0, 1)")
            }

            /**
                See article in the link for explanation of this section.
                The value is between (-6, 6)
             */
            if (p < 0.5) {
                /// F^-1(p) = - G^-1(p)
                return -rationalApproximation(sqrt(-2.0 * log(p)))
            } else {
                /// F^-1(p) = G^-1(1-p)
                return rationalApproximation(sqrt(-2.0 * log(1 - p)))
            }
        }
    }
    
}
