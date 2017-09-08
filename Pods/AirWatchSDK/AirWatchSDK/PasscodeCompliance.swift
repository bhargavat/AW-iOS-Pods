//
//  PasscodeComplianceDetector.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWPresentation
import AWServices
import AWLocalization
import AWStorage

class PasscodeCompliance: PasscodeComplianceProtocol {
    var dataStore: SDKContext

    ///Default Values
    var passcodeMode: AWSDK.PasscodeMode = .off
    var allowSimpleValues: Bool = true
    var minimumPasscodeLength: Int = 0
    var minimumComplexChars: Int = 0
    var passcodeHistoryRequirement: Int = 0 /// The number of previous passcodes that the new passcode cannot match
    var maximumPasscodeAgeInDays: Int = Int.max
    var passcodeSetDate: Date? = nil
    var passcodeHistory: [[Data: Data]]? = nil
    var checkHistoryRequirement: Bool = false ///This is used for forgot passcode flow; temporary incase user remebers their passcode
    var checkPasscodeAge: Bool = false /// This should only be used when checking the currently set passcode, not when creating a new passcode
    fileprivate var currentPasscodeHash: [Data: Data]? = nil

    init(dataStore: SDKContext) {
        self.dataStore = dataStore

        guard let sdkProfile: Profile = self.dataStore.SDKProfile else {
            log(error: "Error: No SDK Profile found in datastorage")
            return
        }
        guard let authenticationPayload: AuthenticationPayload = sdkProfile.authenticationPayload else {
            log(error: "Error: No AuthenticationPayload Profile found in datastorage")
            return
        }
        
        passcodeMode = authenticationPayload.passcodeMode
        allowSimpleValues = authenticationPayload.allowSimple
        minimumPasscodeLength = authenticationPayload.minimumPasscodeLength
        minimumComplexChars = authenticationPayload.minimumComplexCharacters
        passcodeHistoryRequirement = authenticationPayload.minimumUniquePasscodesBeforeReuse
        maximumPasscodeAgeInDays = authenticationPayload.maximumPasscodeAge
        if let setDate: Date = dataStore.currentPasscodeSetDate as Date? {
            passcodeSetDate = setDate
        }
        if let passcodeHistory: [[Data:Data]] = dataStore.passcodeHistory {
            self.passcodeHistory = passcodeHistory
        }
    }

    //MARK:- Passcode Validation Methods
    func passcodeCompliesWithRestrictions(_ passcode: String?) -> PasscodeComplianceResult {
        log(debug: "Validating that the new passcode option complies with restrictions from AuthenticationPayload")
        
        guard let passcode: String = passcode else {
            log(debug: "New passcode option is nil; returning nonCompliant status")
            return ComplianceResult(compliant: false, complianceMessage: "")
        }

        ///check length first
        guard passcode.characters.count >= minimumPasscodeLength else {
            log(debug: "New passcode option is too short; returning nonCompliant status")
            if passcodeMode == .numeric {
                return ComplianceResult(compliant: false, complianceMessage: numericPasscodeTooShortMessage())
            } else {
                return ComplianceResult(compliant: false, complianceMessage: alphaNumericPasscodeTooShortMessage())
            }
        }
        
        //validate simple or complex
        if allowSimpleValues {
            return validateSimplePasscode(passcode)
        } else {
            return validateComplexPasscode(passcode)
        }
    }

    //Validation requires that:
    // (1) Passcode is not an empty strng
    // (2) All characters in passcode are of decimalDigitCharacterSet if Numeric Passcode or of alphanumericCharacterSet if Alphanumeric passcode requirement
    internal func validateSimplePasscode(_ passcode: String) -> PasscodeComplianceResult {
        guard passcode != "" else { /// is not an empty string
            return ComplianceResult(compliant: false, complianceMessage: "")
        }
        
        let legalCharactersComplianceResult: PasscodeComplianceResult = passcodeContainsLegalCharacters(passcode)
        guard legalCharactersComplianceResult.compliant else {
            return legalCharactersComplianceResult
        }
        
        let minNumberComplexCharactersComplianceResult: PasscodeComplianceResult = passcodeHasMinimumNumberComplexCharacters(passcode)
        guard minNumberComplexCharactersComplianceResult.compliant else {
            return minNumberComplexCharactersComplianceResult
        }
        
        if checkHistoryRequirement {
        	let passcodeHistoryComplianceResult: PasscodeComplianceResult = passcodeIsHistoryCompliant(passcode)
        	guard passcodeHistoryComplianceResult.compliant else {
            	return passcodeHistoryComplianceResult
			}
        }
        
        if checkPasscodeAge {
        	let passcodeAgeComplianceResult: PasscodeComplianceResult = passcodeIsAgeCompliant()
        	guard passcodeAgeComplianceResult.compliant else {
            	return passcodeAgeComplianceResult
			}
        }
        return ComplianceResult(compliant: true, complianceMessage: "")
    }

