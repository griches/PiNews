import Foundation

/// TODO add documentation
public struct Event {
    public var subComponents: [CalendarComponent] = []
    public var otherAttrs = [String:String]()

    // required
    public var uid: String!
    public var dtstamp: Date!

    // optional
    // public var organizer: Organizer? = nil
    public var location: String?
    public var summary: String?
    public var descr: String?
    // public var class: some enum type?
    public var dtstart: Date?
    public var dtend: Date?

    public init(uid: String? = NSUUID().uuidString, dtstamp: Date? = Date()) {
        self.uid = uid
        self.dtstamp = dtstamp
    }
}

extension Event: CalendarComponent {
    public func toCal() -> String {
        var str: String = "BEGIN:VEVENT\n"

        if let uid = uid {
            str += "UID:\(uid)\n"
        }
        if let dtstamp = dtstamp {
            str += "DTSTAMP:\(dtstamp.toString())\n"
        }
        if let summary = summary {
            str += "SUMMARY:\(summary)\n"
        }
        if let descr = descr {
            str += "DESCRIPTION:\(descr)\n"
        }
        if let dtstart = dtstart {
            str += "DTSTART:\(dtstart.toString())\n"
        }
        if let dtend = dtend {
            str += "DTEND:\(dtend.toString())\n"
        }

        for (key, val) in otherAttrs {
            str += "\(key):\(val)\n"
        }

        for component in subComponents {
            str += "\(component.toCal())\n"
        }

        str += "END:VEVENT"
        return str
    }
}

extension Event: IcsElement {
    public mutating func addAttribute(attr: String, _ value: String) {
        
        switch attr {
        case "UID":
            let endIndex = value.index(value.endIndex, offsetBy: -1)
            let truncatedValue = value.substring(to: endIndex)
            uid = truncatedValue
        case "DTSTAMP":
            let endIndex = value.index(value.endIndex, offsetBy: -1)
            let truncatedValue = value.substring(to: endIndex)
            dtstamp = truncatedValue.toDate()
        case "DTSTART;TZID=Europe/London":
            let endIndex = value.index(value.endIndex, offsetBy: -1)
            let truncatedValue = value.substring(to: endIndex)
            dtstart = truncatedValue.toDate()
        case "DTEND;TZID=Europe/London":
            let endIndex = value.index(value.endIndex, offsetBy: -1)
            let truncatedValue = value.substring(to: endIndex)
            dtend = truncatedValue.toDate()
        // case "ORGANIZER":
        //     organizer
        case "SUMMARY":
            
            if value.contains("\r") {
                let endIndex = value.index(value.endIndex, offsetBy: -1)
                let truncatedValue = value.substring(to: endIndex)
                summary = truncatedValue
            } else {
                summary = value
            }
        case "DESCRIPTION":
            descr = value
        default:
            otherAttrs[attr] = value
        }
    }
}

extension Event: Equatable { }

public func ==(lhs: Event, rhs: Event) -> Bool {
    return lhs.uid == rhs.uid
}

extension Event: CustomStringConvertible {
    public var description: String {
        return "\(dtstamp.toString()): \(summary ?? "")"
    }
}
