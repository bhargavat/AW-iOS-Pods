//
//  AutoDiscoveryServices.swift
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
import AWNetwork
import AWError

private let autodiscoverCurrentProductionCert:String = "MIIFGjCCBAKgAwIBAgIHJ7XwUNaoMDANBgkqhkiG9w0BAQsFADCBtDELMAkGA1UEBhMCVVMxEDAOBgNVBAgTB0FyaXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoTEUdvRGFkZHkuY29tLCBJbmMuMS0wKwYDVQQLEyRodHRwOi8vY2VydHMuZ29kYWRkeS5jb20vcmVwb3NpdG9yeS8xMzAxBgNVBAMTKkdvIERhZGR5IFNlY3VyZSBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjAeFw0xNDA4MDExMzMzMDlaFw0xNzA4MDExMzMzMDlaMDkxITAfBgNVBAsTGERvbWFpbiBDb250cm9sIFZhbGlkYXRlZDEUMBIGA1UEAwwLKi5hd21kbS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDUo8YtJRe0pVHYSi2SDPle/P+q2lXJXgGh+gIOqBQ8Jppz3fjS/mnjwHLeX2O9wobntDSDVug92MCcGoPG4nkvAHRgpUs1g1Tvro2J3Gzw9Aov9CMq33nu71ibmjpGAq8UckBInW4wHSuD+X6D0A7GWKldujyGIAxda8bLTIBtdBVWgmqlvts4Ww6HqxgFucwxTLudoPgB4Lvp2RB5HZ125FujyzRwinvxLWATfq9tyXc1xMAOYpjUN9xjnTuEj7HBedWmj2/1Dl7rQ8pzozBC3cmpi8uDE+NO5SojT+boQPOJlaYJbhiKJ9fGBNHdYmvDSXfyr/gy8Ogz57ePYvLFAgMBAAGjggGpMIIBpTAMBgNVHRMBAf8EAjAAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAOBgNVHQ8BAf8EBAMCBaAwNgYDVR0fBC8wLTAroCmgJ4YlaHR0cDovL2NybC5nb2RhZGR5LmNvbS9nZGlnMnMxLTg3LmNybDBTBgNVHSAETDBKMEgGC2CGSAGG/W0BBxcBMDkwNwYIKwYBBQUHAgEWK2h0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20vcmVwb3NpdG9yeS8wdgYIKwYBBQUHAQEEajBoMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5nb2RhZGR5LmNvbS8wQAYIKwYBBQUHMAKGNGh0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20vcmVwb3NpdG9yeS9nZGlnMi5jcnQwHwYDVR0jBBgwFoAUQMK9J47MNIMwojPX+2yz8LQsgM4wIQYDVR0RBBowGIILKi5hd21kbS5jb22CCWF3bWRtLmNvbTAdBgNVHQ4EFgQUkKFs7+X+t9KFElRfrozkITFQ/1QwDQYJKoZIhvcNAQELBQADggEBAHzk8rWAvyyLDHJ6jPMrwCLYvv/Ibq8IzNn48fFbInrFhXx10KcF9fjLOxZ0dBmJ3htOOKaNCLPBnGqgXq81HogVEPMHd6Xh/K7LKPNi8SKxk7uSPd2Re3OgpqjWadEMVtpP4h/zNyGP4hnGILOVBW0FyqUFGrEYaLS0G1DL2O0DIHYdk75eNWkpKZJL7gGPn6D7r9MkDk/T8MIQdz8+pajCOvkQhP4hX9RsIgdTonjkoAxpa+VcBDF6uMT8r1K5uHx87Sz7Q1NkOM2E2+DtFDmnfXQ3/vLs8AhDvSKnINl9a/Cvsi5TFjWdO/zAGE0AUDt86kzV/l7Upfe27c/sCgQ="
private let autodiscoverNextProductionCert:String = "MIIFRTCCBC2gAwIBAgIJAK93vKuuqu/FMA0GCSqGSIb3DQEBCwUAMIG0MQswCQYDVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEaMBgGA1UEChMRR29EYWRkeS5jb20sIEluYy4xLTArBgNVBAsTJGh0dHA6Ly9jZXJ0cy5nb2RhZGR5LmNvbS9yZXBvc2l0b3J5LzEzMDEGA1UEAxMqR28gRGFkZHkgU2VjdXJlIENlcnRpZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTE2MDgzMDE4MTYzOFoXDTE5MDgzMDE4MTYzOFowQTEhMB8GA1UECxMYRG9tYWluIENvbnRyb2wgVmFsaWRhdGVkMRwwGgYDVQQDExNkaXNjb3ZlcnkuYXdtZG0uY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAwNTf2xNDHFZUEtzZ0llQ+n61k1aJB3Y2z125yAe7iSGO04RrnbG0SaD9jqGdQV2k5/Aq63RMh5UgC0y6Z7Ecr2mJiO6yef/knx4g3Z3iUIwJkvSwt4frDRu2uxgSp26EOnQ+1cqPaNL58JpJPcYkVsJaQywy8rDxpUPVVtigxWKub2Cy/h/DcriHtc7I2Kg/fGDJcGNjv60GoBWNh4htY9m/Lb5rd1lrBs01wFJzsIClZ9BVFntAVd6gm6jy63AMrHuTiAho18huRtlTsq9cuSGiKf/rsa5I9CwTWKsEbffu8NY7XDYbDEiDQ03XiW2tokf4WTtESrN/DVp/bUgs8QIDAQABo4IByjCCAcYwDAYDVR0TAQH/BAIwADAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDgYDVR0PAQH/BAQDAgWgMDcGA1UdHwQwMC4wLKAqoCiGJmh0dHA6Ly9jcmwuZ29kYWRkeS5jb20vZ2RpZzJzMS0yOTUuY3JsMF0GA1UdIARWMFQwSAYLYIZIAYb9bQEHFwEwOTA3BggrBgEFBQcCARYraHR0cDovL2NlcnRpZmljYXRlcy5nb2RhZGR5LmNvbS9yZXBvc2l0b3J5LzAIBgZngQwBAgEwdgYIKwYBBQUHAQEEajBoMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5nb2RhZGR5LmNvbS8wQAYIKwYBBQUHMAKGNGh0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20vcmVwb3NpdG9yeS9nZGlnMi5jcnQwHwYDVR0jBBgwFoAUQMK9J47MNIMwojPX+2yz8LQsgM4wNwYDVR0RBDAwLoITZGlzY292ZXJ5LmF3bWRtLmNvbYIXd3d3LmRpc2NvdmVyeS5hd21kbS5jb20wHQYDVR0OBBYEFGqKwqsqSabgWRVaNcIJHXXzg10TMA0GCSqGSIb3DQEBCwUAA4IBAQCD4TB9ftbqkbVxo5j3hhl7y0B7pNXWXmVHyQ9KrWbQFTvveaABIesDOd0PfrODcSNcax8Pz0DQM4R89m34AFT5pL5KS6X97tNHeu6fh1Oes2INh9t51ROi/LpSkrj3dEDUmaVd+g5S+2nNzmdaUezbrdlw9uG+H2c9RA8DM62HAmm+CVFH7uJ7xagc0eivm6jOnNjdlgGyTnnmqfs1qmkLLm44SXG5N5hIVKlBE59Z6zQ39jBBKTqcR+q8hiITvj2lZ+yINZoTIKCwpu816G0qPMTg8Iv+Tq58WEg523uwAIMYYyKp7CoglLVy3gMbAfje22DOjBI3gdK/30KVdStC"
private let autodiscoverBackupProductionCert:String = "MIIFRTCCBC2gAwIBAgIJAOC4qPyc4QrDMA0GCSqGSIb3DQEBCwUAMIG0MQswCQYDVQQGEwJVUzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEaMBgGA1UEChMRR29EYWRkeS5jb20sIEluYy4xLTArBgNVBAsTJGh0dHA6Ly9jZXJ0cy5nb2RhZGR5LmNvbS9yZXBvc2l0b3J5LzEzMDEGA1UEAxMqR28gRGFkZHkgU2VjdXJlIENlcnRpZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTE2MDkwNzE1MDE0MFoXDTE5MDkwNzE1MDE0MFowQTEhMB8GA1UECxMYRG9tYWluIENvbnRyb2wgVmFsaWRhdGVkMRwwGgYDVQQDExNkaXNjb3ZlcnkuYXdtZG0uY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAmHngHGpSQCpz1OL7czEUya0yoUrqFE218CbBmWA4R7Eu5SLtdjB6rxEDIUNR1dj4eQ9QtmrPyeDfGoqSD3ui/tck6+tt4VfjUBVSw0yeiOjanaZi9jV4eXvs3EzLhnw5p6ALDtfN/RlqBnZuL7yqCMZ7sGsYDIx+lZGirUbOH0rYV5YNZI1+xXK0C1HwhjH/CmHI0Elx+MstzCsPt+nCJdZc8+LlsBb0lwjC5TLO+7gBer9g66uaI+U/hKF5ykAMN49TeqJUH83SMWZ7IO2AvrKdmdA/zLKfwn5xDEAT6qt3yB1RDzTlAs+FfwOt++IZHM4ISvtUyYDcxa1VVc5lUwIDAQABo4IByjCCAcYwDAYDVR0TAQH/BAIwADAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDgYDVR0PAQH/BAQDAgWgMDcGA1UdHwQwMC4wLKAqoCiGJmh0dHA6Ly9jcmwuZ29kYWRkeS5jb20vZ2RpZzJzMS0yOTkuY3JsMF0GA1UdIARWMFQwSAYLYIZIAYb9bQEHFwEwOTA3BggrBgEFBQcCARYraHR0cDovL2NlcnRpZmljYXRlcy5nb2RhZGR5LmNvbS9yZXBvc2l0b3J5LzAIBgZngQwBAgEwdgYIKwYBBQUHAQEEajBoMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5nb2RhZGR5LmNvbS8wQAYIKwYBBQUHMAKGNGh0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20vcmVwb3NpdG9yeS9nZGlnMi5jcnQwHwYDVR0jBBgwFoAUQMK9J47MNIMwojPX+2yz8LQsgM4wNwYDVR0RBDAwLoITZGlzY292ZXJ5LmF3bWRtLmNvbYIXd3d3LmRpc2NvdmVyeS5hd21kbS5jb20wHQYDVR0OBBYEFHzVJHwcOYN9dBoKHYIoWF7zGpmcMA0GCSqGSIb3DQEBCwUAA4IBAQAAd2eFrmgcGQ7kou5tYmrv4yp4LAdVQecraCA2FxAxpPi/mdplKBru917Wf2bzjaskrZD+X6dUV7DKlUT+0QdCcUf2uyU3IEe+DFUdJ5tC6Bc9EXBfazjCXIaUpNHOMruOy1mI/QOCdqO/09BDUaHNlz0T3rheuHd2IOJovmgTuDR0MdLcGKba/f0kVjtIe9Uhc9UEngIx6p17zD4O33zwMGqvK/BfH1BV6JBwnvkpG0rkRRyQj2rH2Boiw7nUNbrvkms1rWt5TMpR47FybjAB1fdXBJLrjhzEQd/9etcqEDKYTgZ2n6la7bgyku+Z0kJDMzjwQu43UKzyz3y9BGSc"

