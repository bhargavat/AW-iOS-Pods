//
//  SecureChannelAuthorizer.swift
//  AWSecureChannel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import AWHelpers
import AWCrypto
import AWError
import AWCMWrapper
import Foundation

public class SecureChannelAuthorizer: CTLAuthorizationProtocol {
    private static let SecureChannelConfigurationSyncQueue = DispatchQueue(label: "airwatch_services.secure_channel.authorizer.sync_queue")
    private static let SecureChannelConfigurationWorkQueue = DispatchQueue(label: "airwatch_services.secure_channel.authorizer.sync_queue", attributes: [])
    
    let configurationManager: SecureChannelConfigurationManager
    let deviceConfig: DeviceServicesConfiguration
    let handshakeEndpoint: SecureChannelHandshakeEndpoint
    static let authorizerSemaphore = DispatchSemaphore(value: 1)
    
    private func block() {
        SecureChannelAuthorizer.authorizerSemaphore.wait()
    }
    
    private func unblock() {
        SecureChannelAuthorizer.authorizerSemaphore.signal()
    }
    
    init(deviceConfig: DeviceServicesConfiguration, configurationManager: SecureChannelConfigurationManager) {
        self.deviceConfig = deviceConfig
        self.configurationManager = configurationManager
        self.handshakeEndpoint = SecureChannelHandshakeEndpoint(config: deviceConfig, secureChannelConfigurationMananger: configurationManager)
    }

    public func authorize(request: NSMutableURLRequest?, on: DispatchQueue?) -> CTLTask<Void>? {
        guard let request = request,
            let url = request.url,
            let identifier = url.host else {
                return nil
        }
        
        self.block()
        let shellTask = CTLTask<Void>()
        let authorizationBlock = {
            if self.canSignAndEncrypt(request: request) {
                log(debug: "We have Credentials for Signing Secure Channel Request: \(request)")
                
                if self.signAndEncrypt(request: request) {
                    log(debug: "Successfully Signed Secure Channel Request:\(request)")
                    shellTask.completeWithValue()
                    self.unblock()
                    return
                }
            }
            
            if self.validateCertificateForRequest(request: request) == false {
                log(error: "Secure Channel Certificate validation failed for request: \(request)")
                log(error: "Resetting Credentials and will perform cert exchange")
                self.configurationManager.resetClientCredentials(forHost: identifier)
            }
            
            let workQueue = SecureChannelAuthorizer.SecureChannelConfigurationWorkQueue
            _ = self.handshakeEndpoint
                .handshake(onQueue: workQueue, identifier: identifier)?
                .addCallback(on: workQueue) { [weak self] in
                    guard let weakself = self else { return }

                    log(debug: "Handshake completed, Will check if we can sign and encrypt the request")
                    if  weakself.signAndEncrypt(request: request) {
                        log(debug: "We are able to sign and encrypt the request successfully")
                        shellTask.completeWithValue()
                         weakself.unblock()
                        return
                    }
                    
                    log(error: "Can not setup proper secure channel information, even after retrying Checking With Secure Channel.")
                    log(error: "Clearing secure channel storage and re-checkin will be performed upon next reqeust")
                    /// Wipe secure channel storage and re-handshake upon next request
                     weakself.configurationManager.clearAll()
                    shellTask.failWithError(AWError.SDK.SecureChannel.General.signAndEncryptionFailure.error)
                     weakself.unblock()
                }.addErrorCallback(on: workQueue) { [weak self] err in
                    guard let weakself = self else { return }

                    /// reset client credentials if not valid
                    log(error: "Last try to checkin Errored \(err.debugDescription).")
                    log(error: "Resetting secure channel Credentials, Can not authorize request for secure channel endpoint.")
                    if weakself.validateCertificateForRequest(request: request) == false {
                        weakself.configurationManager.resetClientCredentials(forHost: identifier)
                    }
                    shellTask.failWithError(err)
                    weakself.unblock()
                }
        }
        
        DispatchQueue.global().async {
            SecureChannelAuthorizer.SecureChannelConfigurationSyncQueue.sync(execute: authorizationBlock)
        }

        return shellTask
    }

