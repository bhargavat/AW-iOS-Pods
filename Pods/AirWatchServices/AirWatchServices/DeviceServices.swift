//
//  DeviceServices.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWCrypto
import AWNetwork
import AWLog

public class DeviceServices: NSObject {
    open fileprivate(set) var config: DeviceServicesConfiguration
    internal var hmacAuthorizer: HMACAuthorizer? = nil
    internal var secureChannelAuthorizer: SecureChannelAuthorizer? = nil
    internal var responseValidator: CTLResponseValidationProtocol? = nil

    public required init(config: DeviceServicesConfiguration,
                         authorizer: HMACAuthorizer? = nil,
                         secureChannelConfigurationManager: SecureChannelConfigurationManager? = nil,
                         responseValidator: CTLResponseValidationProtocol? = nil) {
        self.config = config
        self.hmacAuthorizer = authorizer
        self.responseValidator = responseValidator ?? AirWatchHeaderValidator()
        if let manager = secureChannelConfigurationManager {
            self.secureChannelAuthorizer = SecureChannelAuthorizer(deviceConfig: config, configurationManager: manager)
        }
    }

    public func sendBeacon(_ payload: AWServices.SendBeaconPayload, completionHandler: @escaping BeaconTransmissionCompletion) -> Void {
        let endpoint: SendBeaconEndpoint = createSecureChannelDeviceServicesEndPoint()
        let beaconPayload = payload.internalPayloadType(config.deviceId)
        endpoint.sendBeaconPayload(beaconPayload, completionHandler: completionHandler)
    }

    public func fetchCertificates(_ issuer: String, token: String, completionHandler: @escaping CertificateFetchCompletionHandler) -> Void {
        let endpoint: FetchCertificateEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchCertificates(issuer, token: token, completionHandler: completionHandler)
    }

    public func fetchProxyCertificates(_ completionHandler: @escaping ProxyCertificateCompletionHandler) -> Void {
        let endpoint: ProxyCertificateEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchProxyCertificates(completionHandler)
    }

    public func startLoadingCommands(decryptionKey: Data, completionHandler: @escaping LoadCommandCompletionHandler) -> Void {
        let endpoint: CommandLoaderEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.startLoadingCommands(decryptionKey, completionHandler:completionHandler)
    }

    public func acknowledgeCommand(_ command: Command, response: CommandResponse, commandDecryptKey: Data, completionHandler: @escaping LoadCommandCompletionHandler) -> Void {
        let endpoint: CommandLoaderEndpoint =  createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.acknowledgeCommand(command, response: response, commandDecryptKey: commandDecryptKey, completionHandler: completionHandler)
    }

    public func fetchConfigurationProfile(type: AWServices.ConfigurationProfileType, completionHandler: @escaping FetchProfileCompletion) -> Void {
        let endpoint: ProfileManagerEndpoint = createSecureChannelDeviceServicesEndPoint()
        endpoint.fetchConfigurationProfile(type: type, completionHandler: completionHandler)
    }

    public func sendLogData(_ logData: Data, settingLogLevel: Int, overWifiOnly: Bool, logType: AWLogType, withCompletion completion: @escaping LogTransmissionCompletionHandler) -> Void {
        let endpoint: LogTransmissionEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.send(logData: logData, settingLogLevel: settingLogLevel, overWifiOnly: overWifiOnly, logType: logType, withCompletion: completion)
    }

    public func sendLogInsightData(_ logData: Data, overWifiOnly: Bool, completion: @escaping LogTransmissionCompletionHandler) -> Void {
        let endpoint: LogInsightTransmissionEndpoint = LogInsightTransmissionEndpoint(config: config, authorizer: nil, validator: self.responseValidator)
        endpoint.sendLogInsightData(logData, overWifiOnly: overWifiOnly, completion: completion)
    }

    public func fetchEscrowedKey(_ keyUsage: AWServices.KeyStoreUser, enrollmentUserId: String, completionHandler: @escaping (_ keytData: Data?, _ error: NSError?) -> Void) -> Void {
        let endpoint: EscrowKeyFetchEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchKeyFromEscrowServer(keyUsage, enrollmentUserId: enrollmentUserId, completionHandler: completionHandler)
    }