#if DEBUG
    private let autodiscoverQACert:String = "MIIFUDCCBDigAwIBAgIQDJEh79PacFIN5b1qTB8fwDANBgkqhkiG9w0BAQsFADBwMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMS8wLQYDVQQDEyZEaWdpQ2VydCBTSEEyIEhpZ2ggQXNzdXJhbmNlIFNlcnZlciBDQTAeFw0xNzAxMDMwMDAwMDBaFw0yMDAxMDgxMjAwMDBaMF4xCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJHQTEQMA4GA1UEBxMHQXRsYW50YTEVMBMGA1UEChMMQWlyV2F0Y2ggTExDMRkwFwYDVQQDDBAqLmFpcndhdGNocWEuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAuhs/WRyXSAT7RvP2JnVc/jauNRhzRKs3KdPeSLP89D9Z+MZVfh4ruwz3OmG2uboSSlKSntvqUfCx1vMCu1YvkRmwMYxAsbNCf/RzHREz40C5TlETjBTipmvMs69TzVV7ced00BEJygWlpV2AXseadleaG+vMidbAiDewIauCiJwisPvVJ1VW2SZvK32LHb+9ekltaEgf6Fs756MqzReROA+yn8vv3NbtQZIhSr25RSyGVAEVKYBAL/btzMTkhlETusA9nKImQVEvq6688yqcRqgRAYskhEo6B+z6UfxQrbRlW+pcnuxtzHJ0NUCXQTjr4sZjU6b+bieq7ZI8YcFCzwIDAQABo4IB9jCCAfIwHwYDVR0jBBgwFoAUUWj/kK8CB3U8zNllZGKiErhZcjswHQYDVR0OBBYEFOE+SkyFKYVSu9TAtU26M9VFI5RXMCsGA1UdEQQkMCKCECouYWlyd2F0Y2hxYS5jb22CDmFpcndhdGNocWEuY29tMAsGA1UdDwQEAwIFoDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwdQYDVR0fBG4wbDA0oDKgMIYuaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL3NoYTItaGEtc2VydmVyLWc1LmNybDA0oDKgMIYuaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL3NoYTItaGEtc2VydmVyLWc1LmNybDBMBgNVHSAERTBDMDcGCWCGSAGG/WwBATAqMCgGCCsGAQUFBwIBFhxodHRwczovL3d3dy5kaWdpY2VydC5jb20vQ1BTMAgGBmeBDAECAjCBgwYIKwYBBQUHAQEEdzB1MCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wTQYIKwYBBQUHMAKGQWh0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFNIQTJIaWdoQXNzdXJhbmNlU2VydmVyQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAJUuJroz0tG/rrYK01ZggWiz1Tt6RSh3G24zJQiJf8rueh/CMV4rcz/UIFazb25jNENpdbcbypUXfMN0HdcwGqrNZGWe6WWFux2iH0MbLFjYzmwn4YzHxSCySOaa5Pa4z1l+HFAvn5NvpgJiXdqSalopg78n15BVHvB+dQNVmjeyYyBc3BElgAl+QyBLnWbxRZWwQ1POrTNC5BFB8OLtLtLF8CXT4/13zPgegYYgU8mZ7I66jpiod9VemaTkhkHwWk5yZqDalFhnJ1RaYAfB+9LUY/KBbtfszu/S90Pu77fA2MJ5iLvvps+CCkjED478LFLZpUj9Stj6hstsbGK1wgQ="