    func decryptAndVerifySignature(request: NSMutableURLRequest, payload: Data) -> Data? {
        var ret: Data? = nil
        // Make sure we return proper value only on sync{ } method.
        SecureChannelAuthorizer.SecureChannelConfigurationSyncQueue.sync {
            if let host = request.url?.host {
                let privateKey = self.configurationManager.secureChannelClientPrivateKey(forHost: host)
                let privateKeyPassphrase = self.configurationManager.secureChannelClientPrivateKeyPassphrase(forHost: host)
                
                let srvCert = self.configurationManager.secureChannelServerCertificate(forHost: host)
                
                let decryptedPayload = AWCMSCryptor.decrypt(payload,
                                                            privateKeyData: privateKey,
                                                            password: privateKeyPassphrase)
                
                ret = AWCMSCryptor.verifyCMSPayloadData(decryptedPayload,
                                                        withCertificateData: srvCert,
                                                        rootCertificate: nil)
            }
        }

        return ret
    }

    private func validateCertificateForRequest(request: NSMutableURLRequest) -> Bool {
        guard let host = request.url?.host else {
            return false
        }

        let privKey = self.configurationManager.secureChannelClientPrivateKey(forHost: host)
        let pubCert = self.configurationManager.secureChannelClientCertificate(forHost: host)
        
        guard
            let x509Pub: AWX509Wrapper = AWX509Wrapper(certificateData: pubCert),
            x509Pub.isValid,
            privKey.count > 0
        else {
            return false
        }
        
        let expectedCN = "\(deviceConfig.bundleId),\(deviceConfig.airWatchServerURL)"
        guard
            let subID = x509Pub.subjectUserID,
            let subName = x509Pub.subjectName,
            subID == deviceConfig.deviceId,
            subName == expectedCN
        else {
            return false
        }

        return true
    }

    private func canSignAndEncrypt(request: NSMutableURLRequest) -> Bool {
        if let host = request.url?.host,
           self.configurationManager.secureChannelServerCertificate(forHost: host) != nil,
           self.configurationManager.secureChannelURL(forHost: host) != nil {
            return true
        }

        return false
    }

    private func signAndEncrypt(request: NSMutableURLRequest) -> Bool {
        /// Check whether client credentials are still valid to proceed
        guard self.validateCertificateForRequest(request: request) else {
            log(error: "Invalid secure channel client credentials")
            return false
        }

        log(info: "Start encrypting message for request type \(request.requestType ?? "\"Request type not set\"")")

        let plist = NSMutableDictionary()
        if let parameters = request.url?.query?.components(separatedBy: "&") {
            for param in parameters {
                let namevalue = param.components(separatedBy: "=")
                plist.setValue(namevalue[1], forKey: namevalue[0])
            }
        }


        if let requestType = request.requestType {
            if let httpBody = request.httpBody,
                let host = request.url?.host {
                
                let srvCert = self.configurationManager.secureChannelServerCertificate(forHost: host)
                let privateKey = self.configurationManager.secureChannelClientPrivateKey(forHost: host)
                let privateKeyPassphrase = self.configurationManager.secureChannelClientPrivateKeyPassphrase(forHost: host)
                
                let pubCert = self.configurationManager.secureChannelClientCertificate(forHost: host)
                
                let signedBody = AWCMSCryptor.cmsSignedPayload(httpBody, privateKeyData: privateKey, password: privateKeyPassphrase, signerCertificate: pubCert)
                guard signedBody != nil else {
                    log(error: "Failed to sign the payload for request type \(requestType)")
                    return false
                }
                
                guard let encryptedBody = AWCMSCryptor.encrypt(signedBody, certificateData: srvCert) else {
                    log(error: "Failed to encrypt the payload for request type \(requestType)")
                    return false
                }
                
                plist.setValue(encryptedBody.base64EncodedString(options: .lineLength64Characters), forKey: requestType)
            } else {
                plist.setValue("", forKey: requestType)
            }
        }
        
        plist.setValue(self.deviceConfig.bundleId, forKey: "bundleId")
        plist.setValue(self.deviceConfig.deviceId, forKey: "uid")
        plist.setValue(self.deviceConfig.deviceType, forKey: "deviceType")

        /// Modify original URL
        if let host = request.url?.host {
            request.url = self.configurationManager.secureChannelURL(forHost: host) as URL?
        }
        request.httpMethod = "POST"
        request.httpBody = try! plist.xmlPlistData()

        return true
    }
    
    public func refreshAuthorization(completion: @escaping (CTLAuthorizationProtocol?, NSError?) -> Void) {
        completion(nil, nil);
    }
}
