//
//  PinnedSSLAuthChallengeHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWNetwork
import AWCrypto
import AWError
import Foundation

extension SDKContext {

    fileprivate func pinnedCertificates(host: String) -> [String]? {
        /*
         let hosts = [
         "apple.com" : ["1"],
         "developer.apple.com" : ["2"],
         "iphone.apple.com": ["3"],
         "ios.developer.apple.com": ["4"],
         "osx.developer.apple.com": ["5"],
         "tvos.developer.apple.com": ["6"]
         ]

         //apple.com ==> apple.com
         //developer.apple.com => developer.apple.com
         //iphone.apple.com => iphone.apple.com

         //developer.apple.com => developer.apple.com
         //ios.developer.apple.com => ios.developer.apple.com
         //osx.developer.apple.com => osx.developer.apple.com
         //watch.developer.apple.com => developer.apple.com
         //google => no match
         //iphone.developer.apple.com => developer.apple.com
         */

        guard let storedKeys = self.SSLTrustPublicKeys else {
            return nil
        }

        let allHosts = storedKeys.keys.sorted { $0.characters.count < $1.characters.count }

        var apropriateHost: String? = nil

        for pinnedHost in allHosts {
            if host == pinnedHost {
                apropriateHost = pinnedHost
                break
            }

            if host.hasSuffix(pinnedHost) {
                apropriateHost = pinnedHost
            }
        }

        guard let pinninghost = apropriateHost else {
            log(error: "Could not find pinned keys for given host: \(host)")
            return nil
        }

        return storedKeys[pinninghost]
    }
}

class ServerTrustAuthenticationHandler: AbstractAuthenticationChallengeHandler {

    var context: SDKContext
    init(context: SDKContext ) {
        self.context = context
    }

    var shouldHandleChallenges: Bool {
        return true
    }

    /// used within the can Handle ProtectionSpace method.
    func validate(protectionSpace: URLProtectionSpace) -> Bool {
        /// are there any credentials for the URL in protectionSpace?
        guard
            let pinnedCertificates = self.context.pinnedCertificates(host: protectionSpace.host)
        else {
            return false
        }

        return pinnedCertificates.count > 0
    }
    
    /// returns a URLCredential if any exists for the host in the given protectionSpace.
    func credential(forProtectionSpace: URLProtectionSpace) -> URLCredential? {
        let protectionSpace = forProtectionSpace
        guard let serverTrust = protectionSpace.serverTrust else {
            return nil
        }
        let operation = ServerTrustValidationOperation(context: self.context, trust: serverTrust, host: protectionSpace.host)
        ServerTrustAuthenticationHandler.ServerTrustValidationQueue.addOperations([operation], waitUntilFinished: true)
        return operation.validatedCredential
    }

    /// returns a URLCredential with Completion Handler if any exists for the host in the given protectionSpace.
    func credential(forProtectionSpace: URLProtectionSpace, completion: @escaping (URLCredential?) -> Void) {
        let protectionSpace = forProtectionSpace
        guard let serverTrust = protectionSpace.serverTrust else {
            completion(nil)
            return
        }

        let operation = ServerTrustValidationOperation(context: self.context, trust: serverTrust, host: protectionSpace.host)
        operation.credentialRefreshBlock = completion
        ServerTrustAuthenticationHandler.ServerTrustValidationQueue.addOperation(operation)
    }

    /// overrides the AbstractAuthenticationChallengeHandler method due to a difference in SSL Pinning challenge handler.
    func canHandle(protectionSpace: URLProtectionSpace) -> Bool {
        log(info: "Checking if can handle protection space given.")
        /// is Challenge asking for us to validate server trust?
        return self.validate(protectionSpace: protectionSpace)
    }

