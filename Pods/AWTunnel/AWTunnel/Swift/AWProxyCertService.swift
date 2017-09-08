//
//  AWProxyCertService.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWServices
import AWCMWrapper
import Foundation

import AWCrypto

@objc
open class AWProxyCertService: NSObject {
    fileprivate let deviceServices: DeviceServices

    public init(deviceServices: DeviceServices) {
        self.deviceServices = deviceServices

        //XXX: clear keychain for testing
        //Settings.store().clear(SecureItemType.ProxyMAGCertificate)

        super.init()
    }

    
    internal static func clearMAGCert() -> Error? {
        let result = Settings.store.clear(SecureItemType.proxyMAGCertificate)
        if let notification = AWTunnelServiceNotifications.MAGCertCleared.getNotifcation() {
            NotificationCenter.default.post(notification)
        }
        log(info: "MAG cleared result : \(result.error?.description ?? "No Error")")
        return result.error
    }
    

    
    open func fetchAndStoreCertWithCompletion(_ completion: @escaping (_ success: Bool, _ error: NSError?) -> Void) {
        
        self.deviceServices.fetchProxyCertificates { (certificate: ProxyCertificateInfo?, error: NSError?) in
            
            log(info: "MAG cert fetch Prcocess complete");
            if (error != nil) {
                log(error: "MAG cert fetch Completed with error \(error?.description)");
                completion(false, error)
            } else if let cert = certificate {
                if let passwd = self.deviceServices.config.bundleId.data(using: String.Encoding.utf8),
                   let fipsCert = self.convertP12CertificateToFIPS(cert.certificateData, password: passwd) {
                    /// Clear cert
                    var result = AWProxyCertService.clearMAGCert()
                    if let err = result {
                        log(error: "Error clearing MAG cert \(err)")
                    } else {
                        log(info: "MAG cert cleared")
                    }
                    

                    /// Store cert
                    guard Settings.store.set(SecureItemType.proxyMAGCertificate,
                                               value: fipsCert).isSuccess else {
                            log(error: "cannot store the value for 'proxy mag certificate' to the keychain")
                            //TODO: Error
                            completion(false, nil)
                            return
                    }
                    
                    
                    if let certHash = fipsCert.sha256  {
                        log(info: "Stored new cert ::::\(certHash.map { String(format: "%02x", $0) }.joined())")
                    }
                    
                    log(info: "MAG cert fetch new cert stored");
                    completion(true, nil)
                } else {
                    //TODO: Error
                    log(error: "cannot convert MAG cert to FIPS compliant cert")
                    completion(false, nil)
                }
            } else {
                log(error: "MAG cert fetch completed with no certificate");
                completion(false, nil)
            }
        }
    }

    open class func signingCertificate() -> Data? {
        let valueResult:StorageResult = Settings.store.get(SecureItemType.proxyMAGCertificate, valueType: SettingType.object)
        if valueResult.isSuccess, let value: Data = valueResult.value() {
            return value
        }
        return nil
    }

    open func signingCertificate() -> Data? {
        return AWProxyCertService.signingCertificate()
    }

