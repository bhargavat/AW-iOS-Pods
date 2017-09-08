//
//  Task.swift
//  SPAsync
//
//  Created by Joachim Bengtsson on 2014-08-14.
//  Copyright (c) 2014 ThirdCog. All rights reserved.
//

import Foundation

open class Task<T> : Cancellable, Equatable
{
	// MARK: Public interface: Callbacks
	
	open func addCallback(_ callback: @escaping ((T) -> Void)) -> Self
	{
		return addCallback(on:DispatchQueue.main, callback: callback)
	}
	
	open func addCallback(on queue: DispatchQueue, callback: @escaping ((T) -> Void)) -> Self
	{
		synchronized(self.callbackLock) {
			if self.isCompleted {
				if self.completedError == nil {
					queue.async {
						callback(self.completedValue!)
					}
				}
			} else {
				self.callbacks.append(TaskCallbackHolder(on: queue, callback: callback))
			}
		}
		return self
	}
	
	open func addErrorCallback(_ callback: @escaping ((NSError?) -> Void)) -> Self
	{
		return addErrorCallback(on:DispatchQueue.main, callback:callback)
	}
    
	open func addErrorCallback(on queue: DispatchQueue, callback: @escaping ((NSError?) -> Void)) -> Self
	{
		synchronized(self.callbackLock) {
			if self.isCompleted {
				if self.completedError != nil {
					queue.async {
						callback(self.completedError!)
					}
				}
			} else {
                let holder = TaskCallbackHolder(on: queue, callback: callback)
				self.errbacks.append(holder)
			}
		}
		return self
	}
	
	open func addFinallyCallback(_ callback: @escaping ((Bool) -> Void)) -> Self
	{
		return addFinallyCallback(on:DispatchQueue.main, callback:callback)
	}
	open func addFinallyCallback(on queue: DispatchQueue, callback: @escaping ((Bool) -> Void)) -> Self
	{
		synchronized(self.callbackLock) {
			if(self.isCompleted) {
				queue.async(execute: { () -> Void in
					callback(self.isCancelled)
				})
			} else {
				self.finallys.append(TaskCallbackHolder(on: queue, callback: callback))
			}
		}
		return self
	}
	
	
	// MARK: Public interface: Advanced callbacks
	
	open func then<T2>(_ worker: @escaping ((T) -> T2)) -> Task<T2>
	{
		return then(on:DispatchQueue.main, worker: worker)
	}
	open func then<T2>(on queue:DispatchQueue, worker: @escaping ((T) -> T2)) -> Task<T2>
	{
		let source = TaskCompletionSource<T2>();
		let then = source.task;
		self.childTasks.append(then)
		
		_=self.addCallback(on: queue) { (value: T) -> Void in
			let result = worker(value)
			source.completeWithValue(result)
		}
		
        _=self.addErrorCallback(on: queue) { (error: NSError?) -> Void in
			source.failWithError(error)
		}
        
		return then
	}
	
	open func then<T2>(_ chainer: @escaping ((T) -> Task<T2>)) -> Task<T2>
	{
		return then(on:DispatchQueue.main, chainer: chainer)
	}
	open func then<T2>(on queue:DispatchQueue, chainer: @escaping ((T) -> Task<T2>)) -> Task<T2>
	{
		let source = TaskCompletionSource<T2>();
		let chain = source.task;
		self.childTasks.append(chain)
		
		_=self.addCallback(on: queue) { (value: T) -> Void in
			let workToBeProvided : Task<T2> = chainer(value)
			
			chain.childTasks.append(workToBeProvided)
			source.completeWithTask(workToBeProvided)
		}
		
        _=self.addErrorCallback(on: queue){ (error: NSError?) -> Void in
			source.failWithError(error)
		}
		
		return chain;
	}
	
