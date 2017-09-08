//
//  AWSDKError_RSAAA.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public extension AWError.SDK {
    enum RSAAA: AWSDKErrorType {
        case generic
        case workSpace
        case invalidUserStatus
        case invalidStatus
        case challengeTokenAuth
        case challengeNewPinFromSystem
        case challengeNewPinFromUser
        case challengeNextTokenAuthAfterNewPinSet
        case challengeNextTokenAuth
        case authenticationInProgress
        case needAuthentication
        case actionCancelled
        case answerEmpty
        case answerNotInCorrectFormat
        case actionInprogress
    }

}

public extension AWError.SDK.RSAAA {
    var code: Int {
        switch self {
        // The code start from 50 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWSDKErrors_Private.h
        case .generic,
             .workSpace,
             .invalidUserStatus,
             .invalidStatus,
             .challengeTokenAuth,
             .challengeNewPinFromSystem,
             .challengeNewPinFromUser,
             .challengeNextTokenAuthAfterNewPinSet,
             .challengeNextTokenAuth,
             .authenticationInProgress, 
             .needAuthentication:
            return _code + 50
        // The code start from 55000 because of the corresponding value in the old SDK (5.9)
        // Location in old SDK: AWSDKErrors_Private.h
        case .actionCancelled: return 55000
        case .answerEmpty: return 55001
        case .answerNotInCorrectFormat: return 55002
        case .actionInprogress: return 55003
        }
    }
    
    var localizableInfo: String? {
        switch self {
        case .generic,
             .workSpace,
             .invalidStatus:
            return "ChallengeServerError"
        case .invalidUserStatus:
            return "ChallengeLocked"
        case .challengeTokenAuth:
            return "ChallengeTokenAuth"
        case .challengeNewPinFromSystem:
            return "ChallengeNewPinFromSystem"
        case .challengeNewPinFromUser:
            return "ChallengeNewPinFromUser"
        case .challengeNextTokenAuthAfterNewPinSet:
            return "ChallengeNextTokenAuthAfterNewPinSet"
        case .challengeNextTokenAuth:
            return "ChallengeNextTokenAuth"
        default:
            return nil
        }
    }
    
    var localizableAnswer: String?  {
        switch self {
        case .challengeTokenAuth:
            return "AnswerPlaceHolderPinAndSecureIDToken"
        case .challengeNewPinFromSystem:
            return "AnswerPlaceHolderNewPin"
        case .challengeNewPinFromUser:
            return "AnswerPlaceHolderNewPin"
        case .challengeNextTokenAuthAfterNewPinSet:
            return "AnswerPlaceHolderPinAndSecureIDToken"
        case .challengeNextTokenAuth:
            return "AnswerPlaceHolderPinAndSecureIDToken"
        default:
            return nil
        }
    }
    
    var userInfo: AWErrorInfoDict? {
        var userInfoDict: AWErrorInfoDict = _userInfo ?? [:]
        userInfoDict["LocalizedAnswer"] = localizableAnswer
        return userInfoDict.isEmpty ? nil : userInfoDict
    }
}
