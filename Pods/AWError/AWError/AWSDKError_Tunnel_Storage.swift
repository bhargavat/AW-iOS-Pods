//
//  AWSDKError_Tunnel_Storage.swift
//  AWError
//
//  Created by "Liu, Troy" on 8/30/16.
//  Copyright © 2016 vmware. All rights reserved.
//

import Foundation

public extension AWError.SDK.Tunnel {
    enum Storage: AWSDKErrorType {
        case keychainAuthError
        case keychainError
        case keychainPersistenceError
        case storageGenericError
        case storageOpenError
        case storageSaveError
        case storageTypeMismatchError
        case unknownKeychainType
        case userDefaultSettingsError
    }
}

public extension AWError.SDK.Tunnel.Storage {
    var code: Int {
        return _code + 5001
    }
    
    var localizableInfo: String? {
        switch self {
        case .keychainAuthError:
            return "Unable to write to / read from keychain due to authorization error"
        case .keychainError:
            return "Generic Keychain Error"
        case .keychainPersistenceError:
            return "Unable to persist an item to the keychain"
        case .storageGenericError:
            return "Generic Storage failure"
        case .storageOpenError:
            return "Denotes that a persistent store errored on a open operation"
        case .storageSaveError:
            return "Denotes that a persistent store errored on a save operation"
        case .storageTypeMismatchError:
            return "Denotes a store access which does not match the specified type"
        case .unknownKeychainType:
            return "Denotes invalid keychain request type during retrieval"
        case .userDefaultSettingsError:
            return "Error occurred when writing or reading from UDS"
        }
    }
}