	/// Transforms Task<Task<T2>> into a Task<T2> asynchronously
	// dunno how to do this with static typing...
	/*public func chain<T2>() -> Task<T2>
	{
		return self.then<T.T>({(value: Task<T2>) -> T2 in
			return value
		})
	}*/
	
	
	// MARK: Public interface: Cancellation
	
	open func cancel()
	{
		var shouldCancel = false
		synchronized(callbackLock) { () -> Void in
			shouldCancel = !self.isCancelled
			self.isCancelled = true
		}
		
		if shouldCancel {
			self.source!.cancel()
			// break any circular references between source<> task by removing
			// callbacks and errbacks which might reference the source
			synchronized(callbackLock) {
				self.callbacks.removeAll()
				self.errbacks.removeAll()
				
				for holder in self.finallys {
					holder.callbackQueue.async(execute: { () -> Void in
						holder.callback(true)
					})
				}
				
				self.finallys.removeAll()
			}
		}
		
		for child in childTasks {
			child.cancel()
		}
		
	}
	
	open fileprivate(set) var isCancelled = false
	
	
	// MARK: Public interface: construction
	
	open class func performWork(on queue:DispatchQueue, _ work: @escaping (Void) -> T) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		queue.async {
			let value = work()
			source.completeWithValue(value)
		}
		return source.task
	}
	
	open class func fetchWork(on queue:DispatchQueue, _ work: @escaping (Void) -> Task<T>) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		queue.async {
			let value = work()
			source.completeWithTask(value)
		}
		return source.task

	}
	
	open class func delay(_ interval: TimeInterval, value : T) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(interval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) { () -> Void in
			source.completeWithValue(value)
		}
		return source.task
	}
	
	open class func completedTask(_ value: T) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		source.completeWithValue(value)
		return source.task
	}
	
	open class func failedTask(_ error: NSError!) -> Task<T>
	{
		let source = TaskCompletionSource<T>()
		source.failWithError(error)
		return source.task
	}
	
	
	// MARK: Public interface: other convenience
	
	open class func awaitAll(_ tasks: [Task]) -> Task<[Any]>
	{
		let source = TaskCompletionSource<[Any]>()
		
		if tasks.count == 0 {
			source.completeWithValue([])
			return source.task;
		}
		
		var values : [Any] = []
		var remainingTasks : [Task] = tasks
		
		var i : Int = 0
		for task in tasks {
			source.task.childTasks.append(task)
			weak var weakTask = task
			
			values.append(NSNull())
			_=task.addCallback(on: DispatchQueue.main, callback: { (value: Any) -> Void in
				values[i] = value
                remainingTasks.remove(at: remainingTasks.index(of: weakTask!)!)
				if remainingTasks.count == 0 {
					source.completeWithValue(values)
				}
			}).addErrorCallback(on: DispatchQueue.main, callback: { (error: NSError?) -> Void in
				if remainingTasks.count == 0 {
					// ?? how could this happen?
					return
				}

                remainingTasks.remove(at: remainingTasks.index(of: weakTask!)!)
				source.failWithError(error)
				for task in remainingTasks {
					task.cancel()
				}
				remainingTasks.removeAll()
				values.removeAll()

			}).addFinallyCallback(on: DispatchQueue.main, callback: { (canceled: Bool) -> Void in
				if canceled {
					source.task.cancel()
				}
			})
			
			i += 1;
		}
		return source.task;
	}

	
	// MARK: Private implementation
	
	var callbacks : [TaskCallbackHolder<(T) -> Void>] = []
	var errbacks : [TaskCallbackHolder<(NSError?) -> Void>] = []
	var finallys : [TaskCallbackHolder<(Bool) -> Void>] = []
	var callbackLock : NSLock = NSLock()
	
	var isCompleted = false
	var completedValue : T? = nil
	var completedError : NSError? = nil
	weak var source : TaskCompletionSource<T>?
	var childTasks : [Cancellable] = []
	
	internal init()
	{
		// temp
	}
	
	internal init(source: TaskCompletionSource<T>)
	{
		self.source = source
	}
	
	open func completeWithValue(_ value: T)
	{
		assert(self.isCompleted == false, "Can't complete a task twice")
		if self.isCompleted {
			return
		}
		
		if self.isCancelled {
			return
		}
		
		synchronized(callbackLock) {
			self.isCompleted = true
            self.completedValue = value
            let cancelled = self.isCancelled
            while self.callbacks.count > 0 {
                let holder = self.callbacks.removeFirst()
                let queue = holder.callbackQueue
                queue.async {
                    holder.callback(value)
                }
            }

            while self.finallys.count > 0 {
                let holder = self.finallys.removeFirst()                
                let queue = holder.callbackQueue
                queue.async {
                    holder.callback(cancelled)
                }

            }
			self.errbacks.removeAll()
		}

	}
	open func failWithError(_ error: NSError!)
	{
		assert(self.isCompleted == false, "Can't complete a task twice")
		if self.isCompleted {
			return
		}
		
		if self.isCancelled {
			return
		}

		synchronized(callbackLock) {
			self.isCompleted = true
			self.completedError = error
			let copiedErrbacks = self.errbacks
			let copiedFinallys = self.finallys
			
			for holder in copiedErrbacks {
				holder.callbackQueue.async {
					if !self.isCancelled {
						holder.callback(error)
					}
				}
			}
			for holder in copiedFinallys {
				holder.callbackQueue.async {
					holder.callback(self.isCancelled)
				}
			}

			self.callbacks.removeAll()
			self.errbacks.removeAll()
			self.finallys.removeAll()
		}

	}
}

