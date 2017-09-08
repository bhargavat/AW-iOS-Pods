//
//  CommandProcessorEndpoint.swift
//  BeaconEndpoint
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWNetwork
import AWHelpers
import AWCrypto
import AWError

public typealias LoadCommandCompletionHandler = (_ command: Command?, _ error: NSError?) -> Void

internal class AWCommandFactory: CommandFactory {}

internal class CommandLoaderEndpoint: DeviceServicesEndpoint {

    public required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = "deviceservices/awmdmsdk/v3/processor"
    }

    public func startLoadingCommands(_ commandDecryptKey: Data, completionHandler: @escaping LoadCommandCompletionHandler) -> Void {

        guard let data = self.createPayload(status: .idle, payloadIdentifier: "", requester: self.config.bundleId) else {
            completionHandler(nil, AWError.SDK.Service.General.plistSerialization.error)
            return
        }
        
        self.POST(data) { (rsp: Data?, error: NSError?) in
            guard let data: Data = rsp , data.count > 0 else {
                completionHandler(nil, error)
                return
            }

            var responseData: Data = data
            if let decryptedResponseData = self.decryptResponseData(data, decryptKey: commandDecryptKey) {
                responseData = decryptedResponseData
            } else {
                log(debug: "Unable to decrypt command response data; attempting to proceed with given data as if it is unencrypted")
            }

            do {
                let info: [String: AnyObject] = try Dictionary.dictionaryFromPropertyListData(responseData)
                let command = AWCommandFactory().createCommand(info: info)
                log(debug: command.debugDescription)
                completionHandler(command, nil)
            } catch {
                completionHandler(nil, AWError.SDK.Service.General.plistSerialization.error)
            }
        }
    }

    public func acknowledgeCommand(_ command: Command, response: CommandResponse, commandDecryptKey: Data, completionHandler: @escaping LoadCommandCompletionHandler) -> Void {

        guard let data = self.createPayload(response: response) else {
            completionHandler(nil, AWError.SDK.Service.General.plistSerialization.error)
            return
        }

        self.additionalHTTPHeaders = [ "Content-Type": "text/xml", "Accept": "text/xml" ]

        self.POST(data) { (rsp: Data?, error: NSError?) in
            guard let data: Data = rsp , data.count > 0 else {
                completionHandler(nil, error)
                return
            }

            var responseData: Data = data
            if let decryptedResponseData: Data = self.decryptResponseData(data, decryptKey: commandDecryptKey) {
                responseData = decryptedResponseData
            } else {
                log(debug: "Unable to decrypt command response data; attempting to proceed with given data as if it is unencrypted")
            }

            do {
                let info: Dictionary <String, AnyObject> = try Dictionary.dictionaryFromPropertyListData(responseData)
                let command = AWCommandFactory().createCommand(info: info)
                log(debug: command.debugDescription)
                completionHandler(command, nil)
            } catch {
                completionHandler(nil, AWError.SDK.Service.General.plistSerialization.error)
            }
        }
    }

    internal func createPayload(status: AWServices.CommandStatus, payloadIdentifier: String, requester: String ) -> Data? {

        let payload = [
            "Status": status.rawValue,
            "UDID": self.config.deviceId,
            "CommandUUID": payloadIdentifier,
            "Requestor": requester
        ] as [String : Any]

        return try? (payload as NSDictionary).xmlPlistData()
    }

    lazy var commandAckTimeStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy hh:mm:ss aaa"
        return formatter
    }()

    internal func createPayload(response: CommandResponse) -> Data? {

        var payload: [String: AnyObject] = [
            "Status": response.status.rawValue as AnyObject,
            "UDID": self.config.deviceId as AnyObject,
            "CommandUUID": response.payloadIdentifier as AnyObject,
            "Requestor": response.commandTarget as AnyObject,
            "SampleTime": commandAckTimeStampFormatter.string(from: Date()) as AnyObject
        ]

        if response.certificateResponse != nil {
            payload["CertificateList"] = response.certificateResponse as AnyObject?
        } else if response.installedProfilesResponse != nil {
            payload["ProfileList"] = response.installedProfilesResponse as AnyObject?
        }
        return try? (payload as NSDictionary).xmlPlistData()
    }

    fileprivate func decryptResponseData(_ responseData: Data, decryptKey: Data) -> Data? {

        /// Since we use AES256-CBC Decryption, we will make sure that
        /// Decrypt key has at least those many number of bytes.
        let requiredKeySize = CipherAlgorithm.aes256.keysize

        guard let base64EncodedString: NSString = NSString(data: responseData, encoding:String.Encoding.utf8.rawValue) else {
            return nil
        }

        guard decryptKey.count >= requiredKeySize else {
            log(error: "The decrypt key size should be greater than or equal to 32")
            return nil
        }

        let seperatedAr: [String] = base64EncodedString.components(separatedBy: ":")

        guard seperatedAr.count == 2 else {
            log(debug: "ResponseData cannot be decrypted: Response not of the format initializationVector:body; ")
            return nil
        }

        let initializationVector: String = seperatedAr[0]
        let encryptedBody: String = seperatedAr[1]

        /// Use first requiredKeySize bytes as key for decryption.
        let key: Data = decryptKey.subdata(in: 0..<requiredKeySize)

        /// converting to bytes:
        guard let iv: Data = Data(base64Encoded: initializationVector, options: Data.Base64DecodingOptions(rawValue: 0)) else {
            log(error: "IV cannot be converted to bytes")
            return nil
        }
        guard let bodyData: Data = Data(base64Encoded: encryptedBody, options: Data.Base64DecodingOptions(rawValue: 0)) else {
            log(error: "encryptedBody cannot be converted to bytes")
            return nil
        }
        do {
            let decryptedData: Data = try Data.AESDecrypt(bodyData, key: key, iv: iv)
            return decryptedData
        } catch {
            log(error: "AESDecrypt failed to decrypt data while decrypting command response data")
            return nil
        }
    }
}
