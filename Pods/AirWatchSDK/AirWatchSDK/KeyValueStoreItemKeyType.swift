//
//  SharedKeychainService.swift
//  AWSecureSharedStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

public enum KeyValueStoreItemKeyType: String {

    case TouchIDConfigured                              = "com.touchidconfigured.intermediate.service"
    case CurrentStorageVersion                          = "com.air-watch.version.storage"
    case CurrentConsoleVersion                          = "com.air-watch.version.console"
    case ApplicationServiceURL                          = "AWApplicationServerURLService"
    case AgentEnrolledDeviceUDID                        = "com.air-watch.ios.applicationUDID" // MDM enrolled UDID
    case ContainerModeEnrolledUDID                      = "com.air-watch.ios.applicationAWUDID" //Container
    case EnrollmentStatusCheckDate                      = "com.air-watch.ios.application.enrollmentcheckdate"
    case EnrollmentStatus                               = "com.air-watch.ios.application.enrollmentstatus" //Container
    case ReportUnenrollment                             = "com.air-watch.reportUnenrollment"

    case ContainerEnrolledDeviceUDID                    = "com.anchoridentifier.service"
    case LocationGroup                                  = "kAWApplicationGroupIDService"
    case AnchorScheme                                   = "com.shared.achor.scheme.service"
    case SharedKeychainAvailable                        = "com.share.achor.service"
    case CertificateSharingEnabled                      = "com.certshare.achor.service"
    case EnrollmentAccount                              = "com.user.service.v1"
    case AuthenticationPayload                          = "com.authentication.payload.service"
    case AuthenticationPayloadIdentifier                = "com.payloadidentifier.service"
    case ProtectedWithPasscode                          = "com.passcodeset.service"
    case SingleSignOnEnabled                            = "com.app.sso.enabled"
    case BiometricMethod                                = "com.biometricmethod.service"
    case AuthenticationType                             = "com.authenticationtype.service.v1"
    case LegacyAuthenticationType                       = "com.passcodemode.service"
    case NewSDKPasscodeSetDate                          = "com.newsdkpasscodesetdate.service" // Deprecated do NOT use
    case CurrentPasscodeSetDate                         = "com.passcodesetdate.service.v1"
    case SessionKeySeedInformation                      = "com.context.service"
    case BootTimeInformation                            = "com.boottime.service"
    case LastUnlockedTimeStamp                          = "com.unlock.service"
    //SSO Details
    case DefaultPin                                     = "com.key.random"
    case CryptKeySalt                                   = "com.id1.service"
    case ApplicationKey                                 = "com.app.key.service.v1"
    case SharedContainerKey                             = "com.app.sharedkey.service"
    case SSOSessionInfo                                 = "com.sso.session.info.service.v1"
    case CurrentSessionCryptKey                         = "com.temp.sessionkey.service.v1"
    case FailedPasscodeAttempts                         = "com.authentication.failedattempts.service"
    
    case TouchIDKeyStoredInSecureEnclave                = "com.secure.intermediate.key.service"
    
    case MasterKeyEncryptedWithCryptKey                 = "com.masterkey.store.service.v1"
    
    case MasterKeyEncryptedWithTouchIDKey               = "masterkey.secondaryKey.service"
    case MasterKeyVerificationEncryptedWithTouchIDKey   = "masterkey.secondaryKey.service.verifier"
    
    case MasterKeyEncryptedWithSessionKey               = "masterkey.sessionKey.service"
    case MasterKeyVerificationEncryptedWithSessionKey   = "masterkey.sessionKey.service.verifier"
    
    
    case CentennialEncryptedWithMasterKey               = "masterkey.centennial.service"
    case CentennialVerificationEncryptedWithMasterKey   = "masterkey.centennial.service.verifier"
    case CryptKeyToEscrow                               = "cryptkeyToEscrow.service"

    
    
    case EncryptedPin                                   = "com.masterkey.pin.store.service.v1"
    case EncryptedPinHash                               = "com.masterkey.store.pin.validate.service.v1"
    case PasscodeHistory                                = "com.passcodehistory.store.service"
    case EnrolledUserEmailAddress                       = "com.enrolleduseremailaddress.store.service"
    case CurrentCryptKeyEscrowSuccessful                = "AWCryptKeyEscrowedSuccess.service"
    //Master/Common Id
    case LegacyCommonIdentityAuthenticationInformation  = "com.auth.master.service"
    case CommonIdentityAuthenticationInformation        = "com.aw.common.hmac.service"
    // Application/NonShared
    case ApplicationIdentityAuthenticationInformation   = "com.sso.hmac.info.service.v1"
    case OnboardedUser                                  = "com.onboardeduser.store.service"

    // case SSOEncryptedSharedPin

    case RememberUsername                               = "com.user.remember.service"
    case CurrentUserInformation                         = "com.user.information.service"
    case SecureEnclaveCryptKey                          = "com.secure.crypt.data.service" //old key not used anymore
    case IAuthClientCert                                = "aw.client.certificate"
    
    //session management service names
    case SessionTable                                   = "sessiontable.service"
    case RSAKeyPairEncryptedWithMasterKey               = "rsakeypair.service"
    case SessionTableEntryKeyPreFix                     = "tableKey"
    case RSAKeyGenerationIdentifierPostFix              = "keyGen"

    //Managed Settings sanity service names
    case LastVerifiedOneTimeToken                       = "com.sso.oneTimeToken.verified"
    
    //SecureChannelConfiguration Security service names
    case SecureChannelConfigurationObfuscationKey       = "com.air-watch.schannel.config.obfuscationkey"
    case CommonAuthenticationGroupKey                   = "AWCommonAuthenticationGroup.service"
    case ApplicationAnalyticsIdentifier                 = "com.air-watch.diagnostics.identifier"
    
}