#endif

public class AutoDiscoveryService {
    // MARK: Constants
    fileprivate let DomainLookupQuery = "/autodiscovery/awcredentials.aws/v2/domainlookup/domain/"
    fileprivate let DomainLookupWithAuthQuery = "/autodiscovery/DeviceRegistry.aws/v2/domainlookup/domain/"
    fileprivate let SSLPinQuery = "/autodiscovery/HostRegistry.aws?URL="
    fileprivate let authGroupHardCoded = "com.air-watch.mdm.6.4"

    // MARK: properties
    let host: String

    var networkService: CTLService
    internal static var networkManager: SessionManager = SessionManager()

    // MARK: public funcs
    public init?(AutoDiscoveryHost host: String) {
        var urlString = host.lowercased()
        if urlString.hasPrefix("http") == false {
            urlString = "https://\(urlString)"
        }

        guard let _ = URL(string: urlString) else {
            log(error: "AutoDiscovery could not construct URL with given Host String")
            return nil
        }

        self.host = urlString
        self.networkService = CTLService()
    }

    public func requestServerDetails(withDomain domain: String, useHMAC: Bool = false, deviceId: String? = nil, completionHandler: @escaping (_ response: DomainResponseObject?, _ error: NSError?) -> Void) {

        let urlString = self.host + (useHMAC ? DomainLookupWithAuthQuery : DomainLookupQuery) + domain
        log(debug: "Constructing Domain Lookup URL: \(urlString)")
        let url = URL(string: urlString)!

        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "GET"

        let fetcher = self.networkService.fetcherKeeper.fetcherWithRequest(request as URLRequest)

        if useHMAC {
            log(debug: "Domain Lookup is using HMAC")
            guard let deviceId = deviceId else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.missingDeviceIdWhileUsingHMAC.error)
                return
            }

