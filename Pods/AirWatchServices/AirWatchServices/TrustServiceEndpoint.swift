//
//  TrustServiceEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import Alamofire

import AWCrypto
import AWError
import AWLog

private let trustserviceProductionCert:String = "MIIFcTCCA1mgAwIBAgIEDo20fTANBgkqhkiG9w0BAQ0FADAYMRYwFAYDVQQDEw1BVyBUcnVzdCBSb290MB4XDTE2MTEwNjE2NDQ0NVoXDTI5MTEwNzE2NDQ0NVowGDEWMBQGA1UEAxMNQVcgVHJ1c3QgUm9vdDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBANbKaoJvQE5dKmzZFFrMrKFH9dZIkD24EI3uWz3smA9/1M/C0jdqQ7CIrqfLVWZm0UZSVZegzk2AmY3fhn5tIHaPR6RP2eaYk/JRpqlTJDGfLoZjTmhhGp+5Nnp/eYDjYQL1Hx2Ef/nULSKG9AZOWNYbufo/uONrSoDIfq/6wmk7cBY0RDBjb0vhEbzfYZHk6oBwexvzAKmVR1BDWXTePbw5Jf2JKZtEyVhXOaXnlWHWNrTAUYzkt5QHg8upzKRYTykJyFeX5PzdrCpBYagNi/X9MqBM6sCzsO/rMNayDVGn+dhmOhyEUyulgrCaR/5uDmmbqPLe+LFsk49BtUnysTQAi3S+b+L8gLkEHiog05VYObqH5cCHHqHl7B3hOeiL/uZz1Nnf/7YAlDxS2lHSq8qj4zX9QBjzsfI0j7OHI+J7KqMIA34m+yXtzMq0geKPHQI2FywtMqXXb7O9vTKmr1w/MveRIQ/6Igl4PzROpy8JCvTINNz0riEs+8tNhnlvTyo2UEAnpkAms1jw78my9hitLX2gxxg97RMunWVKoIKiS/XcArQHxkcURlLljbL0ICy64PbWBNOu++yrmDmuMlOscK9r3wGEzyhnMCYfPGligmiUeqNMw/eznXarViTo93Dpr6ggg/033Ax32iq9hiqGb9P8K0z3nHbyG2AZdcKZAgMBAAGjgcIwgb8wHQYDVR0OBBYEFLtXQLXGrELgS3XVm11E6VCQCRfyMA8GA1UdEwEB/wQFMAMBAf8wQwYDVR0jBDwwOoAUu1dAtcasQuBLddWbXUTpUJAJF/KhHKQaMBgxFjAUBgNVBAMTDUFXIFRydXN0IFJvb3SCBA6NtH0wCwYDVR0PBAQDAgH2MDsGA1UdJQQ0MDIGCCsGAQUFBwMBBggrBgEFBQcDCQYIKwYBBQUHAwIGCCsGAQUFBwMIBggrBgEFBQcDAzANBgkqhkiG9w0BAQ0FAAOCAgEADgD5lUbuQKiuQTOl+31DD+F4Z0HEWP7tiYB9ekQkRV+TURY3tHYVBa93+QDxvUZuwmEk7FXeuDcRPDK0Vdzskwv8Evs0UvtjTNHMPg7vT8F4hlpPS7Prmhb8BW90Wo0ZolomGamBCdP0eRddb9hlaKNQL92bZjzwvVNcGd8vkxDfvJkjj2NPA1azI8aRzoDkEwgMeIv4Of09oWDCVsBv+8TxzpW9xMnJkg9x/TJMsJwPzz3xuL4NWgLgORNKKqV/oaUlKicOSev5qmcbHVgzqvVTy/rU0tl1DTAV08dA/vtyBgWGPDxaX7qkB2KxqWCtA3L3AynIkgLjRweDdG5xDFw0Oh78CAiInay5/7B+gEIXVVmUYYNdBlUUuwtDm60/UEPWoAuMz2xSdF0kxFKblieCDQ7t9IRjaSYAbY5g9MEIVbN3hl1BxJ47DgcL2eA/d3HL/eVd5PwJ6eDhly48o+eRJXyGl10OobQsTQZSgzl1O3ykUD3c/wffWdNcd5PSOMO6h3slBSuK6qBmeS+n6aMjZkI8Tjy2LTOhfnjTheemYMUN562yWYGJywFrHWen8RSpelOPVwTeRVOl4Pr/JZZH+N3C5Wol+KZTk1+xMuawSazdRNGPYKtddfkRDjoXfgnCmMazVO1BY3cKl9c5FbVwNPoJfrm+Pe/YSbqxwxM="