    static let ServerTrustValidationQueue =  { () -> OperationQueue in
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}

fileprivate class ServerTrustValidationOperation: Foundation.Operation {

    var validatedCredential: URLCredential? = nil
    let serverTrust: SecTrust
    let host: String
    var context: SDKContext

    var credentialRefreshBlock: (URLCredential?) -> Void = { (_) in }

    init(context: SDKContext, trust: SecTrust, host: String) {
        self.context = context
        self.serverTrust = trust
        self.host = host
    }

    override func main() {

        if self.evaluateHostWithCurrentServerTrust() {
            log(info: "Trusting Server using stored pinned keys.")
            log(debug: "Trusting Server now")
            self.validatedCredential = URLCredential(trust: self.serverTrust)
            self.credentialRefreshBlock(self.validatedCredential)
            self.finishOperation()
            return
        }


        self.reportFailureToServer()
        guard self.canRefreshServerTrust() else {
            log(error: "Server Not Trusted, and will not refresh pinned keys as last refresh is under minimum black-out time.")
            self.credentialRefreshBlock(nil)
            self.finishOperation()
            return
        }

        let operation = ServerTrustValidationOperation(context: self.context, trust: self.serverTrust, host: self.host)
        operation.credentialRefreshBlock = self.credentialRefreshBlock
        self.finishOperation()

        log(info: "Server Not Trusted, trying quick refresh of pinned keys and re-validation.")
        /// If haven't tried to Refresh Pinned Certs for Failed verification in last 5 minutes
        /// Try to Quickly update pinned certs and re-evaluate...
        self.refreshPinnedSSLCertificates { (refreshed) in
            guard refreshed else {
                log(info: "Pinned SSL Certificates Refresh was not successful.")
                operation.credentialRefreshBlock(nil)
                return
            }

            ServerTrustAuthenticationHandler.ServerTrustValidationQueue.addOperation(operation)
        }
    }

    private let minimumTimeIntervalBetweenServerTrustRefresh = TimeInterval(5.secondsFromMinutes) // 5 minutes
    static var serverTrustCredentialsRefreshTimestamp: Date? = nil

    private func canRefreshServerTrust() -> Bool {
        let lastFetchTimestamp = ServerTrustValidationOperation.serverTrustCredentialsRefreshTimestamp?.timeIntervalSince1970 ?? 0
        return (lastFetchTimestamp + minimumTimeIntervalBetweenServerTrustRefresh ) <= Date().timeIntervalSince1970
    }

    private func reportFailureToServer() {
        // Report failed challenge to server...

        guard let config = self.context.consoleServicesConfig else {
            log(error: "Missing Required information to report Server Trust Validation Failure.")
            return
        }

        let airWatchServerURL = config.airWatchServerURL
        let deviceId = config.deviceId
        //TODO: Replace this to use Device services call rather than using it directly as endpoint.
        let isSendingReport = PinnedCertValidationFailureEndpoint.reportCertValidationFailureToServer(awServerUrl:airWatchServerURL, onDeviceId: deviceId, forChallengedHost: self.host)
        if isSendingReport == false {
            log(error: "Could not report cert pinning validation error for host: \(host)")
        }

        log(warning: "Tried to report Server Trust Validation Failure to server.")
    }

    private func evaluateHostWithCurrentServerTrust() -> Bool {

        guard let publicKeys = self.context.pinnedCertificates(host: self.host) else {
            log(error: "Could not find pinned keys for given host: \(host)")
            return false
        }

        guard let serverCert = SecTrustGetCertificateAtIndex(self.serverTrust, 0) else {
            return false
        }

        let serverCertData = SecCertificateCopyData(serverCert) as Data

        let certificate = try? Certificate(certificateData: serverCertData, format: .der)

        guard let publicKey = certificate?.keyPair?.publicKey else {
            return false
        }

        let publicKeyData = Data.publicKeyData(publicKey)!
        let mypublicKey = publicKeyData.hexadecimalString

        let trustServer = publicKeys.filter { mypublicKey.contains($0.lowercased()) }.count > 0
        return trustServer
    }

    private func refreshPinnedSSLCertificates(completion: (Bool) -> Void) {

        guard
            let config = self.context.consoleServicesConfig,
            let url = URL(string: config.airWatchServerURL),
            let deviceServicesHost = url.host
        else {
            log(error: "Tried to Refresh Pinned Certs without having proper server URL.")
            completion(false)
            self.finishOperation()
            return
        }

        ServerTrustValidationOperation.serverTrustCredentialsRefreshTimestamp = Date()

        /// We may need couple of operations to refresh complete set of SSL pins.
        /// If the current refresh is due to Server Trust Validation failure on a device Services URL, We need to refetch Device Services pinned SSL Certificates from Auto Discovery/Trust Service and rest of the Pins from Device Services.

        /// If the current refresh is due to Server Trust validation failure on non Device Services URL, We need to refetch Only SSL Pins from Device Services.

        /// refreshOp will refresh the pins for DS, if the DS connection just failed to validate agasint current pinned keys.
        /// refreshOp2 will refresh full SSL Pin Set, but only if we already have HMAC Token, and/or after refreshOp has completed.


        let failedOnAirWatchServerURL = self.host.lowercased() == deviceServicesHost.lowercased()
        let userDidLogin = (self.context.applicationIdentity?.authorization?.hmacToken != nil)
        var retrievedPinnedSSLCerts = false

        if failedOnAirWatchServerURL {
            let refreshOp = PinningCertificateFetchOperation(sdkController: AWController.sharedInstance, presenter: AWController.sharedInstance.presenter, dataStore: self.context)
            SDKOperationQueue.workerQueue.addOperations([refreshOp], waitUntilFinished: true)
            if refreshOp.operationCompletedSuccessfully {
                self.context.SSLTrustPublicKeys = refreshOp.dataStore.SSLTrustPublicKeys
                retrievedPinnedSSLCerts = true
            }
        }

        if userDidLogin {
            let refreshOp2 = PostEnrollmentSSLPinFetchOperation(sdkController: AWController.sharedInstance, presenter: AWController.sharedInstance.presenter, dataStore: self.context)
            SDKOperationQueue.workerQueue.addOperations([refreshOp2], waitUntilFinished: true)
            if refreshOp2.operationCompletedSuccessfully {
                self.context.SSLTrustPublicKeys = refreshOp2.dataStore.SSLTrustPublicKeys
                retrievedPinnedSSLCerts = true
            }
        }

        completion(retrievedPinnedSSLCerts)
        
    }

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

    func finishOperation() {
        self.isExecuting = false
        self.isFinished = true
    }
}
