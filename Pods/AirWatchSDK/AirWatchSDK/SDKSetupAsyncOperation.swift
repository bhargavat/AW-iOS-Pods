//
//  SDKSetupAsyncOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

extension NSNotification.Name {
    internal static let sdkContextDidChange = NSNotification.Name("SDKContextDidChange")
}

internal enum NotificationObjectKeys: String {
    case SDKContext   =   "sdkcontext"
}
internal class SDKOperation: Operation {

    var dataStore: SDKContext
    var directDependency: SDKOperation? = nil

    let sdkController: AWController
    let presenter: SDKQueuePresenter
    var operationCompletedSuccessfully = false

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        self.sdkController = sdkController
        self.presenter = presenter
        self.dataStore = dataStore
        super.init()
        self.name = String(describing: type(of: self))
        NotificationCenter.default.addObserver(self, selector:  #selector(updateContext(notification:)), name: NSNotification.Name.sdkContextDidChange, object: nil)
    }
    
    deinit {
        cleanup()
    }

    func createDependencyChain<T: SDKOperation>(_ operationTypes: [T.Type], dataStore: SDKContext? = nil) -> [T] {
        let operationDataStore = dataStore ?? self.dataStore
        var previousOperation: SDKOperation? = nil
        let operations = operationTypes.map { (SDKOperationType) -> T in
            let operation = SDKOperationType.init(sdkController: sdkController, presenter: presenter, dataStore: operationDataStore)
            if let previousOperation = previousOperation {
                operation.directDependency = previousOperation
                operation.addDependency(previousOperation)
            }
            previousOperation = operation
            return operation
        }
        return operations
    }

    func createOperationGroup<T: SDKOperation>(_ operationTypes: [T.Type], dataStore: SDKContext? = nil) -> [T] {
        let operationDataStore = dataStore ?? self.dataStore
        let operations = operationTypes.map { (SDKOperationType) -> T in
            let operation = SDKOperationType.init(sdkController: sdkController, presenter: presenter, dataStore: operationDataStore)
            return operation
        }
        return operations
    }
    var startTime = CFTimeInterval(0)
    var completionTime = CFTimeInterval(0)


    override func main() {

        if let dependecy = self.directDependency {
            guard dependecy.operationCompletedSuccessfully else {
                log(error: "\(self.name ?? "Operation name is not set and") is being cancelled due to failure of \(dependecy.name ?? "a dependency which has no name set" )")
                self.operationCompletedSuccessfully = false
                self.finishOperation()
                return
            }
        }

        guard !self.isCancelled  else {
            self.operationCompletedSuccessfully = false
            log(error: "\(self.name ?? "Operation name is not set and") is being cancelled due to the reason that the operation was canclled from outside")
            return
        }

        let failedDependencies = self.dependencies.filter { $0.isCancelled }
        guard failedDependencies.count == 0 else {
            log(error: "\(String(describing: type(of: self))) has some failed dependencies. Cancelling current Operation")
            self.operationCompletedSuccessfully = false
            self.cancel()
            return
        }
        self.startTime = CACurrentMediaTime()
        self.startOperation()
    }
    
    final func updateContext(notification: Notification) {
        guard let sdkContext = notification.userInfo?[NotificationObjectKeys.SDKContext.rawValue] as? SDKContext
            else {
            log(error: "did not recieve context in updateContext notification")
            return
        }
        self.dataStore = sdkContext
        
    }

    final func markOperationComplete() {
        self.completionTime = CACurrentMediaTime()
        log(debug: "Total Time for \(self.name ?? "Name not set"): \(self.completionTime - self.startTime)")
        self.operationCompletedSuccessfully = true
        self.finishOperation()
    }

    final func markOperationFailed() {
        self.completionTime = CACurrentMediaTime()
        log(debug: "Total Time for \(self.name ?? "Name not set"): \(self.completionTime - self.startTime)")


        log(error: "Operation Failed: \(self.name ?? "Name not set") ")
        self.operationCompletedSuccessfully = false
        self.finishOperation()
    }

    override func cancel() {
        super.cancel()
        self.operationCompletedSuccessfully = false
        self.cleanup()
    }

    func startOperation() { fatalError("This should be overriden by subclasses") }

    func finishOperation() {
        self.cleanup()
        log(info: "Finished Operation: \(self.name ?? "Name not set")")
    }
    
    final func cleanup() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.sdkContextDidChange, object: nil)
    }

}

internal class SDKSetupInlineOperation: SDKOperation { }
internal class SDKSetupAsyncOperation: SDKOperation {
    // MARK: overriding existing properties from NSOperation
    private var _asynchronous: Bool = true
    override final var isAsynchronous: Bool {
        get { return _asynchronous }
        set { _asynchronous = newValue }
    }

    private var _executing: Bool = false
    override final var isExecuting: Bool {
        get { return _executing }
        set {
            if _executing != newValue {
                willChangeValue(forKey: "isExecuting")
                _executing = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
    }

    private var _finished: Bool = false
    override final var isFinished: Bool {
        get {
            return _finished
        }
        set {
            if _finished != newValue {
                willChangeValue(forKey: "isFinished")
                _finished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }

    override final func start() {
        self.main()
    }

    override func finishOperation() {
        self.isExecuting = false
        self.isFinished = true
    }
}