    open class func deviceRootCertificate() -> Data? {
        var certLines:[String] = []
        certLines.append("MIIJCQIBAzCCCM8GCSqGSIb3DQEHAaCCCMAEggi8MIIIuDCCA28GCSqGSIb3DQEHBqCCA2AwggNcAgEA")
        certLines.append("MIIDVQYJKoZIhvcNAQcBMBwGCiqGSIb3DQEMAQMwDgQIhrq986o36wMCAggAgIIDKMknnFWDDGiZHq1H")
        certLines.append("ECXFsgQ5pTxK0DMuqTpP54Zg4j6ibC+SxCkux5MKXiWAa7h58dB6n7bVXmJZeZzqvG8z3wa4wl5pv1oK")
        certLines.append("mECaZ4ktDNggu/cBYmWsdqARNu7LuMP9vuf5QA8NGoSbFjymHdc+qfyAWw1oVJ7foD6OjSPR+SQ582GE")
        certLines.append("DDdyNRgWpbFWc/UpnmfxPhWhDXrPSNSd1J52KlA7Tv91g/NaVkEQc0wInOB7W/2ZAw5RP511Vv5671+i")
        certLines.append("fGKwc3jc6Jv6WL/oD7G8CrjyL6ba8LUT0R/SLdboU5kUikyiThRM8h4vXtq4vaQN92SYWh4FWMeMD1Mb")
        certLines.append("avDaIaEjY35nLlf5XNfjB2MKK1HaAQndkjOWx+4IO5vAeButm6gICkKrkwa4Is6ycHVSth2Wo3hLRUsk")
        certLines.append("o8EP2M8mBNB5VbzoHjVZZS1vNzU+tM+m1s0l20tLldvEZ5Zp7Yk+U8y4EsHF7gEK/2pz0f2cAsaNvFBZ")
        certLines.append("rPMI775xF9lLn4YXe9u3R0QMmMHazG1eSqZc4AXG2MVsHrUsT9YnxW9Q2K9Axw2TPnNZ+j3DADD6/V0n")
        certLines.append("8wW5bG+YglAu+XGF59JC9zCewJeraijf2SdQIYuJhJxfoDUmxi3UrDouyn4teVR+Gogxik1CD2P69fnz")
        certLines.append("CxiS4gDF6o0zRs2j10FkloNDIK8TfTurmbOEM3sRdMW0b7oHtMBYILXtutARDW+6cTUt1uF9MTpl81o4")
        certLines.append("8nAuCPhfAUhTtCvCylEx3RZmmh1IaJTc3j5EmW1TZLl0Qv5tJg0Li7ATOlbaYiN4qKAzWbdYnjk179v5")
        certLines.append("FsD1bKVIF80HiXC7CymHV70LSmMR9NEjcfb05uLloiz052pYqzcfXd3bq/As6g4bdwJlZmEZnLeO1J/R")
        certLines.append("MW68ajGEzRGa5N2OeLgQBOLsD4rAwgWHZS8Oj3Gr4g0Xm9MuUvf9ArjhbgJmIrZB+E4lhwNYMuO8+xQA")
        certLines.append("wHdEahADu7fasHWn1WQjuZ90SfGUNiSFRLXyxueFRyzx6ts53qwFjCischAtsOdRELHSfGebt576jXiK")
        certLines.append("hdwrQ752WgqxkLB5uxxuPdEwggVBBgkqhkiG9w0BBwGgggUyBIIFLjCCBSowggUmBgsqhkiG9w0BDAoB")
        certLines.append("AqCCBO4wggTqMBwGCiqGSIb3DQEMAQMwDgQIieMsqup5ydgCAggABIIEyK0qo5YgK24ondaa7F9EzmNx")
        certLines.append("iLB/YfFuftcI/+Hkj4qCegJ+TTsYvIyfplcp3EccPo6zmstZrspSyEjxdXhrUeY3/pgMboHB5wiV3igZ")
        certLines.append("HxrHKJR5Dn687TgD/EwbAOrIzyrLoRxqdB6b1RqQEr72nhBVQuDmugtUarT/iB50A5EGJKvOyqxm38iO")
        certLines.append("6ZSebDLEney9K4x2BlNhPZPaR66uDkVHcevmjIypXaPEfe1icIi1AUJeNDpyWtpIJ78EeenKbxItlnM1")
        certLines.append("8S1Ly1s6c4bLAUwWUHUfgkDEYoxQseMeZpVe9eg3L2m1DWRbNN3mXzcERefSuvNw8u8v5qK9fdqENoVh")
        certLines.append("cibUkTwN2zlZoQYCrILPos9WHhe7lgh+6VeaIcG/ZpzN4fiPclGq9+WVH64uElHS+XdZR+5se/Gknfke")
        certLines.append("cTebi7mnLze18pyZrdhXC4dx6PLLecuPfRSbRM593deq8x/GjNa4JYWB4aI9UmJ4jjEefwKiwUHO1zQk")
        certLines.append("KRtNEQYkvt9ayeMdVPc0wVg1McoBooOa44di02OJVJMf65VvUyM8VFwnzwcMzJY5bQCYFiJN2MK+E7N+")
        certLines.append("xb02Dodsh3JLELohB79dCrGs9zzRdhZTQumMHkFobkhod5g5zebyFgJZryU7JuuFmqrX+qydbDii8SAs")
        certLines.append("phkXs5o0+ZmuhfxONGpwdKJew5ETmS9PT0QbixMyu5duP/W6b6p3RYPMO0JBrHkkhTkRL0EyJqlPuOfE")
        certLines.append("RsWmKhGePRsqujjnQBWv+s/j+j2pkDv5yS2s4yKi/Ibq+BSu12xH7XScty/IPAPZ7Bwpt2Hl0evv98oM")
        certLines.append("V9cSTSfn4dait8gAA2AFTqBWHuRGVY81oHtrVg04sqy+V5c2FSe5/LNtpVhen/u5O+BhyjsIxRR4FBAg")
        certLines.append("jokvhXd7yXMdkbW9GeE+LRcpurcOMtdu3498AImt7aR1SCQeNohLRFOTZyZisBULsFwa0ipbQl/zHaNN")
        certLines.append("Su2HB7FVz/30CUW8h/1Zr7sk253r8LtBUEE0kUUex2iFg0If5AbhrB7Isu3LkoSggcuqrAblX90Xgqy/")
        certLines.append("hcxy6MRqKIKrMpRzDLFyLXrFQOc4ma51xE7XoRpxDofJ7476BZwiT4X7ZzM8jXA9s6y3+cS3D3jf2AY/")
        certLines.append("ZUKqsdX288Xlh6wSeJA1iQL5mxqApDXlqBz/xpUWPVLdZJvghi95/pmufdVzXDcJNNMqCGXEkm/iYLyu")
        certLines.append("PcZ4cONqygo3wHd31VU3qIrhLY3qPU8F0HR8OV7u3fIT7i3mLv5RwQjRhQRr4A9fMFtTuR7M4OCJOhU9")
        certLines.append("rjCsuzaDy+9IYUkhCpKVKdzFck0ap+nqKOrPS5z3kftYlw/vR3JMuZ+NYALL/46EUkSEJ6rK90H2yl2H")
        certLines.append("HtcntrAAPHfr9FDMGdg9DXN6nR20sCGOtQLuRxbo96BduREhzZHbpgKypW3948JjIJY6in5e+hs5Evj4")
        certLines.append("xNH7VEMPKt0KmkrM8eD2mMteE+ChT7DB2iNE6UwPCmqUoCt0NhcWl0so+tqbqObmEwIy4zH5evDh1M11")
        certLines.append("kq+/Q2DMA0y82YifUpi6mk8XFlWpGDsNoSnVhyBsrGuM7XcXiAV08TUrK06kFCgbetsDuAZLb2tBYm5C")
        certLines.append("dMBb1SUJODElMCMGCSqGSIb3DQEJFTEWBBSvAO04l/QV1ZfWjP3eNeox8ecJYzAxMCEwCQYFKw4DAhoF")
        certLines.append("AAQUWkGCBlJJX9qUrJrby1/DjI2zdDwECPfVHgxjV54+AgIIAA==")
        
        return certLines.joined(separator: "").data(using: String.Encoding.utf8)
    }

    open func convertP12CertificateToFIPS(_ cert: Data, password: Data) -> Data? {
        if let passwdStr = NSString(bytes: (password as NSData).bytes, length: password.count, encoding: String.Encoding.utf8.rawValue) {
            return AWPKCS12Helper.exportToFIPS(fromPKCS12Data: cert, password: passwdStr as String)
        } else {
            return nil
        }
    }

}