    public func storeKeyWithEscrowService(EscrowStoreKey escrowKey: EscrowKey, enrollmentUserId: String, completionHandler: @escaping (_ isEscrowKeyStored: Bool, _ error: NSError?) -> Void) -> Void {
        let endpoint: EscrowKeyStoreEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.storeKeyInEscrowServer(escrowKey, enrollmentUserID: enrollmentUserId, completionHandler: completionHandler)
    }

    public func fetchUserInfo(_ completionHandler: @escaping UserInfoCompletionHandler) -> Void {
        let endpoint: UserInfoEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchUserInfo(completionHandler)
    }

    public func sendDataSamplerReadyPacket(_ token: Data? = nil, completion: @escaping DataSampleTransmissionCompletion) -> Void {
        let endpoint: InterrogatorEndpoint = createSecureChannelDeviceServicesEndPoint()
        let readyPayload = DataSamplerPacketPayload.readyPacket(type: .platformIOS, udid: self.config.deviceId)
        endpoint.sendDataSamplerPacket(flags: .flagReady, token: token, payload: readyPayload.data(), completion: completion)
    }

    public func sendDataSamplerDataPacket(_ token: Data? = nil, data: Data, completion: @escaping DataSampleTransmissionCompletion) -> Void {
        let endpoint: InterrogatorEndpoint = createSecureChannelDeviceServicesEndPoint()
        let dataPayload = DataSamplerPacketPayload.dataPacket(type: .platformIOS, udid: self.config.deviceId, data: data)
        endpoint.sendDataSamplerPacket(flags: .flagData, token: token, payload: dataPayload.data(), completion: completion)
    }

    public func fetchCertificatesToPin(_ completion: @escaping (_ pinningResposne: [String: [String]]?, _ error: NSError?) -> Void) -> Void {
        let endpoint: CertificatePinningEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchPublicKeysToPin(completion)
    }
    
    /**
     Should not be used unless in conjunction with AWDataUsage module
     To use with AWDataUsage module create a class that conforms to the protocols defined within AWDataUsage module and call this method. Don't forget to also call sendDataUsageToServer for the other method.
     */
    public func receiveDataUsageFromServer(startDate: Date?,
                                         endDate: Date?,
                                         withCompletion completion: @escaping ((_ dictionary: Dictionary<AnyHashable, Any>?, _ error: Error?) -> Void)) -> Void {
        let endpoint: DataUsageTransmitterEndPoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.receiveDataFromServer(startDate: startDate, endDate: endDate, withCompletion: completion)
    }
    /** 
     Should not be used unless in conjunction with AWDataUsage module
     To use with AWDataUsage module create a class that conforms to the protocols defined within AWDataUsage module and call this method. Don't forget to also call receiveDataUsageFromServer for the other method.
     */
    public func sendDataUsageToServer(_ dictionaryToSend: [AnyHashable: Any], withCompletion completion: @escaping (Bool)->()) -> Void {
        let endpoint: DataUsageTransmitterEndPoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.sendDataToServer(dictionaryToSend, withCompletion: completion)
    }
    
    public func fetchPolicySigningCertificate(_ completion: @escaping (_ signingCertificateResponse: [AWCrypto.Certificate]?, _ error: NSError?) -> Void) {
        let endpoint: PolicySigningEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchPolicySigningCertificate { (certificateResponse, error) in
            completion(certificateResponse, error)
        }
    }

    public func fetchEnrolledUserInformation(completion: @escaping EnrolledUserInformationFetchCompletion) -> Void {
        let enrolledUserInformationFetchEndpoint: EnrolledUserInformationFetchEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        enrolledUserInformationFetchEndpoint.fetchEnrolledUserInformation(completion: completion)
    }

    public func fetchCredentialProfileInformation(type: AWServices.ProfileType = .all, update: Bool = false, completion: @escaping FetchCredentialProfileInformationCompletion) -> Void {
        let credentialProfileEndPoint: CredentialProfileEndPoint = createHMACAuthorizedDeviceServicesEndPoint()
        credentialProfileEndPoint.fetchCredentialProfileInformation(type: type, update: update, completion: completion)
    }

