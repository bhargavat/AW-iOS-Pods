//
//  InterrogatorEndpoint.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWNetwork
import AWError
import Foundation

public extension AWServices {
    
    public enum DataSamplerFlags: UInt8 {
        case flagDataResponse = 6
        case flagReady = 16
        case flagError = 64
        case flagReadyResponse = 80
        case flagData = 128
        case flagUnknown = 192
    }
}

internal enum PacketPlatformType: UInt8 {
    case platformWindowsMobile = 1
    case platformIOS = 2
    case platformBlackBerry = 3
    case platformSymbian = 4
    case platforAndroid = 5
}

internal enum DataSamplerPacketPayload {
    case readyPacket(type: PacketPlatformType, udid: String)
    case dataPacket(type: PacketPlatformType, udid: String, data: Data)

    func data() -> Data {
        switch self {
        case let .readyPacket(platformType, udid):
            return build(platformType, udid: udid, data: nil)
        case let .dataPacket(platformType, udid, data):
            return build(platformType, udid: udid, data: data)
        }
    }

    fileprivate func build(_ type: PacketPlatformType, udid: String, data: Data?) -> Data {
        let mutable = NSMutableData()

        var platformID = UInt16(type.rawValue)
        mutable.append(&platformID, length: MemoryLayout<UInt16>.size)

        //        let udidData = udid.data(using: String.Encoding.utf16)
        //        /// Expect first two bytes are BOM [Byte Order Mark](https://en.wikipedia.org/wiki/Byte_order_mark)
        //        var udidDataSize: Int32 = ((udidData?.count) != nil) ? Int32((udidData?.count)! - 2) : 0
        //        mutable.append(&udidDataSize, length: MemoryLayout<Int32>.size)

        var udidDataSize: Int32 =  0
        let udidData = udid.data(using: String.Encoding.utf16)
        if let udidData = udidData {
            /// Expect first two bytes are BOM [Byte Order Mark](https://en.wikipedia.org/wiki/Byte_order_mark)
            udidDataSize = Int32(udidData.count - 2)
        }
        mutable.append(&udidDataSize, length: MemoryLayout<Int32>.size)

        if let data = data {
            var dataSize = Int32(data.count)
            mutable.append(&dataSize, length: 4)
        }
        /// First two bytes are BOM
        if let udidData = udidData , udidDataSize > 0 {
            mutable.append(udidData.subdata(in: 2..<udidData.count))
        }

        if let sampleData = data , sampleData.count > 0 {
            mutable.append(sampleData)
        }

        return mutable.copy() as! Data
    }
}


public struct DataSamplerPacket {
    public init?(data: Data) {
        if (data.count >= 18) {
            var flag: UInt8 = 0
//            data.copyBytes(to: &flag, from: Range(uncheckedBounds: (lower: 1, upper: 1)))
            data.copyBytes(to: &flag, from: 1..<2)
            if let flags = AWServices.DataSamplerFlags(rawValue: flag) {
                self.flags = flags
            } else {
                /**
                    FIXME: At this moment, no full documentation can be found for all flag values, so
                           it would be safer to fail if the value is unknown here.
                 */
                return nil
            }
            self.token = data.subdata(in: 2..<18)
            self.payload = data.count - 18 > 0 ? data.subdata(in: 18..<(data.count)) : nil
        } else {
            return nil
        }
    }

    /**
        `DataSamplerPacket` is the client side representation of interrogator payload
     
        - Parameter flags: The flag to be understood by client and server
        - Parameter token: 16 bytes fix length data. It is usually coming from server response.
        - Parameter payload: The protocol payload data to be understood by server.
     */
    public init(flags: AWServices.DataSamplerFlags, token: Data? = nil, payload: Data? = nil) throws {
        self.flags = flags
        if let t = token , t.count != 16 {
            throw AWError.SDK.Service.Interrogator.invalidTokenLength
        }

        self.token = token
        self.payload = payload
    }

    public var flags: AWServices.DataSamplerFlags = .flagError
    public var token: Data? = nil
    public var payload: Data? = nil

    public mutating func data() -> Data {
        let mutable = NSMutableData()
        // Reserved
        if let appendData = NSMutableData(length: 1) {
            mutable.append(appendData as Data)
        }

        var flagValue = self.flags.rawValue
        mutable.append(&flagValue, length: 1)
        if let token = self.token {
            mutable.append(token.subdata(in: 0..<16))
        } else {
            if let appendData = NSMutableData(length: 16) {
                mutable.append(appendData as Data)
            }
        }

        if let payload = self.payload {
            var length: Int32 = Int32(payload.count)
            mutable.append(&length, length: 4)
            mutable.append(payload)
        } else {
            var zero: Int32 = 0
            mutable.append(&zero, length: 4)
        }

        return mutable.copy() as! Data
    }
}


public typealias DataSampleTransmissionCompletion = (_ packet: DataSamplerPacket?, _ error: NSError?) -> Void

internal class InterrogatorEndpoint: DeviceServicesEndpoint {
    let kInterrogatorEndpoint = "/deviceservices/Interrogator/InterrogatorHandler.ashx"
    
    required init(config: DeviceServicesConfiguration, authorizer: CTLAuthorizationProtocol?, validator: CTLResponseValidationProtocol?) {
        super.init(config: config, authorizer: authorizer, validator: validator)
        self.serviceEndpoint = kInterrogatorEndpoint
    }

    func sendDataSamplerPacket(flags: AWServices.DataSamplerFlags,
                               token: Data? = nil,
                               payload: Data? = nil,
                               completion: @escaping DataSampleTransmissionCompletion) {        
        guard self.endpointURL != nil else {
            completion(nil, AWError.SDK.Service.General.invalidHTTPURL("\(hostUrlString), \(serviceEndpoint)").error)
            return
        }

        if let t = token , t.count != 16 {
            completion(nil, AWError.SDK.Service.Interrogator.invalidTokenLength.error)
            return
        }

        do {
            var packet = try DataSamplerPacket(flags: flags, token: token, payload: payload)
            let packetData = packet.data()
            
            guard let endpointURL = endpointURL else {
                completion(nil, AWError.SDK.Service.General.invalidHTTPURL("nil").error)
                return
            }
            _ = self.fetchURL(endpointURL,
                          dataToPost: packetData,
                          ETag: nil,
                          httpMethod: "POST",
                          mayAuthorize: true,
                          executingQuery: nil) {
                            (rsp: Data?, error: NSError?) in
                            if (error != nil) {
                                completion(nil, error)
                            } else if let rsp = rsp {
                                if let packet = DataSamplerPacket(data: rsp) {
                                    completion(packet, nil)
                                } else {
                                    completion(nil, AWError.SDK.Service.General.unexpectedResponse.error)
                                }
                            } else {
                                completion(nil, AWError.SDK.Service.General.unexpectedResponse.error)
                            }
            }
        } catch let err {
            completion(nil, (err as! AWSDKErrorType).error)
        }
    }

    override internal func requestForURL(_ url: URL,
                                         ETag: String?,
                                         httpMethod: String,
                                         additionalHeaders: [String: String]?) -> NSMutableURLRequest? {
        let request = super.requestForURL(url, ETag: ETag, httpMethod: httpMethod, additionalHeaders: additionalHeaders)
        request?.requestType = "interrogator"
        return request
    }
}
