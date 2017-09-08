//
//  NSDateHelpers.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
let SpecialLocalesToFixYearFormat = ["ja_JP", "ko_KR", "zh-Hans"]
let AirWatchDefaultDateFormat = "yyyy-MM-dd'T'HH:mm:s.SS"
let GMTDateFormat = "yyyy-MM-dd'T'HH:mm:ss"
let ContentParserGMTDateFormat = "yyyy-MM-dd'T'HH:mm:s"

extension DateFormatter {

    public static var shortDateStyleFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return DateFormatter.polishFormatStringForSpecialLocales(formatter.dateFormat)
    }

    public static var shortDateTimeStyleFormat: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return DateFormatter.polishFormatStringForSpecialLocales(formatter.dateFormat)
    }

    public static var GMTDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = GMTDateFormat
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        return formatter
    }

    public static var GMTDateFormatterPOSIXLocale: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = GMTDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        return formatter
    }

    public static var ContentParserGMTDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = ContentParserGMTDateFormat
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
        return formatter
    }


    fileprivate static func polishFormatStringForSpecialLocales(_ format: String) -> String {
        let currentLocaleIdentifier = Locale.autoupdatingCurrent.identifier
        var resultingFormat = format
        for locale in SpecialLocalesToFixYearFormat {
            if (currentLocaleIdentifier.range(of: locale) != nil) {
                if (format.range(of: "yyyy") == nil && format.range(of: "yy") != nil) {
                    resultingFormat = format.replacingOccurrences(of: "yy", with: "yyyy")
                }
            }
        }

        return resultingFormat
    }
}

extension Date {
    public static func GMTDate() -> Date {
        let formatter = DateFormatter.GMTDateFormatter
        return formatter.date(from: formatter.string(from: Date()))!
    }
}

extension NSDate {
    @objc
    public static func aw_gmtDate() -> NSDate {
        return Date.GMTDate() as NSDate
    }
}