    //Validation requires that:
    // (1) Passcode is not an empty string
    // (2) Passcode is not ascending or decending
    // (3) All characters in passcode are of decimalDigitCharacterSet if Numeric Passcode or of alphanumericCharacterSet if Alphanumeric passcode requirement
    // (4) Passcode has the minimum number of complex characters
    // (5) Passcode does not match the indicated number of previous passcodes
    internal func validateComplexPasscode(_ passcode: String) -> PasscodeComplianceResult {
        guard passcode != "" else { /// is not an empty string
            return ComplianceResult(compliant: false, complianceMessage: "")
        }
        
        let notAscendingAndNotDecendingComplianceResult: PasscodeComplianceResult = passcodeIsNotAscendingAndNotDecending(passcode)
        guard notAscendingAndNotDecendingComplianceResult.compliant else {
            return notAscendingAndNotDecendingComplianceResult
        }
        
        let legalCharactersComplianceRestult: PasscodeComplianceResult = passcodeContainsLegalCharacters(passcode)
        guard legalCharactersComplianceRestult.compliant else {
            return legalCharactersComplianceRestult
        }
        
        let minNumberComplexCharactersComplianceResult: PasscodeComplianceResult = passcodeHasMinimumNumberComplexCharacters(passcode)
        guard minNumberComplexCharactersComplianceResult.compliant else {
            return minNumberComplexCharactersComplianceResult
        }
        if checkHistoryRequirement {
        	let passcodeHistoryComplianceResult: PasscodeComplianceResult = passcodeIsHistoryCompliant(passcode)
        	guard passcodeHistoryComplianceResult.compliant else {
            	return passcodeHistoryComplianceResult
			}
        }
        if checkPasscodeAge {
        	let passcodeAgeComplianceResult: PasscodeComplianceResult = passcodeIsAgeCompliant()
        	guard passcodeAgeComplianceResult.compliant else {
            	return passcodeAgeComplianceResult
			}
        }
        return ComplianceResult(compliant: true, complianceMessage: "")
    }

    //MARK:- Previous Passcode History Check Mutating Methods
    internal func addPasscodeToHistory(passcode: String) {
        log(debug: "Adding passcode hash entry to passcodeHistory in datastore")
        self.currentPasscodeHash = getCurrentPasscodeHash(passcodeStr: passcode)
        guard let currentHash: [Data: Data] = self.currentPasscodeHash else {
            log(error: "Failed to add passcode hash to passcodeHistory: No passcode hash to add")
            return /// no current Passcode
        }
        self.passcodeHistory = addHashToFrontOfHashArray(currentHash, hashArray: self.passcodeHistory)
        dataStore.passcodeHistory = addHashToFrontOfHashArray(currentHash, hashArray: dataStore.passcodeHistory)
        log(debug: "Successfully added passcode hash entry to passcodeHistory in datastore")
    }
    
    //MARK:- Helper Methods
    internal func passcodeIsNotAscendingAndNotDecending(_ passcode: String) -> PasscodeComplianceResult {
        let passcodeLength: Int = passcode.characters.count
        let nonComplianceLength: Int = (passcodeLength - 1)

        var sameDigitCount: Int = 0
        var nonComplianceCount: Int = 0

        ///get int values for characters
        let charactersUInt16: [UInt16] = Array(passcode.utf16)
        var characterInts: [Int] = []
        for char: UInt16 in charactersUInt16 {
            characterInts.append(Int(char))
        }

        var previousDigit = characterInts[0]
        var nextDigit: Int = 0

        var index: Int = 1
        while index < characterInts.count {
            nextDigit = characterInts[index]
            var diff: Int = nextDigit - previousDigit

            if ((passcodeLength - index) > 1) {
                let secondNextDigit: Int = characterInts[index+1]
                let secondNextDigitDiff: Int = (secondNextDigit - previousDigit)

                /// check for 3 Consecutive digit or Alphabets
                if (((1 == diff) && (2 == secondNextDigitDiff)) || ((-1 == diff) && (-2 == secondNextDigitDiff))) {
                    return ComplianceResult(compliant: false, complianceMessage: passcodeCannotBeRepeatingAscendingDescendingMessage())
                }
            }

            ///update nonCompliantCount and sameDigitCount
            diff = abs(diff)
            if( 1 == diff || ((AWSDK.PasscodeMode.numeric == passcodeMode) && (9 == diff))) {
                nonComplianceCount += 1
            } else if ( 0 == diff ) {
                sameDigitCount += 1
            }
            previousDigit = nextDigit
            index += 1
        }

        if(nonComplianceCount == nonComplianceLength) {
            return ComplianceResult(compliant: false, complianceMessage: passcodeCannotBeRepeatingAscendingDescendingMessage())
        } else if(sameDigitCount > 0 ) {
            return ComplianceResult(compliant: false, complianceMessage: passcodeCannotBeRepeatingAscendingDescendingMessage())
        }
        return ComplianceResult(compliant: true, complianceMessage: "")
    }