public func ==<T>(lhs: Task<T>, rhs: Task<T>) -> Bool
{
	return lhs === rhs
}

// MARK:
open class TaskCompletionSource<T> : NSObject {
    open lazy var task: Task<T> = Task<T>(source: self)

	public override init()
	{
        super.init()
	}

	fileprivate var cancellationHandlers : [(() -> Void)] = []

	/** Signal successful completion of the task to all callbacks */
	open func completeWithValue(_ value: T)
	{
		self.task.completeWithValue(value)
	}
	
	/** Signal failed completion of the task to all errbacks */
	open func failWithError(_ error: NSError!)
	{
		self.task.failWithError(error)
	}

	/** Signal completion for this source's task based on another task. */
	open func completeWithTask(_ task: Task<T>)
	{
        _=task.addCallback(on: DispatchQueue.global(qos: DispatchQoS.QoSClass.default)) {
            (v: T) -> Void in
            self.task.completeWithValue(v)
        }.addErrorCallback(on: DispatchQueue.global(qos: DispatchQoS.QoSClass.default)) {
            (e: NSError?) -> Void in
            self.task.failWithError(e)
        }

	}

	/** If the task is cancelled, your registered handlers will be called. If you'd rather
    poll, you can ask task.cancelled. */
	open func onCancellation(_ callback: @escaping () -> Void)
	{
		synchronized(self) {
			self.cancellationHandlers.append(callback)
		}
	}
	
	func cancel() {
		var handlers: [()->()] = []
		synchronized(self) { () -> Void in
			handlers = self.cancellationHandlers
		}
		for callback in handlers {
			callback()
		}
	}
}

protocol Cancellable {
	func cancel() -> Void
}

class TaskCallbackHolder<T>
{
	init(on queue:DispatchQueue, callback: T) {
		callbackQueue = queue
		self.callback = callback
	}
	
	var callbackQueue : DispatchQueue
	var callback : T
}

func synchronized(_ on: AnyObject, closure: () -> Void) {
	objc_sync_enter(on)
	closure()
	objc_sync_exit(on)
}

func synchronized(_ on: NSLock, closure: () -> Void) {
	on.lock()
	closure()
	on.unlock()
}

func synchronized<T>(_ on: NSLock, closure: () -> T) -> T {
	on.lock()
	let r = closure()
	on.unlock()
	return r
}
