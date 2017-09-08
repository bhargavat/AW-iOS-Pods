//
//  CTLSessionDelegate.swift
//  AWCoreNetwork
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import Alamofire


/**
    The delegate to allow high level interacting with core networking layer.

    The reason not to expose directly NSURLSessionDelegate protocol is allow best using of closures. This
    duplicates `SessionDelegate` from Alamofire, but it would create a good insulation between application and
    the underlying wrapped HTTP library.
 */

public typealias CTLSessionChallengeHandlingCompletion = (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
public typealias CTLSessionDidReceiveChallengeWithCompletion = ((CTLSessionFetcher, URLAuthenticationChallenge, @escaping CTLSessionChallengeHandlingCompletion) -> Void)
public typealias CTLSessionWillPerformHTTPRedirectionWithCompletion = ((CTLSessionFetcher, HTTPURLResponse, URLRequest, (URLRequest?) -> Void) -> Void)
//MARK: TODO: more delegate functions

public protocol CTLSessionDelegateProtocol {
    
    var sessionDidReceiveChallengeWithCompletion:  CTLSessionDidReceiveChallengeWithCompletion? { get set }
    
    var sessionWillPerformHTTPRedirectionWithCompletion: CTLSessionWillPerformHTTPRedirectionWithCompletion? { get set }
}


/// Default `CTLSessionDelegate` struct
public struct CTLSessionDelegate: CTLSessionDelegateProtocol {
    public var sessionDidReceiveChallengeWithCompletion:  CTLSessionDidReceiveChallengeWithCompletion? = nil
    public var sessionWillPerformHTTPRedirectionWithCompletion: CTLSessionWillPerformHTTPRedirectionWithCompletion? = nil
}

public class AWCTLSessionDelegate: SessionDelegate  {

    override public var taskDidReceiveChallengeWithCompletion: ((URLSession, URLSessionTask, URLAuthenticationChallenge, (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?  {
        didSet{
            self.taskDidReceiveChallengeWithEscapingCompletion = {[weak self] (session, task, challenge, completion) in
                self?.taskDidReceiveChallengeWithCompletion?(session, task, challenge, completion)
            }
        }
    }

    var taskDidReceiveChallengeWithEscapingCompletion: ((URLSession, URLSessionTask, URLAuthenticationChallenge, @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void)?

    override public func urlSession( _ session: URLSession,
                                     task: URLSessionTask,
                                     didReceive challenge: URLAuthenticationChallenge,
                                     completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
    {
        guard self.taskDidReceiveChallengeWithEscapingCompletion == nil else {
            self.taskDidReceiveChallengeWithEscapingCompletion?(session, task, challenge, completionHandler)
            return
        }

        super.urlSession(session, task: task, didReceive: challenge, completionHandler: completionHandler)
    }
    
}
