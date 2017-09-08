//
//  PolicyManager.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWHelpers
import AWServices
import Foundation
//
//enum Status {
//    case Complete
//    case InProgress
//    case Failed
//}
//
//struct EnforcementStatus {
//    var status: Status
//    var error: ErrorType?
//}
//
//
//// MARK: - Policy Delegate Protocol
//protocol PolicyManagementDelegate: class {
//    func configurationApplied(policyManager: PolicyManager, policyEnforced: String, policyStatus: EnforcementStatus)
//}

// MARK: - PolicyManager
//class PolicyManager: PolicyDelegate {
//
//    private let context: SDKContext
//    weak var delegate: PolicyManagementDelegate?
//    let enforceAndWaitQueue: NSOperationQueue
//    let enforceAndGoQueue: NSOperationQueue
//
//    private var backgroundPolicies: Array<PolicyEnforcementOperation> = []
//    private var waitForPolicies: Array<PolicyEnforcementOperation> = []
//
//    private(set) var currentStatus: Dictionary<String, EnforcementStatus> = [:]
//
//    // MARK: Initialization
//    init(context: SDKContext) {
//        self.context = context
//        self.enforceAndWaitQueue = NSOperationQueue()
//        self.enforceAndGoQueue = NSOperationQueue()
//
//        if enforceAndWaitQueue.maxConcurrentOperationCount > 1 {
//            enforceAndWaitQueue.maxConcurrentOperationCount = 1
//        }
//        enforceAndWaitQueue.name = "enforceAndWaitQueue"
//
//        if enforceAndGoQueue.maxConcurrentOperationCount > 4 {
//            enforceAndGoQueue.maxConcurrentOperationCount = 4
//        }
//        enforceAndGoQueue.name = "enforceAndGoQueue"
//
//        /// Protect against something having previously suspended the operation queues.
//        enforceAndWaitQueue.suspended = false
//        enforceAndGoQueue.suspended = false
//    }
//
//    deinit {
//        self.enforceAndWaitQueue.cancelAllOperations()
//        self.enforceAndGoQueue.cancelAllOperations()
//    }
//
//    // MARK: Work
//    func applyConfiguration(profile: AWServices.Profile) -> Void {
//
//        /// Policy Manager will wait for these to complete or fail before continuing on with execution.
//        /// All waited for Enforcers will run in sequence serially on a single operationQueue.
//        let RestrictionsEnforcer = RestrictionsPolicyEnforcer(payload: profile.restrictionsPayload, context: self.context)
//        addNewPolicyEnforcer(RestrictionsEnforcer, waitForEnforcement: true)
//        log(verbose: "Restrictions Enforcer created with payload: \(profile.restrictionsPayload)")
//
//        let authenticationEnforcer = AuthenticationPolicyEnforcer(payload: profile.authenticationPayload, context: self.context)
//        addNewPolicyEnforcer(authenticationEnforcer, waitForEnforcement: true)
//        log(verbose: "Auth Enforcer created with payload: \(profile.authenticationPayload)")
//
//        let proxyEnforcer = ProxyPolicyEnforcer(payload: profile.proxyPayload, context: self.context)
//        addNewPolicyEnforcer(proxyEnforcer, waitForEnforcement: true)
//        log(verbose: "Proxy Enforcer created with payload: \(profile.proxyPayload)")
//
//        let networkAccessEnforcer = NetworkAccessPolicyEnforcer(payload: profile.networkAccessPayload, context: self.context)
//        addNewPolicyEnforcer(networkAccessEnforcer, waitForEnforcement: true)
//        log(verbose: "Network Enforcer created with payload: \(profile.networkAccessPayload)")
//
//        let identityEnforcer = IdentityPolicyEnforcer(payload: profile.identityPayload, context: self.context)
//        addNewPolicyEnforcer(identityEnforcer, waitForEnforcement: true)
//        log(verbose: "Identity Enforcer created with payload: \(profile.identityPayload)")
//
//        log(verbose: "Now creating Enforcer's to be waited on...")
//        /// Policy Manager will NOT wait for these Enforcers, and these Enforcers will be added to a concurrent queue.
//        let AnalyticsEnforcer = AnalyticsPolicyEnforcer(payload: profile.analyticsPayload, context: self.context)
//        addNewPolicyEnforcer(AnalyticsEnforcer)
//        log(verbose: "Analytics Enforcer created with payload: \(profile.analyticsPayload)")
//
//        let ComplianceEnforcer = CompliancePolicyEnforcer(payload: profile.compliancePayload, context: self.context)
//        addNewPolicyEnforcer(ComplianceEnforcer)
//        log(verbose: "Compliance Enforcer created with payload: \(profile.compliancePayload)")
//
//        let brandingEnforcer = BrandingPolicyEnforcer(payload: profile.brandingPayload, context: self.context)
//        addNewPolicyEnforcer(brandingEnforcer)
//        log(verbose: "Branding Enforcer created with payload: \(profile.brandingPayload)")
//
//        let loggingEnforcer = LoggingPolicyEnforcer(payload: profile.loggingPayload, context: self.context)
//        addNewPolicyEnforcer(loggingEnforcer)
//        log(verbose: "Logging Enforcer created with payload: \(profile.loggingPayload)")
//
//        let offlineAccessEnforcer = OfflineAccessPolicyEnforcer(payload: profile.offlineAccessPayload, context: self.context)
//        addNewPolicyEnforcer(offlineAccessEnforcer)
//        log(verbose: "OfflineAccess Enforcer created with payload: \(profile.offlineAccessPayload)")
//
//        let certificateEnforcer = CertificatePolicyEnforcer(payload: profile.certificatePayload, context: self.context)
//        addNewPolicyEnforcer(certificateEnforcer)
//        log(verbose: "Certificate Enforcer created with payload: \(profile.certificatePayload)")
//
//        let sslPinningEnforcer = SSLPinningPolicyEnforcer(payload: profile.sslPinningPayload, context: self.context)
//        addNewPolicyEnforcer(sslPinningEnforcer)
//        log(verbose: "SSLPinning Enforcer created with payload: \(profile.sslPinningPayload)")
//
//        self.enforcePolicies()
//    }
//
//    // MARK: Private queue and delegate Work
//    private func enforcePolicies() -> Void {
//
//        self.enforceAndGoQueue.addOperations(backgroundPolicies, waitUntilFinished: false)
//
//        self.enforceAndWaitQueue.addOperations(waitForPolicies, waitUntilFinished: true)
//        log(verbose: "Have completed/failed all enforcement that was required to wait for.")
//    }
//
//    private func addNewPolicyEnforcer(policyEnforcer: PolicyEnforcementOperation, waitForEnforcement: Bool = false) {
//        currentStatus[policyEnforcer.payloadType] = EnforcementStatus(status: .InProgress, error: nil)
//        if waitForEnforcement {
//            waitForPolicies.append(policyEnforcer)
//        } else {
//            backgroundPolicies.append(policyEnforcer)
//        }
//        policyEnforcer.delegate = self
//    }
//
//    static let syncQueue: dispatch_queue_t = dispatch_queue_create("EnforcementStatusUpdateQueue", nil)
//
//    // MARK: - Policy Delegate Protocol Methods
//    func policyEnforced(payloadType: String, status: EnforcementStatus) {
//
//        dispatch_async(PolicyManager.syncQueue) { [weak self] in
//            self?.currentStatus[payloadType] = status
//
//            if let delegate = self?.delegate {
//                delegate.configurationApplied(self!, policyEnforced: payloadType, policyStatus: status)
//            }
//        }
//    }
//
//    func policyFailedToEnforce(payloadType: String, error: ErrorType) {
//        NSLog("Received Error while enforcing Payload, \(payloadType), \(error)")
//        policyEnforced(payloadType, status: EnforcementStatus(status: .Failed, error: error))
//    }
//}