#if DEBUG
    private let trustserviceQACert:String = "MIIE0DCCA7igAwIBAgIBBzANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoTEUdvRGFkZHkuY29tLCBJbmMuMTEwLwYDVQQDEyhHbyBEYWRkeSBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTExMDUwMzA3MDAwMFoXDTMxMDUwMzA3MDAwMFowgbQxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQHEwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5LmNvbSwgSW5jLjEtMCsGA1UECxMkaHR0cDovL2NlcnRzLmdvZGFkZHkuY29tL3JlcG9zaXRvcnkvMTMwMQYDVQQDEypHbyBEYWRkeSBTZWN1cmUgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC54MsQ1K92vdSTYuswZLiBCGzDBNliF44v/z5lz4/OYuY8UhzaFkVLVat4a2ODYpDOD2lsmcgaFItMzEUz6ojcnqOvK/6AYZ15V8TPLvQ/MDxdR/yaFrzDN5ZBUY4RS1T4KL7QjL7wMDge87Am+GZHY23ecSZHjzhHU9FGHbTj3ADqRay9vHHZqm8A29vNMDp5T19MR/gd71vCxJ1gO7GyQ5HYpDNO6rPWJ0+tJYqlxvTV0KaudAVkV4i1RFXULSo6Pvi4vekyCgKUZMQWOlDxSq7neTOvDCAHf+jfBDnCaQJsY1L6d8EbyHSHyLmTGFBUNUtpTrw700kuH9zB0lL7AgMBAAGjggEaMIIBFjAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUQMK9J47MNIMwojPX+2yz8LQsgM4wHwYDVR0jBBgwFoAUOpqFBxBnKLbv9r0FQW4gwZTaD94wNAYIKwYBBQUHAQEEKDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5nb2RhZGR5LmNvbS8wNQYDVR0fBC4wLDAqoCigJoYkaHR0cDovL2NybC5nb2RhZGR5LmNvbS9nZHJvb3QtZzIuY3JsMEYGA1UdIAQ/MD0wOwYEVR0gADAzMDEGCCsGAQUFBwIBFiVodHRwczovL2NlcnRzLmdvZGFkZHkuY29tL3JlcG9zaXRvcnkvMA0GCSqGSIb3DQEBCwUAA4IBAQAIfmyTEMg4uJapkEv/oV9PBO9sPpyIBslQj6Zz91cxG7685C/b+LrTW+C05+Z5Yg4MotdqY3MxtfWoSKQ7CC2iXZDXtHwlTxFWMMS2RJ17LJ3lXubvDGGqv+QqG+6EnriDfcFDzkSnE3ANkR/0yBOtg2DZ2HKocyQetawiDsoXiWJYRBuriSUBAA/NxBti21G00w9RKpv0vHP8ds42pM3Z2Czqrpv1KrKQ0U11GIo/ikGQI31bS/6kA1ibRrLDYGCD+H1QQc7CoZDDu+8CL9IVVO5EFdkKrqeKM+2xLXY2JtwE65/3YR8V3Idv7kaWKK2hJn0KCacuBKONvPi8BDAB"
#endif

public class TrustServiceEndpoint {
    
    let trustServiceUrl: NSURL
    let config: DeviceServicesConfiguration
    internal static var networkManager: SessionManager = SessionManager()
    
    required public init?(trustServiceUrl: String, withConfiguration config: DeviceServicesConfiguration) {
        guard let endpointUrl = NSURL(string: trustServiceUrl + "/SSLPinning/Settings") else {
            return nil
        }
        self.trustServiceUrl = endpointUrl
        self.config = config
    }
    
