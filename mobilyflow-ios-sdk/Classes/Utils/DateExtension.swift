//
//  DateExtension.swift
//  AppForgeTestApple
//
//  Created by Gregoire Taja on 27/01/2025.
//

import Foundation

extension Date {
    func isSameDay(_ other: Date) -> Bool {
        return Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isAfterDay(_ other: Date) -> Bool {
        return !self.isSameDay(other) && self > other
    }

    func isBeforeDay(_ other: Date) -> Bool {
        return !self.isSameDay(other) && self > other
    }

    /*
     Return the number of days between self an other (truncated to Int).
     If other is before self, result is positive, else it's negative.
     */
    func dayUntil(_ other: Date) -> Int {
        return Int((self.timeIntervalSince1970 - other.timeIntervalSince1970) / (24 * 3600))
    }
}
