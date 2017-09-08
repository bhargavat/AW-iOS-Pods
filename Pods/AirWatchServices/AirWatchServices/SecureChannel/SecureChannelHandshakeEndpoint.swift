//
//  SecureChannelHandshakeEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import AWCrypto
import AWError
import AWCMWrapper
import Foundation


private enum SecureChannelHandshakeState {
    case stateIdle
    /**
        Associate the handshake task object with the state so that when
        someone tries to do handshake while there's one handshake is on
        going then it simply registers itself as an observer to be notified
        once the task is completed or failed.
     */
    case stateHandshake(CTLTask<Void>)

    var handshakeTask: CTLTask<Void>? {
        switch(self) {
        case .stateIdle:
            return nil
        case .stateHandshake(let task):
            return task
        }
    }
}


internal class SecureChannelHandshakeEndpoint: DeviceServicesEndpoint {
    fileprivate var secureChannelConfigurationManager: SecureChannelConfigurationManager? = nil
    fileprivate static var states: [String: SecureChannelHandshakeState] = Dictionary()

    fileprivate static let syncQueue = DispatchQueue(label: "AirWatchServices.SecureChannel.Handshake.SyncQueue", attributes: [])

    fileprivate static func with(_ queue: DispatchQueue, f: () -> Void) { queue.sync(execute: f) }

    fileprivate let challenge = Data.randomData(count: 16).base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
    