            guard let hmackey = self.hmacKey() else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.genericError.error)
                return
            }
            
            guard let authorizer = DeviceServicesHMACAuthorizer(deviceId: deviceId, authGroup: authGroupHardCoded, hmac: hmackey) else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.genericError.error)
                return
            }
            log(debug: "Authorizer: \(authorizer)")

            fetcher.authorizer = authorizer
        }

        _ = fetcher.beginFetch(on: nil, mayAuthorize: useHMAC) {(rsp: DomainResponseObject?, error: NSError?) in

                            log(debug: "After fetching server details, autodiscovery responded with object: \(rsp.debugDescription)")
                            log(debug: "error: \(error.debugDescription)")

                            if let rsp = rsp {
                                completionHandler(rsp, nil)
                            } else if let error = error {
                                if error.userInfo.count > 0 {
                                    /// Strip any additional Properties from UserInfo.
                                    let outError = NSError(domain: error.domain, code: error.code, userInfo: nil)
                                    completionHandler(nil, outError)
                                } else {
                                    completionHandler(nil, error)
                                }
                            }
        }
    }

    public func requestSSLPin(forAirWatchHost AWHost: String, withConfiguration config: DeviceServicesConfiguration, completionHandler: @escaping (_ response: SSLPinResponseObject?, _ error: NSError?) -> Void) {

        let urlString = self.host + SSLPinQuery + AWHost
        guard let url = URL(string: urlString) else {
            completionHandler(nil, AWError.SDK.Service.AutoDiscovery.invalidInput.error)
            return
        }
        
        AutoDiscoveryService.networkManager.delegate.taskDidReceiveChallengeWithCompletion = { (urlSession: URLSession, urlSessionTask: URLSessionTask, authenticationChallenge: URLAuthenticationChallenge, completion:(URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Void in
            
            guard authenticationChallenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
                completion(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
                return
            }
            
            guard let serverTrust = authenticationChallenge.protectionSpace.serverTrust else {
                completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
                return
            }
            
            let evaluation = AutoDiscoveryService.evaluate(serverTrust: serverTrust, forHost: authenticationChallenge.protectionSpace.host, completion: completion)
            
            if evaluation == false {
                _ = PinnedCertValidationFailureEndpoint.reportCertValidationFailureToServer(awServerUrl: config.airWatchServerURL, onDeviceId: config.deviceId, forChallengedHost: authenticationChallenge.protectionSpace.host)
            }
        }
        
        let networkRequest = AutoDiscoveryService.networkManager.request(url, method: .get).responseData { (networkResponse) in
            
            guard networkResponse.result.isSuccess else {
                if let error = networkResponse.result.error {
                    completionHandler(nil, error as NSError?)
                } else {
                    completionHandler(nil, NSError(domain: "com.air-watch.SDK.CertPinning.AutoDiscovery", code: 1, userInfo: nil))
                }
                return
            }
            
            guard let statusCode = networkResponse.response?.statusCode else {
                completionHandler(nil, NSError(domain: "com.air-watch.SDK.CertPinning.AutoDiscovery", code: 1, userInfo: nil))
                return
            }
            
            switch statusCode {
            case 200: break
                
            case 401: completionHandler(nil, AWError.SDK.Service.AutoDiscovery.unAuthorized.error)
                return
                
            case 403: completionHandler(nil, AWError.SDK.Service.AutoDiscovery.forbidden.error)
                return
                
            case 500: completionHandler(nil, AWError.SDK.Service.AutoDiscovery.serverError.error)
                return
                
            default: log(warning: "Unhandled Status Code.  Continuing by checking for json data in response.")
                break
            }
            
            guard let responseData = networkResponse.result.value else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.invalidServerResponse.error)
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.mutableContainers) else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.invalidServerResponse.error)
                return
            }
            
            guard let jsonDictionary = json as? [String : [String]] else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.invalidServerResponse.error)
                return
            }
            
            let jsonKeys = jsonDictionary.keys
            
            guard jsonKeys.count > 0 else {
                log(debug: "Empty Json object as resposne means there are no Certs to pin.")
                completionHandler(SSLPinResponseObject(host: "", publicKeys: []), nil)
                return
            }
            
            /// This should never throw, but it also unwraps the optional being given.
            guard let hostKey = jsonKeys.first else {
                completionHandler(nil, AWError.SDK.Service.AutoDiscovery.invalidServerResponse.error)
                return
            }
            
            var publicKeys: [String] = []
            
            if let certs = jsonDictionary[hostKey] {
                for cert in certs {
                    publicKeys.append(cert)
                }
            }
            
            let result = SSLPinResponseObject(host: hostKey, publicKeys: publicKeys)
            
            completionHandler(result, nil)
        }
        networkRequest.resume()

    }

    // MARK: Private funcs
    fileprivate func hmacKey() -> Data? {

        let deObfuscator = hmacGenerator()

        let decryptData = deObfuscator.decrypt("llZgGxqt5tJFUTPG6aPFJeC/YlLo9eXQGZNmoWkFt/DvEsMaNQS9uYq1KPpg7nqx")

        return decryptData
    }

    fileprivate struct hmacGenerator: InlineCipherDeObfuscator {
        let phrase: String = "AWReceivedNotification"
        let salt: String = "UYr4df8+D+hJU4df8T+D+hJXm"
    }
    
    private static func getStoredAutodiscoveryCerts() -> [NSData]? {
        
        guard let discoveryProdCert = NSData(base64Encoded: autodiscoverCurrentProductionCert, options: NSData.Base64DecodingOptions(rawValue: 0)),
            let discoveryNexProdCert = NSData(base64Encoded: autodiscoverNextProductionCert, options: NSData.Base64DecodingOptions(rawValue: 0)),
            let discoveryBackupProdCert = NSData(base64Encoded: autodiscoverBackupProductionCert, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                log(error: "Could not retrieve discovery pinnned certs from memory.")
                return nil;
        }
        
        #if DEBUG
            guard let discoveryQACert = NSData(base64Encoded: autodiscoverQACert, options: NSData.Base64DecodingOptions(rawValue: 0)) else {
                log(error: "Could not retrieve QA discovery pinned cert from memory.")
                return nil;
            }
            
            return [discoveryProdCert, discoveryNexProdCert, discoveryBackupProdCert, discoveryQACert]
            
        #else
            return [discoveryProdCert, discoveryNexProdCert, discoveryBackupProdCert]
        #endif
    }
    
    internal static func evaluate(serverTrust: SecTrust, forHost host: String, completion: (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) -> Bool {
        
        guard let serverCert = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            log(error: "Missing server generated certificate from server trust challenge...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        guard let discoveryCertDataArray = self.getStoredAutodiscoveryCerts() else {
            log(error: "Missing Discovery secure data...Cannot validate Discovery service...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        let dispatchQueue = DispatchQueue(label: "DiscoveryCertParsingQueue")
        let certFormat = CertificateFormat.der
        var discoveryCerts: [SecCertificate] = []
        for certData:NSData in discoveryCertDataArray {
            // Can't be certain that parse logic is thread safe, so making it serial.
            dispatchQueue.sync() {
                let certificateData:NSData = certData
                if let currentCert = try? certFormat.parse(certificateData: certificateData as Data) {
                    discoveryCerts.append(currentCert)
                }
            }
        }
        
        guard discoveryCerts.count > 0 else {
            log(error: "Missing Discovery certs...Cannot validate Discovery service...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        let policy = SecPolicyCreateSSL(false, host as CFString?)
        var trust: SecTrust? = nil
        var statusCode = SecTrustCreateWithCertificates(serverCert, policy, &trust)

        guard statusCode == errSecSuccess else {
            log(error: "SecTrustCreateWithCertificates failed with error code \(statusCode)...Cannot validate Discovery service...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        guard let newTrust = trust else {
            log(error: "Unable to create trust object...Cannot validate Discovery service...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        statusCode = SecTrustSetAnchorCertificates(newTrust, discoveryCerts as CFArray)

        guard statusCode == errSecSuccess else {
            log(error: "SecTrustSetAnchorCertificates failed with error code \(statusCode)...Cannot validate Discovery service...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        guard var trustResultType: SecTrustResultType = SecTrustResultType(rawValue: 0) else {
            log(error: "Cannot validate Discovery service...Cancelling Challenge.")
            completion(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
            return false
        }
        
        let status = SecTrustEvaluate(newTrust, &trustResultType)
        log(debug: "While validating Discovery Service, Received status: \(status == errSecSuccess ? "good":"error"), and resultType: \(trustResultType) == \(SecTrustResultType.unspecified)")
        if status == errSecSuccess && trustResultType == SecTrustResultType.unspecified {
            
            let credentialToUse = URLCredential(trust: newTrust)
            completion(URLSession.AuthChallengeDisposition.useCredential, credentialToUse)
        } else {
            // MARK: Soft Fail enabled here
            // TODO: To Disable Soft Fail for this endpoint: Change this AuthChallengeDisposition to Cancel
            completion(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
            return false
        }
        return true
    }
}

// MARK: - Response Object Classes
public final class DomainResponseObject: CTLDataObjectProtocol {

    public let enrollmentUrl: String
    public let enrollmentOrgGroup: String
    public fileprivate(set) var certBase64: String?
    public fileprivate(set) var message: String?
    public fileprivate(set) var status: Int?

    init(enrollUrl: String, orgGroup: String) {
        self.enrollmentUrl = enrollUrl
        self.enrollmentOrgGroup = orgGroup

        self.certBase64 = nil
        self.message = nil
        self.status = nil
    }

    public static func objectWithData(_ data: Data?, additionalProperties: [String: AnyObject]?) throws -> DomainResponseObject {
        let KeyForEnrollmentUrl = "EnrollmentUrl"
        let KeyForGroupId = "GroupId"
        let KeyForCertBase64 = "CertificateBase64"
        let KeyForMessage = "Message"
        let KeyForStatus = "Status"

        if let data = data , data.count > 0 {
            log(debug: "Domain response object string from data: \(String(data: data, encoding: String.Encoding.utf8) ?? "Could not convert data to string")")
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers)

            guard let json = jsonObject as? [String: AnyObject] else {
                throw AWError.SDK.Service.AutoDiscovery.invalidServerResponse
            }

            guard let url = json[KeyForEnrollmentUrl] as? String, let group = json[KeyForGroupId] as? String else {
                throw AWError.SDK.Service.AutoDiscovery.invalidServerResponse
            }

            let result = DomainResponseObject(enrollUrl: url, orgGroup: group)

            /// These are optional values that might or might not be part of the response.
            result.certBase64 = json[KeyForCertBase64] as? String
            result.message = json[KeyForMessage] as? String
            result.status = json[KeyForStatus] as? Int

            return result
        }

        guard let addProps = additionalProperties else {
            throw AWError.SDK.Service.AutoDiscovery.genericError
        }

        if let response = addProps[CTLConstants.kCTLDataObjectURLResponse] as? HTTPURLResponse {

            switch response.statusCode {
            case 200: throw AWError.SDK.Service.AutoDiscovery.invalidServerResponse
            case 204: throw AWError.SDK.Service.AutoDiscovery.domainNotListedOnServer
            case 401: throw AWError.SDK.Service.AutoDiscovery.unAuthorized
            case 403: throw AWError.SDK.Service.AutoDiscovery.forbidden
            case 500: throw AWError.SDK.Service.AutoDiscovery.serverError

            default: break
            }
        }
        throw AWError.SDK.Service.AutoDiscovery.genericError
    } /// End objectWithData method
}

public final class SSLPinResponseObject {

    // FIXME: Should these be optional???
    public let host: String
    public let publicKeys: [String]

    init(host: String, publicKeys: [String]) {
        self.host = host
        self.publicKeys = publicKeys
    }
    
}