    internal func passcodeHasMinimumNumberComplexCharacters(_ passcode: String) -> PasscodeComplianceResult {
        if passcodeMode == AWSDK.PasscodeMode.numeric {
            return ComplianceResult(compliant: true, complianceMessage: "")
        }

        let complexCharSet: CharacterSet = CharacterSet(charactersIn: ("~!@#$%^&*_-+=`|\\(){}[]:;\"'<>,.?/"))
        var complexCharCount: Int = 0

        ///get unichar values for characters
        let charactersUInt16: [UInt16] = Array(passcode.utf16)
        var characters: [unichar] = []
        for char: unichar in charactersUInt16 {
            characters.append(char)
        }

        var index: Int = 0
        while (index < characters.count) {
            let char: unichar = characters[index]
            if let unicodeScalarchar = UnicodeScalar(char), complexCharSet.contains(unicodeScalarchar) {
                complexCharCount += 1
            }
            index += 1
        }

        if complexCharCount < minimumComplexChars {
            return ComplianceResult(compliant: false, complianceMessage: passcodeMinmumComplexCharactersMessage())
        } else {
            return ComplianceResult(compliant: true, complianceMessage: "")
        }
    }

    internal func passcodeContainsLegalCharacters(_ passcode: String) -> PasscodeComplianceResult {
        let passcodeMode: AWSDK.PasscodeMode = self.passcodeMode
        if passcodeMode == AWSDK.PasscodeMode.alphanumeric {
            ///passcode must contain atleast 1 number
            let decimalRange = passcode.rangeOfCharacter(from: CharacterSet.decimalDigits, options: NSString.CompareOptions(), range: nil)
            let containsAtleast1Number: Bool = decimalRange != nil
            ///passcode must not contain only numbers
            let containsOnlyNumbers: Bool = CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: passcode))
            if (containsAtleast1Number && !containsOnlyNumbers) {
                return ComplianceResult(compliant: true, complianceMessage:"")
            } else {
                return ComplianceResult(compliant: false, complianceMessage: alphaNumericPasscodeSimpleInstructionMessage())
            }
        }
        return ComplianceResult(compliant: true, complianceMessage:"") ///Default to valid since we know that it is of valid length even though there is no passcodemode setting
    }
    

    internal func passcodeIsAgeCompliant() -> PasscodeComplianceResult {
        let now: Date = Date()

        if maximumPasscodeAgeInDays <= 0 {
            log(verbose: "Maximum passcode age is <= 0 days. returning back-> no action")
            return ComplianceResult(compliant: true, complianceMessage: "")

        }
        guard let setDate: Date = passcodeSetDate else {
            log(error: "No Set Date for passcode")
            return ComplianceResult(compliant: true, complianceMessage: "")
        }

        let difference: TimeInterval = now.timeIntervalSince(setDate)
        let maximumPasscodeAge: TimeInterval = Double(maximumPasscodeAgeInDays) * (60*60*24) /// convert to seconds

        if difference >= maximumPasscodeAge {
            // passocde Age expired prompt user to change passocde
            log(info: "Passcode Age has expired.. need to change it")
            return ComplianceResult(compliant: false, complianceMessage: "Passcode Age has expired")
        }
        return ComplianceResult(compliant: true, complianceMessage: "")
    }

    internal func passcodeIsHistoryCompliant(_ passcode: String) -> PasscodeComplianceResult {
        let history: [[Data:Data]] = passcodeHistory ?? [] ///default to empty array if passcodeHistory is nil
        if (passcodeHistoryRequirement == 0 || history.count == 0) {
            log(debug: "no passcodeHistoryRequirement or no passcodes in history")
            return ComplianceResult(compliant: true, complianceMessage: "")
        }

        ///only check the number of pervious passcodes == passcodeHistoryRequirement
        for (index, previousPasscodeValue) in history.enumerated() where index < passcodeHistoryRequirement {
            if match(passcode, previousPinValue:previousPasscodeValue) {
                log(debug: "passcode matches a previous passcode")
                return ComplianceResult(compliant: false, complianceMessage: passcodeHistoryRequirementViolationMessage())
            }
        }
        return ComplianceResult(compliant: true, complianceMessage: "")
    }

    //MARK: - Private Passcode Hashing Methods
    fileprivate func getCurrentPasscodeHash(passcodeStr: String) -> [Data: Data]? {
        return createPasscodeHistoryEntry(pin: passcodeStr, salt: nil)
    }

    fileprivate func match(_ passcode: String, previousPinValue: [Data:Data]) -> Bool {
        for (salt, previousPasscodeHash) in previousPinValue {
            if let newPasscodeHash: [Data: Data] = self.createPasscodeHistoryEntry(pin: passcode, salt: salt) {
                if newPasscodeHash[salt] == previousPasscodeHash {
                    return true
                } // else keep looping
            }
        }
        return false
    }

    fileprivate func createPasscodeHistoryEntry(pin: String, salt: Data?) -> [Data: Data]? {
    
        guard var passcodeData = pin.data(using: String.Encoding.utf8) else {
            log(error: "Could not create crypt key for passcode history check")
            return nil
        }
        let tmpSalt = salt ?? Data.randomData(count: 16)
        passcodeData.append(tmpSalt)

        guard let passcodeHash = passcodeData.sha512 else {
            log(error: "Could not create hashkey for passcode history check: SHA512 hash failed")
            return nil
        }

        return [tmpSalt: passcodeHash]
    }

    //Purpose of this method is to prevent duplications
    fileprivate func addHashToFrontOfHashArray(_ hash: [Data: Data], hashArray: [[Data: Data]]?) -> [[Data: Data]]? {
        var newHashArray: [[Data: Data]] = hashArray ?? []
        for storedHash: [Data: Data] in newHashArray {
            if NSDictionary(dictionary: hash).isEqual(to: storedHash) {
                log(error: "Error: hash to add already exists in the current hash Array")
                return hashArray // they match so this passcode is already in this array of hashes so return original array
            }
        }
        newHashArray.insert(hash, at: 0)
        return newHashArray
    }

    //MARK: Compliance Messages Convience Methods
    
    fileprivate func removeUnneedCharacters(_ string: String) -> String {
        var newString = string.replacingOccurrences(of: "\n ", with: "")
        newString = newString.replacingOccurrences(of: ":", with: "")
        newString = newString.replacingOccurrences(of: "-", with: "")
        newString = newString.replacingOccurrences(of: "(", with: "")
        newString = newString.replacingOccurrences(of: ")", with: "")
        return newString
    }
    
    fileprivate func numericPasscodeTooShortMessage() -> String {
        var numericPasscodeTooShortMessage: String = AWSDKLocalization.getLocalizationString("MimimumPasscodeLength")
        numericPasscodeTooShortMessage = (numericPasscodeTooShortMessage as NSString).replacingOccurrences(of: "%d", with: "\(minimumPasscodeLength)")
        numericPasscodeTooShortMessage = removeUnneedCharacters(numericPasscodeTooShortMessage)
        return numericPasscodeTooShortMessage
    }
    
    fileprivate func alphaNumericPasscodeTooShortMessage() -> String {
        /// minimum passcode length rule
        var alphaNumericpasscodeTooShortMessage: String =  AWSDKLocalization.getLocalizationString("MimimumPasscodeLength")
        alphaNumericpasscodeTooShortMessage = (alphaNumericpasscodeTooShortMessage as NSString).replacingOccurrences(of: "%d", with: "\(minimumPasscodeLength)")
        alphaNumericpasscodeTooShortMessage = removeUnneedCharacters(alphaNumericpasscodeTooShortMessage)
        return alphaNumericpasscodeTooShortMessage
    }
    
    fileprivate func alphaNumericPasscodeSimpleInstructionMessage() -> String {
        var alphaNumericSimplePasscodeInstruction = AWSDKLocalization.getLocalizationString("YourPasscodeShould") + AWSDKLocalization.getLocalizationString("AlphaNumericSimplePasscodeInstrution")
        alphaNumericSimplePasscodeInstruction = removeUnneedCharacters(alphaNumericSimplePasscodeInstruction)
        return alphaNumericSimplePasscodeInstruction
    }
    
    fileprivate func passcodeHistoryRequirementViolationMessage() -> String {
        var passcodeHistoryMessage: String = AWSDKLocalization.getLocalizationString("YourPasscodeShould") + AWSDKLocalization.getLocalizationString("PasscodeHistoryInstruction")
        passcodeHistoryMessage = (passcodeHistoryMessage as NSString).replacingOccurrences(of: "%d", with: "\(passcodeHistoryRequirement)")
        passcodeHistoryMessage = removeUnneedCharacters(passcodeHistoryMessage)
        return passcodeHistoryMessage
    }
    
    fileprivate func passcodeCannotBeRepeatingAscendingDescendingMessage() -> String {
        var repeatingAscendingDescendingMessage = AWSDKLocalization.getLocalizationString("YourPasscodeShould") + AWSDKLocalizedString("DontAllowSimpleNumericPasscodeInstrution")
        repeatingAscendingDescendingMessage = removeUnneedCharacters(repeatingAscendingDescendingMessage)
        return repeatingAscendingDescendingMessage
    }
    
    fileprivate func passcodeMinmumComplexCharactersMessage() -> String {
        var complexCharRule = AWSDKLocalization.getLocalizationString("YourPasscodeShould") + AWSDKLocalization.getLocalizationString("ComplexSymbolsRequiredInstruction")
        complexCharRule = (complexCharRule as NSString).replacingOccurrences(of: "%d", with: "\(minimumComplexChars)")
        complexCharRule = removeUnneedCharacters(complexCharRule)
        return complexCharRule
    }
    
    //MARK:- Accessing Current Passcode Restrictions
    func getPasscodeRestrictions() -> String {
        var supportedPasscodePolicyRule = AWSDKLocalization.getLocalizationString("YourPasscodeShould")

        switch passcodeMode {
        case .off:
            break

        case .numeric:
            /// minimum passcode length rule
            var minPasscodeLengthRule: String = AWSDKLocalization.getLocalizationString("NumericPasscodeLengthInstruction")
            minPasscodeLengthRule = (minPasscodeLengthRule as NSString).replacingOccurrences(of: "%d", with: "\(minimumPasscodeLength)")

            supportedPasscodePolicyRule = supportedPasscodePolicyRule + minPasscodeLengthRule

        case .alphanumeric:
            //minimum passcode length
            var minPasscordCharLengthRule = AWSDKLocalization.getLocalizationString("AlphaNumericPasscodeLengthInstruction")
            minPasscordCharLengthRule = (minPasscordCharLengthRule as NSString).replacingOccurrences(of: "%d", with: "\(minimumPasscodeLength)")
            supportedPasscodePolicyRule = supportedPasscodePolicyRule + minPasscordCharLengthRule

            //alpha numeric
            let alphaNumericSimplePasscodeInstrution = AWSDKLocalization.getLocalizationString("AlphaNumericSimplePasscodeInstrution")
            supportedPasscodePolicyRule = supportedPasscodePolicyRule + alphaNumericSimplePasscodeInstrution

            if(minimumComplexChars > 0) {
                var complexCharRule = AWSDKLocalization.getLocalizationString("ComplexSymbolsRequiredInstruction")
                complexCharRule = (complexCharRule as NSString).replacingOccurrences(of: "%d", with: "\(minimumComplexChars)")
                supportedPasscodePolicyRule = supportedPasscodePolicyRule + complexCharRule
            }        
        }

        ///shouldnt allow simple values rule
        if(!allowSimpleValues) {
            let allowSimpleValueInstruction: String = AWSDKLocalization.getLocalizationString("DontAllowSimpleNumericPasscodeInstrution")
            supportedPasscodePolicyRule = supportedPasscodePolicyRule + allowSimpleValueInstruction
        }
        /// Cannot Match Previous Passcodes
        if (passcodeHistoryRequirement > 0) {
            var passcodeHistoryMessage: String = AWSDKLocalization.getLocalizationString("PasscodeHistoryInstruction")
            passcodeHistoryMessage = (passcodeHistoryMessage as NSString).replacingOccurrences(of: "%d", with: "\(passcodeHistoryRequirement)")
            supportedPasscodePolicyRule = supportedPasscodePolicyRule + passcodeHistoryMessage
        }
        return supportedPasscodePolicyRule
    }
}

struct ComplianceResult: PasscodeComplianceResult {
    public var complianceMessage: String
    public var compliant: Bool
    
    init(compliant: Bool, complianceMessage: String) {
        self.compliant = compliant
        self.complianceMessage = complianceMessage
    }
}
