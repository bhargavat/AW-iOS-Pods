//
//  AWCommandRetriever.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

internal protocol CommandRetrieverDelegate: class {

    func failedToRetrieveCommand(error: NSError)

    func commandAvailableToProcess(command: Command)

    func finishedRetrievingCommands()

    func acknowledged(command: Command?, status: AWServices.CommandStatus, error: NSError?)
}

internal protocol CommandRetriever: class {
    weak var delegate: CommandRetrieverDelegate? { get set }
    var deviceServices: DeviceServices? { get set }
    var context: SDKContext { get set }

    func startLoadingCommands()
    func acknowledgeCommand(command: Command, response: CommandResponse)
}

extension CommandRetriever {

    func startLoadingCommands() {
        let hmacToken: String = self.context.applicationIdentity?.authorization?.hmacToken ?? ""
        guard let hmacData: Data = hmacToken.data(using: String.Encoding.utf8) else {
            log(error: "hmac nil")
            return
        }

        self.deviceServices?.startLoadingCommands(decryptionKey: hmacData) {[weak self] (command, error) in
            if let error = error {
                self?.delegate?.failedToRetrieveCommand(error: error)
            }

            if let command = command {
                self?.delegate?.commandAvailableToProcess(command: command)
            } else {
                self?.delegate?.finishedRetrievingCommands()
            }
        }
    }
    
    func acknowledgeCommand(command: Command, response: CommandResponse) {

        let hmacToken: String = self.context.applicationIdentity?.authorization?.hmacToken ?? ""
        guard let hmacData: Data = hmacToken.data(using: String.Encoding.utf8) else {
            log(error: "hmac nil")
            return
        }

        self.deviceServices?.acknowledgeCommand(command, response: response, commandDecryptKey: hmacData) {[unowned self] (command, error) in
            var status = AWServices.CommandStatus.acknowledged
            if error != nil {
                status = AWServices.CommandStatus.error
            }
            self.delegate?.acknowledged(command: command, status: status, error: error)
            if let error = error {
                self.delegate?.failedToRetrieveCommand(error: error)
            }

            if let command = command {
                self.delegate?.commandAvailableToProcess(command: command)
            }
            // If there are no more commands, 0 bytes is returned from the server and thus command will be nil and error will also be nil
            if command == nil && error == nil {
                self.delegate?.finishedRetrievingCommands()
            }
        }
    }
}