    public func fetchPinnedCertsFromTrustService(forHost host: String, completionHandler: @escaping (_ pinKeyResponse: [String: [String]]?, _ error: NSError?) -> Void) {
        guard host.characters.count > 0 && host.lowercased().contains("http") == false else {
            log(error: "Can't retrieve SSL public keys when there is no AirWatch Host to retrieve them for/from")
            completionHandler(nil, AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        guard let _ = NSURL(string: "https://\(host)") else {
            log(error: "Can't retrieve SSL public keys when there is no AirWatch Host to retrieve them for/from")
            completionHandler(nil, AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        let urlComps = NSURLComponents(url: self.trustServiceUrl as URL, resolvingAgainstBaseURL: false)
        
        urlComps?.query = "URL=\(host)"
        
        guard let trustServiceURL = urlComps?.url else { //"https://architecture.airwatchqa.com/TrustService/SSLPinning/Settings?URL=dev16.airwatchdev.com"
            log(error: "Could not create Trust Service URL with given values.")
            completionHandler(nil, AWError.SDK.CertificatePinning.malformedURL.error)
            return
        }
        
        let deviceId = self.config.deviceId
        let awServer = self.config.airWatchServerURL
        
        /**
         SAMPLE REQUEST
         https://architecture.airwatchqa.com/TrustService/SSLPinning/Settings?URL=dev16.airwatchdev.com
         
         SAMPLE RESPONSE
         {
         "dev16.airwatchdev.com":[      "308189028181009A2B32357B32C12964D77DD80981E6FFEC0C483C95D76A00FA0F7A9B1E73837EC91FDC8B25C5D0D304E6C213C5F298D354E1D801DB22E1C9D93E7FDAD1AFCEE962016F1796DF05C42E29EA6A4E8A2035E87E6C69362C90B208960140A6B85FF051A2459F5EB559A487AC55D7167FC0448CE088B141DA7199A454D146BDEAF8C90203010001"
         ]
         }
         */
        
        TrustServiceEndpoint.networkManager.delegate.taskDidReceiveChallengeWithCompletion = {(urlSession: URLSession, urlSessionTask: URLSessionTask, authenticationChallenge: URLAuthenticationChallenge, completion:(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void in
            
            guard authenticationChallenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
                completion(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
                return
            }
            
            guard let serverTrust = authenticationChallenge.protectionSpace.serverTrust else {
                // MARK: There is no server trust to validate.  Exiting early.
                completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
                return
            }
            
            let evaluation = TrustServiceEndpoint.evaluate(serverTrust: serverTrust, forHost: authenticationChallenge.protectionSpace.host, completeDisposition: completion)
            
            if evaluation == false {
                _ = PinnedCertValidationFailureEndpoint.reportCertValidationFailureToServer(awServerUrl: awServer, onDeviceId: deviceId, forChallengedHost: authenticationChallenge.protectionSpace.host)
            }
        }
        
        let networkRequest = TrustServiceEndpoint.networkManager.request(trustServiceURL, method: .get).responseData { (response) in
            guard response.result.isSuccess else {
                // The request failed
                if let error = response.result.error {
                    completionHandler(nil, error as NSError?)
                } else {
                    // Given that there was a network failure, there should always be an error to accompany it.
                    completionHandler(nil, AWError.SDK.CertificatePinning.failedToFetchPinningCertificate.error)
                }
                
                return
            }
            
            guard let statusCode = response.response?.statusCode else {
                // Given that there is no error there should always be a response and status code. Protecting against statistical impossibility.
                completionHandler(nil, AWError.SDK.CertificatePinning.failedToFetchPinningCertificate.error)
                return
            }
            
            if statusCode < 200 || statusCode > 299 {
                switch statusCode {
                case 401: completionHandler(nil, AWError.SDK.Service.AutoDiscovery.unAuthorized.error)
                    return
                case 403: completionHandler(nil, AWError.SDK.Service.AutoDiscovery.forbidden.error)
                    return
                case 500: completionHandler(nil, AWError.SDK.Service.AutoDiscovery.serverError.error)
                    return
                default: completionHandler(nil, AWError.SDK.CoreNetwork.CTL.httpStatus(statusCode, HTTPURLResponse.localizedString(forStatusCode: statusCode)).error)
                }
            }
            
            guard let responseData = response.result.value else {
                // Response value is missing.
                completionHandler(nil, NSError(domain: "AirWatchSDK.PinningCertificateFetchOperation", code: 1, userInfo: nil))
                return
            }
            
            guard let responseJson = try? JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.mutableContainers) else {
                // Response value is missing expected Json.
                completionHandler(nil, NSError(domain: "AirWatchSDK.PinningCertificateFetchOperation", code: 1, userInfo: nil))
                return
            }
            
            guard let responseObject = responseJson as? [String : [String]] else {
                // Response value is missing expected Json Object.
                completionHandler(nil, NSError(domain: "AirWatchSDK.PinningCertificateFetchOperation", code: 1, userInfo: nil))
                return
            }
            
            completionHandler(responseObject, nil)
            log(info: "Received response from Trust Service. Completing SSL Pin fetch.")
            return
        }
        
        networkRequest.resume()
        
    }
    
    private static func getStoredTrustServiceCerts() -> [NSData]? {
        
        guard let trustServiceProdCert = NSData(base64Encoded: trustserviceProductionCert, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
            log(error: "Could not retrieve trust service pinned cert from memory.")
            return nil;
        }
        
        #if DEBUG
            guard let trustServiceQACert = NSData(base64Encoded: trustserviceQACert, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                log(error: "Could not retrieve QA trust service pinned cert from memory.")
                return nil;
            }
            return [trustServiceProdCert, trustServiceQACert]
        #else
            return [trustServiceProdCert]
        #endif
    }
    
    internal static func evaluate(serverTrust: SecTrust, forHost host: String, completeDisposition:(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Bool {
        
        var serverCerts: [SecCertificate] = []
        
        let count = SecTrustGetCertificateCount(serverTrust)
        log(debug: "Received a Cert Chain of \(count) certificates from Trust Service")
        var current = 0
        while current < count {
            serverCerts.append(SecTrustGetCertificateAtIndex(serverTrust, current)!)
            current += 1
        }
        
        guard let trustServiceCertDataArray = self.getStoredTrustServiceCerts() else {
            log(error: "Missing Trust service secure data...Cannot validate Trust service...Cancelling Challenge.")
            completeDisposition(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        let certFormat = CertificateFormat.der
        var trustServiceCerts: [SecCertificate] = []
        for trustServiceCertData: NSData in trustServiceCertDataArray {
            if let currentCert = try? certFormat.parse(certificateData: trustServiceCertData as Data) {
                trustServiceCerts.append(currentCert)
            }
        }
        
        guard trustServiceCerts.count > 0 else {
            log(error: "Missing Trust service certs...Cannot validate Trust service...Cancelling Challenge.")
            completeDisposition(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        let policy = SecPolicyCreateSSL(false, host as CFString?)
        var trust: SecTrust? = nil
        SecTrustCreateWithCertificates(serverCerts as CFArray, policy, &trust)
        guard let newTrust = trust else {
            completeDisposition(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        SecTrustSetAnchorCertificates(newTrust, trustServiceCerts as CFArray)
        
        guard var trustResultType: SecTrustResultType = SecTrustResultType(rawValue: 0) else {
            completeDisposition(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        let status = SecTrustEvaluate(newTrust, &trustResultType)
        log(debug: "While validating Trust Service, Received status: \(status == noErr ? "good":"error"), and resultType: \(trustResultType) == \(SecTrustResultType.unspecified)")
        if status == noErr && trustResultType == SecTrustResultType.unspecified {
            
            let credentialToUse = URLCredential(trust: newTrust)
            completeDisposition(URLSession.AuthChallengeDisposition.useCredential, credentialToUse)
        } else {
            // MARK: Soft Fail enabled here
            // TODO: To Disable Soft Fail for this endpoint: Change this AuthChallengeDisposition to Cancel
            completeDisposition(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
            return false
        }
        return true
    }
}