    public func sendCredentialProfiles(uploadProfiles:Array<[String:String]>, completion: @escaping SendCredentialProfilesCompletion) -> Void {
        let credentialProfileEndPoint: CredentialProfileEndPoint = createHMACAuthorizedDeviceServicesEndPoint()
        credentialProfileEndPoint.sendCredentialProfiles(uploadProfiles: uploadProfiles, completion: completion)
    }

    /**
     @brief Get the environments SupportInformation for email and telephone. When an occurs, then the response from the server will return a message with the reason why and an appropriate error will be returned as part of the completion block
     
     @return completion return object - SupportInformation object with email, telephone, and error message. If the server responds with an error, then error message will have a string, else it will be nil. Must check both the error objet of the completion and ErrorMessage values to know if an error occured.
     @return AWError.SDK.CoreNetwork.CTL.createRequestFailure(error.localizedDescription) - network related failure
     @return AWError.SDK.General.jsonDeserializationFailed - could not unwrap the response data which is supposed to be JSON
     @return AWError.SDK.General.configurationValuesUnavailable.error - An Error was returned on the server. Check the error message for a possible message.
     
     */
    public func fetchSupportInformation(completion: @escaping SupportInformationFetchCompletion) -> Void {
        let endpoint: SupportInformationEndpoint = self.createSecureChannelDeviceServicesEndPoint()
        endpoint.fetchSupportInformation(completion: completion)
    }


    public func requestRequeryDeviceInformation(type: AWServices.RequeryType, completion: @escaping (Bool, Error?) -> Void) {
        let endpoint: RequestRequeryDeviceStatusEndpoint = self.createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.requestRequery(type: type, completion: completion)
    }

    public func fetchEULAAcceptanceStatus(completion: @escaping (_ requiredEULAAcceptance: AWServices.EULAAcceptanceStatus, NSError?) -> Void) {
        let endpoint: EULAAcceptanceStatusEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.getAcceptanceStatus(completion: completion)
    }

    public func updateEULAAcceptanceStatus(contentID: UInt,
                                           action: AWServices.EULAAcceptanceStatus,
                                           completion: @escaping(Bool, NSError?) -> Void) {
        let endpoint: EULAAcceptanceStatusEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.updateEULAAcceptance(contentID: contentID, status: action, completion: completion)
    }

    public func fetchEULAContent(contentID: Int = -1, completion: @escaping (AWServices.EULAContent?, NSError?) -> Void) {
        let endpoint: EULAContentFetchEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        endpoint.fetchEULAContent(contentID: contentID, completion: completion)
    }

    /**
     The current implementation on console does not unenroll the device, but marks the device for "Enterprise Wipe Pending". Once console receives a request for commands from command manager, then console will mark the device as unenrolled.
     */
    public func unenrollDevice(completion completionHandler: @escaping (_ statusForDidUnEnroll: Bool) -> () ) {
        let hmacEndpoint: UnEnrollmentEndpoint = createHMACAuthorizedDeviceServicesEndPoint()
        let secureChannelEndpoint: UnEnrollmentEndpoint = self.createSecureChannelDeviceServicesEndPoint()

        hmacEndpoint.deviceUnenrollmentForAuthenticatedUser { (statusForDidUnEnroll: Bool) in
            if statusForDidUnEnroll {
                completionHandler(true)
            } else {
                secureChannelEndpoint.deviceUnenrollmentForNonAuthenticatedUser (completion: { (statusForDidUnEnroll: Bool) in
                    completionHandler(statusForDidUnEnroll)
                })
            }
        }
    }

    internal func createHMACAuthorizedDeviceServicesEndPoint<T>() -> T where T: DeviceServicesEndpoint {
        let endpoint = T(config: config, authorizer: hmacAuthorizer, validator: responseValidator)
        return endpoint
    }

    internal func createSecureChannelDeviceServicesEndPoint<T>() -> T where T: DeviceServicesEndpoint {
        let endpoint =  T(config: config, authorizer: nil, validator: nil)
        let scEndpoint = SecureChannelEndpoint(config: config, authorizer: secureChannelAuthorizer)
        scEndpoint.validator = responseValidator
        endpoint.surrogate = scEndpoint
        return endpoint
    }
}


