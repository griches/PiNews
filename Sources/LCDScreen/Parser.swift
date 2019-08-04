import Foundation

/// TODO add documentation
internal class Parser {
    let icsContent: [String]

    init(_ ics: [String]) {
        icsContent = ics
    }

    func read() throws -> [iCalendar] {
        var completeCal = [iCalendar?]()

        // Such state, much wow
        var inCalendar = false
        var currentCalendar: iCalendar?
        var inEvent = false
        var currentEvent: Event?
        var inAlarm = false
        var currentAlarm: Alarm?

        for (_ , line) in icsContent.enumerated() {
            switch line {
            case "BEGIN:VCALENDAR\r":
                inCalendar = true
                currentCalendar = iCalendar(withComponents: nil)
                continue
            case "END:VCALENDAR\r":
                inCalendar = false
                completeCal.append(currentCalendar)
                currentCalendar = nil
                continue
            case "BEGIN:VEVENT\r":
                inEvent = true
                currentEvent = Event()
                continue
            case "END:VEVENT\r":
                inEvent = false
                currentCalendar?.append(component: currentEvent)
                currentEvent = nil
                continue
            case "BEGIN:VALARM\r":
                inAlarm = true
                currentAlarm = Alarm()
                continue
            case "END:VALARM\r":
                inAlarm = false
                currentEvent?.append(component: currentAlarm)
                currentAlarm = nil
                continue
            default:
                break
            }

            guard let (key, value) = line.toKeyValuePair(splittingOn: ":") else {
                // print("(key, value) is nil") // DEBUG
                continue
            }

            if inCalendar && !inEvent {
                currentCalendar?.addAttribute(attr: key, value)
            }

            if inEvent && !inAlarm {
                currentEvent?.addAttribute(attr: key, value)
            }

            if inAlarm {
                currentAlarm?.addAttribute(attr: key, value)
            }
        }

        return completeCal.flatMap{ $0 }
    }
}
