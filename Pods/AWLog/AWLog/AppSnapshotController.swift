//
//  AppSnapshotController.swift
//  AWLog
//
//  Copyright © 2016 VMware, Inc. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the United States and
//  other countries as well as by international treaties.
//  AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc(AWAppSnapshotReporter)
public protocol AppSnapshotReporter {

    var snapshotReport: String { get }

    @objc optional
    var snapshotReportTitle: String { get }
}

private extension AppSnapshotReporter {

    var formattedReport: String {
        let reportSectionSeperator = "======================================"
        let sectionTitle = self.snapshotReportTitle ?? String(describing: type(of: self))
        let reportItems = ["", sectionTitle, reportSectionSeperator, self.snapshotReport, reportSectionSeperator]
        return reportItems.joined(separator: "\n")
    }

}

extension DateFormatter {
    fileprivate static func snapshottimestampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .full
        return formatter
    }
}

@objc(AWAppSnapshotController)
open class AppSnapshotController: NSObject {
    @objc
    open static let sharedInstance = AppSnapshotController()


    fileprivate var reporters: [AppSnapshotReporter] = []
    fileprivate static let timestampFormatter = DateFormatter.snapshottimestampFormatter()
    fileprivate var timestamp: String {
        return AppSnapshotController.timestampFormatter.string(from: Date())
    }

    fileprivate var applicationID: String? {
        return Bundle.main.bundleIdentifier
    }

    fileprivate var reportHeader: String {
        let headerSeperator = "*****************************************************************"
        let reportItems = [headerSeperator,
                           "*",
                           "* AirWatch App Diagnostics",
                           "* Timestamp: \(self.timestamp)",
                           "* Application Id: \(String(describing: self.applicationID))",
                           "*",
                           headerSeperator ]
        return reportItems.joined(separator: "\n")
    }

    @objc
    open func register(_ snapshotReporter: AppSnapshotReporter) {
        if (self.reporters.index(where: {$0 === snapshotReporter}) == nil) {
            self.reporters.append(snapshotReporter)
        }
    }

    @objc
    open func remove(_ snapshotReporter: AppSnapshotReporter) {
        if let index = self.reporters.index(where: {$0 === snapshotReporter}) {
            self.reporters.remove(at: index)
        }
    }

    @objc
    open func generateReport() -> String {
        guard self.reporters.count > 0 else {
            return ""
        }
        
        var report = self.reportHeader
        self.reporters.forEach { (reporter) in
            report.append(reporter.formattedReport)
        }
        return report
    }

    internal func removeAllReporters() {
        self.reporters.removeAll()
    }
}
