/*
 See LICENSE folder for this sample’s licensing information.
 */

import Foundation

extension Date {
    @MainActor
    func dayAndTimeText(locale: Locale, resolver: LocalizedStringResolver) -> String {
        let timeText = formatted(
            Date.FormatStyle(date: .omitted, time: .shortened)
                .locale(locale)
        )
        if locale.calendar.isDateInToday(self) {
            return resolver.string(
                "date.today.at",
                bundle: .main,
                arguments: [timeText]
            )
        } else {
            let dateText = formatted(
                Date.FormatStyle()
                    .month(.abbreviated)
                    .day()
                    .locale(locale)
            )
            return resolver.string(
                "%@ at %@",
                bundle: .main,
                arguments: [dateText, timeText]
            )
        }
    }

    @MainActor
    func dayText(locale: Locale, resolver: LocalizedStringResolver) -> String {
        if locale.calendar.isDateInToday(self) {
            return resolver.string("date.today", bundle: .main)
        } else {
            return formatted(
                Date.FormatStyle()
                    .month()
                    .day()
                    .weekday(.wide)
                    .locale(locale)
            )
        }
    }
}