    /// This endpoint is only used for secure channel handshake
    let kSecureChannelConnectionEndpoint = "/DeviceServices/ConnectionEndpoint.aws/v2"

    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol? = nil) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = kSecureChannelConnectionEndpoint
    }

    convenience init(config: DeviceServicesConfiguration, secureChannelConfigurationMananger: SecureChannelConfigurationManager, validator: CTLResponseValidationProtocol? = nil) {
        self.init(config: config, authorizer: nil, validator: validator)
        self.secureChannelConfigurationManager = secureChannelConfigurationMananger
    }

    fileprivate func resetHandshakeState(_ identifier: String) {
        SecureChannelHandshakeEndpoint.with(SecureChannelHandshakeEndpoint.syncQueue) {
            SecureChannelHandshakeEndpoint.states[identifier] = .stateIdle
        }
    }

    fileprivate func startHandshakeAtomically(_ on: DispatchQueue, identifier: String) {
        /// simulate classic C compareAndSwap atomic operation to synchronize the state access
        SecureChannelHandshakeEndpoint.with(SecureChannelHandshakeEndpoint.syncQueue) {
            switch SecureChannelHandshakeEndpoint.states[identifier] {
            case .none:
                SecureChannelHandshakeEndpoint.states[identifier] = .stateIdle
                fallthrough
            case .some(.stateIdle):
                let handshakeTask = self.handshakeOnce(onQueue: on, identifier: identifier)
                SecureChannelHandshakeEndpoint.states[identifier] = .stateHandshake(handshakeTask)
            default: break
            }
        }
    }

    fileprivate func checkin(_ identifier: String) -> CTLTask<CTLPlistObject>? {
        let checkInSvc = CTLService()
        checkInSvc.serviceURL = URL(string: "\(self.config.airWatchServerURL)/\(self.kSecureChannelConnectionEndpoint)")

        let query = CTLQuery()
        query.addtionalHTTPHeaders = ["Content-Type": "text/html",
                                      "Accept": "text/html"]
        query.httpMethod = "GET"
        query.urlQueryParameters = ["uid": self.config.deviceId,
                                    "deviceType": self.config.deviceType]
        query.shouldSkipAuthorization = true
        return checkInSvc.execute(query: query) { (rsp: CTLPlistObject?, error: NSError?) in
            if let plist = rsp?.PLIST {
                log(verbose: "Checkin successful with response plist: \(plist.description)")
            } else {
                log(verbose: "Checkin failed with error: \(error?.debugDescription ?? "Both Error and CTLPlistObject.PLIST were nil")")
            }
        }
    }

    fileprivate func generateDeviceKeyPairFromPlist(_ plist: CTLPlistObject, identifier: String) -> CTLTask<(pubCert: Data, srvCert: Data, checkInURL: String)> {
        let signCertTask = CTLTask<(pubCert: Data, srvCert: Data, checkInURL: String)>()

        guard let plistData = plist.PLIST as? [String: AnyObject],
            let srvCertData = plistData["certificate"] as? Data,
            let checkinURLString = plistData["checkInURL"] as? String else {
                signCertTask.failWithError(AWError.SDK.SecureChannel.General.incompleteCheckinResponse.error)
                return signCertTask
        }
        
        guard let secureChannelConfigurationManager = self.secureChannelConfigurationManager else {
            signCertTask.failWithError(AWError.SDK.SecureChannel.General.incompleteCheckinResponse.error)
            return signCertTask
        }

        do {
            try secureChannelConfigurationManager.setSecureChannelServerCertificate(forHost: identifier,
                                                                                    unverifiedServerCertificateData: srvCertData)
        } catch let err {
            signCertTask.failWithError(err as NSError)
            return signCertTask
        }

        let signedDeviceCertData = secureChannelConfigurationManager.secureChannelClientCertificate(forHost: identifier)

        signCertTask.completeWithValue((pubCert: signedDeviceCertData, srvCert: srvCertData, checkInURL: checkinURLString))
        return signCertTask
    }

    fileprivate func constructPayload(publicDeviceCert pubCert: Data, serverCert: Data, checkInURL: String) -> CTLTask<(checkInURL: String, payload: Data)> {
        let constructPayloadTask = CTLTask<(checkInURL: String, payload: Data)>()

        let plist = NSMutableDictionary()
        plist.setValue(pubCert.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters), forKey: "certificate")
        plist.setValue("1.1", forKey: "version")
        plist.setValue(self.config.bundleId, forKey: "bundleId")
        plist.setValue(self.challenge, forKey: "challenge")

        if let xmlData = try? plist.xmlPlistData(),
           let payload = AWCMSCryptor.encrypt(xmlData, certificateData: serverCert) {
            let exchgPlist = NSMutableDictionary()
            exchgPlist.setValue(payload.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters), forKey: "payload")
            exchgPlist.setValue(self.config.deviceId, forKey: "uid")
            exchgPlist.setValue(self.config.deviceType, forKey: "deviceType")

            if let exchgData = try? exchgPlist.xmlPlistData() {
                constructPayloadTask.completeWithValue((checkInURL: checkInURL, payload: exchgData))
            } else {
                constructPayloadTask.failWithError(AWError.SDK.SecureChannel.General.plistDataParsingError.error)
            }
        } else {
            constructPayloadTask.failWithError(AWError.SDK.SecureChannel.General.plistDataParsingError.error)
        }
        return constructPayloadTask
    }

    fileprivate func exchangeKey(_ on: DispatchQueue, checkInURL: String, payload: Data) -> CTLTask<CTLPlistObject> {
        let request = NSMutableURLRequest()
        if let url = CTLUtilities.URLWithString(checkInURL, queryParameters: nil) {
            request.url = url
        }
        request.cachePolicy = URLRequest.CachePolicy.reloadIgnoringLocalCacheData
        request.timeoutInterval = 5
        request.setValue("", forHTTPHeaderField: "Content-Type")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.httpMethod = "POST"
        request.httpBody = payload
        let fetcher = CTLSessionFetcher.fetcherWithRequest(request as URLRequest)
        
        guard let task = fetcher.beginFetch(on: on, mayAuthorize: false, { (rsp: CTLPlistObject?, error: NSError?) in
            ///Leave the work to the following task
        }) else {
            log(error: "The task is empty")
            return CTLTask<CTLPlistObject>() }
        return task
    }

    fileprivate func handshakeOnce(onQueue on: DispatchQueue, identifier: String) -> CTLTask<Void> {

        let shellTask = CTLTask<Void>()
        
        guard let secureChannelConfigurationManager = self.secureChannelConfigurationManager else {
            log(error: "the secureChannelConfigurationManager is nil")
            return shellTask
        }

        /// Generate client pub/private key pair at the background
        on.async {
            _ = secureChannelConfigurationManager.secureChannelClientCertificate(forHost: identifier)
        }

        guard let handshakeTask = checkin(identifier)?.then(on: on, chainer: {
            (plist: CTLPlistObject) -> Task<(pubCert: Data, srvCert: Data, checkInURL: String)> in
            return self.generateDeviceKeyPairFromPlist(plist, identifier: identifier)
        }).then(on: on, chainer: {
            (pubCert: Data, srvCert: Data, checkInURL: String) -> Task<(checkInURL: String, payload: Data)> in
            return self.constructPayload(publicDeviceCert: pubCert, serverCert: srvCert, checkInURL: checkInURL)
        }).then(on: on, chainer: {
            (checkInURL: String, payload: Data) -> Task<CTLPlistObject> in
            return self.exchangeKey(on, checkInURL: checkInURL, payload: payload)
        }) else {
            shellTask.failWithError(AWError.SDK.SecureChannel.General.startCheckinError.error)
            return shellTask
        }

        _ = handshakeTask.addCallback(on: on, callback: { (plist: CTLPlistObject) in
            
            guard let ack = plist.PLIST as? [String: AnyObject]  else {
                shellTask.failWithError(AWError.SDK.SecureChannel.General.invalidResponse.error)
                return
            }
            log(verbose: "Successfully handshake with the server with response data: \(ack)")
            
            let ackPayload = ack["ack"] as! Data
            let privKey = secureChannelConfigurationManager.secureChannelClientPrivateKey(forHost: identifier)
            let privateKeyPassphrase = secureChannelConfigurationManager.secureChannelClientPrivateKeyPassphrase(forHost: identifier)
            let srvCert = secureChannelConfigurationManager.secureChannelServerCertificate(forHost: identifier)
            
            guard let payload = AWCMSCryptor.decrypt(ackPayload, privateKeyData: privKey, password: privateKeyPassphrase) else {
                shellTask.failWithError(AWError.SDK.SecureChannel.General.decryptionFailure.error)
                return
            }

            guard let verifiedPayload = AWCMSCryptor.verifyCMSPayloadData(payload,
                                                                              withCertificateData: srvCert,
                                                                              rootCertificate: nil) else {
                shellTask.failWithError(AWError.SDK.SecureChannel.General.signatureVerificationFailure.error)
                return
            }

            /// Verify challenge
            do {
                let payloadDict = try NSDictionary.dictionaryFromPlistData(verifiedPayload)
                if ((payloadDict["challenge"] as! String) == self.challenge) {
                    secureChannelConfigurationManager.setSecureChannelURL(forHost: identifier,
                        channelURL: NSURL(string:(payloadDict["channelUrl"] as! String))! as URL)
                    //Reset the global handshake state so that re-handshake could be started on demand.
                    //Only one handshake would happen at a single time.
                    self.resetHandshakeState(identifier)
                    shellTask.completeWithValue()
                    
                } else {
                    shellTask.failWithError(AWError.SDK.SecureChannel.General.challengeNotMatch.error)
                }
            } catch let err {
                shellTask.failWithError(err as NSError)
            }
        }).addErrorCallback(on: on) { err in
            guard let nsErr: NSError = err else { return }
            shellTask.failWithError(nsErr)
        }

        return shellTask
    }

    internal func handshake(onQueue on: DispatchQueue, identifier: String) -> CTLTask<Void>? {
        startHandshakeAtomically(on, identifier: identifier)

        let handshakeTask = SecureChannelHandshakeEndpoint.states[identifier]?.handshakeTask
        _ = handshakeTask?.addErrorCallback(on: on) { _ in
            /// Reset state to idle
            self.resetHandshakeState(identifier)

        }
        return handshakeTask
    }
}
