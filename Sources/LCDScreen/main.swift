import SwiftyGPIO
import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

import HD44780LCD

// MARK: - Fact -
struct Fact: Codable {
    let id, text, source: String?
    let sourceURL: String?
    let language: String?
    let permalink: String?
    
    enum CodingKeys: String, CodingKey {
        case id, text, source
        case sourceURL = "source_url"
        case language, permalink
    }
}

// MARK: - End Fact -

// MARK: - News -
struct News: Codable {
    let status: String
    let totalResults: Int
    let articles: [Article]
}

// MARK: - Article
struct Article: Codable {
    let source: Source?
    let author: String?
    let title: String
    let articleDescription: String?
    let url: String?
    let urlToImage: String?
    let publishedAt: String?
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case source, author, title
        case articleDescription = "description"
        case url, urlToImage, publishedAt, content
    }
}

// MARK: - Source
struct Source: Codable {
    let id: String?
    let name: String
}

// MARK: - End News -

// MARK: - TrainInfo -
struct TrainInfo: Codable {
    let departures: [Departure]?
    let generatedAt, locationName, crs: String?
    let filterLocationName, filtercrs: JSONNull?
    let filterType: Int?
    let nrccMessages: [NrccMessage]?
    let platformAvailable, areServicesAvailable: Bool?
}

// MARK: - Departure
struct Departure: Codable {
    let service: Service?
    let crs: String?
}

// MARK: - Service
struct Service: Codable {
    let origin, destination: [Destination]?
    let currentOrigins, currentDestinations: JSONNull?
    let rsid, sta, eta, std: String?
    let etd, platform, serviceOperator, operatorCode: String?
    let isCircularRoute, isCancelled, filterLocationCancelled: Bool?
    let serviceType, length: Int?
    let detachFront, isReverseFormation: Bool?
    let cancelReason, delayReason: JSONNull?
    let serviceID, serviceIDPercentEncoded, serviceIDGUID, serviceIDURLSafe: String?
    let adhocAlerts: JSONNull?
    
    enum CodingKeys: String, CodingKey {
        case origin, destination, currentOrigins, currentDestinations, rsid, sta, eta, std, etd, platform
        case serviceOperator = "operator"
        case operatorCode, isCircularRoute, isCancelled, filterLocationCancelled, serviceType, length, detachFront, isReverseFormation, cancelReason, delayReason, serviceID
        case serviceIDPercentEncoded = "serviceIdPercentEncoded"
        case serviceIDGUID = "serviceIdGuid"
        case serviceIDURLSafe = "serviceIdUrlSafe"
        case adhocAlerts
    }
}

// MARK: - Destination
struct Destination: Codable {
    let locationName, crs: String?
    let via, futureChangeTo: JSONNull?
    let assocIsCancelled: Bool?
}

// MARK: - NrccMessage
struct NrccMessage: Codable {
    let value: String?
}

// MARK: - Encode/decode helpers

class JSONNull: Codable, Hashable {
    
    public static func == (lhs: JSONNull, rhs: JSONNull) -> Bool {
        return true
    }
    
    public var hashValue: Int {
        return 0
    }
    
    public init() {}
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if !container.decodeNil() {
            throw DecodingError.typeMismatch(JSONNull.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for JSONNull"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encodeNil()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(-1)
    }
}

// MARK: - End TrainInfo -

// MARK: - Variables
let width = 20
let height = 4

let formatter = DateFormatter()

let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPi2)
var rs = gpios[.P27]!
var e = gpios[.P22]!
var d4 = gpios[.P25]!
var d5 = gpios[.P24]!
var d6 = gpios[.P23]!
var d7 = gpios[.P18]!
let lcd = HD44780LCD(rs:rs,e:e,d7:d7,d6:d6,d5:d5,d4:d4,width:width,height:height)
var currentScreen = 0
var displayScreens: [[String]] = []
var currentRailScreen = 0
var displayRailScreens: [[String]] = []
var currentFactScreen = 0
var displayFactScreens: [[String]] = []
var currentCalendarScreen = 0
var displayCalendarScreens: [[String]] = []
var currentPage = 0
var fetchNewsDate = Date()
var fetchTrainDate = Date()
var fetchFactDate = Date()
var fetchCalendarDate = Date()

// Interval is in seconds * minutes
let newsFetchInterval: TimeInterval = 60 * 10
let trainFetchInterval: TimeInterval = 60 * 2
let factFetchInterval: TimeInterval = 60 * 30
let calendarFetchInterval: TimeInterval = 60 * 60

// MARK: - URLs
let newsURL = URL(string: "https://newsapi.org/v2/top-headlines?sources=bbc-news&apiKey=2c5ede941f6546c0a3ce330b9c03af8b")!
let trainURL = URL(string: "https://huxley.apphb.com/next/rys/none/ctk?accessToken=3a02290d-e8cc-4eb9-abb2-709ea77e3e69")!
let factURL = URL(string: "https://uselessfacts.jsph.pl/random.json?language=en")!
let calendarURL = URL(string: "http://p57-calendars.icloud.com/published/2/MTMzOTU1MTA3NzEzMzk1NceTE2UwoBF7JX5n7L9RtkzXEF2XkEuP0ZshMqnZSlpxYhAYO8WWRvrmaTab9fyXH8HltnUOIx4RUC-kb8RxmJY")!

// MARK: - News
func loadNews(closure: (()->())? = nil){
    
    let session = URLSession.shared.dataTask(with: newsURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("News error")
            wait(seconds: 6)
            loadNews()
            return
        }
        guard let data = data else {
            print("Empty news data")
            // Handle Empty Data
            wait(seconds: 6)
            loadNews()
            return
        }
        // Handle Decode Data into Model
        fetchNewsDate = Date()
        print("Fetched news: \(Date())")
        
        do {
            let news = try JSONDecoder().decode(News.self, from: data)
            let articles = news.articles
            
            displayScreens = []
            currentScreen = 0
            
            for article in articles {
                let splitHeadline = split(string: article.title)
                displayScreens.append(splitHeadline)
            }
            
            closure?()
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

// MARK: - Calendar
func loadCalendar(closure: (()->())? = nil) {

    let session = URLSession.shared.dataTask(with: calendarURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("Calendar error")
            wait(seconds: 6)
            loadCalendar()
            return
        }
        guard let data = data else {
            print("Empty calendar data")
            // Handle Empty Data
            wait(seconds: 6)
            loadCalendar()
            return
        }
        
        let string = String(data: data, encoding: .utf8)
        let cals = iCal.load(string: string!)
        
        fetchCalendarDate = Date()
        print("Fetched calendar info: \(Date())")
        
        for cal in cals {
            
            displayCalendarScreens = []
            currentCalendarScreen = 0
            fetchCalendarDate = Date()
            
            var sortedEvents: [Event] = []
            var filteredEvents: [Event] = []
            
            let today = Date()
            
            for event in cal.subComponents where event is Event {
                if let event = event as? Event {
                    filteredEvents.append(event)
                }
            }
            
            for event in filteredEvents {
                if let endDate = event.dtend {
                    
                    let today = Date()
                    let nextDate = NSCalendar.current.date(byAdding: .day, value: 14, to: today)!
                    
                    if endDate > today && endDate < nextDate {
                        
                        sortedEvents.append(event)
                    }
                }
            }
            
            sortedEvents.sort { $0.dtend! >= $1.dtend! }

            for event in sortedEvents {
                var splitInfo:[String] = []
                
                if let summary = event.summary {
                    splitInfo = split(string: summary)
                }
                
                if let start = event.dtstart, let end = event.dtend {
                    
                    if start < today {
                        let endDateString = relativeDateString(from: end, showTime: false, capitaliseIn: false)
                        splitInfo.append("Ends \(endDateString)")
                    } else {
                        let startDateString = relativeDateString(from: start, showTime: true)
                        splitInfo.append(startDateString)
                    }
                }
                
                displayCalendarScreens.append(splitInfo)
            }
        }
        closure?()
    }
    session.resume()
}

// MARK: - Train
func loadTrain(closure: (()->())? = nil){
    
    let session = URLSession.shared.dataTask(with: trainURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("Train error")
            wait(seconds: 6)
            loadTrain()
            return
        }
        guard let data = data else {
            print("Empty train data")
            // Handle Empty Data
            wait(seconds: 6)
            loadTrain()
            return
        }
        // Handle Decode Data into Model
        fetchTrainDate = Date()
        print("Fetched train info: \(Date())")
        
        do {
            let trainInfo = try JSONDecoder().decode(TrainInfo.self, from: data)
            var splitInfo:[String] = []
            
            displayRailScreens = []
            currentRailScreen = 0
            
            if let departure = trainInfo.departures?.first {
                if let service = departure.service, let locationName = trainInfo.locationName, let destination = service.destination?.first?.locationName, let standardDeparture = service.std, let estimatedDeparture = service.etd {
                    splitInfo.append("Train service")
                    splitInfo.append("\(locationName) to \(destination)")
                    splitInfo.append("\(standardDeparture) (\(estimatedDeparture))")
                    displayRailScreens.append(splitInfo)
                }
            }
            
            if let nrccMessages = trainInfo.nrccMessages {
                for message in nrccMessages {
                    if let splitMessage = message.value?.split(separator: ".").first {
                        displayRailScreens.append(split(string: String(splitMessage)))
                    }
                }
            }
            
            closure?()
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

// MARK: - Fact
func loadFact(closure: (()->())? = nil){
    
    let session = URLSession.shared.dataTask(with: factURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("Fact error")
            wait(seconds: 6)
            loadFact()
            return
        }
        guard let data = data else {
            print("Empty fact data")
            // Handle Empty Data
            wait(seconds: 6)
            loadFact()
            return
        }
        // Handle Decode Data into Model
        fetchFactDate = Date()
        print("Fetched fact: \(Date())")
        
        do {
            let fact = try JSONDecoder().decode(Fact.self, from: data)

            displayFactScreens = []
            currentFactScreen = 0
            
            if let factText = fact.text {
                var splitFact = split(string: factText)
                splitFact.insert("Fact:", at: 0)
                displayFactScreens.append(splitFact)
            }
            
            closure?()
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

// MARK: - Display
func displayInfo() {
    
    repeat {

        if displayScreens.count != 0 && currentScreen < displayScreens.count {
            
            print("Displaying story \(currentScreen + 1) of \(displayScreens.count)")
        
            let splitHeadline = displayScreens[currentScreen]
            lcd.clearScreen()
            var y = 0

            let startIndex = (currentPage * height)
            let endIndex = min((currentPage * height) + height, splitHeadline.count) // 0 based start

            for line in startIndex ..< endIndex {
                lcd.printString(x: 0, y: y, what: splitHeadline[line], usCharSet: true)
                y += 1
            }
            
            // Have we finished the story, or do we need to scroll to the next page?
            if endIndex == splitHeadline.count {
                currentPage = 0
                currentScreen += 1
            } else {
                currentPage += 1
            }
            
            // Wait for 6 seconds
            wait(seconds: 6)
            
            continue
        } else if displayRailScreens.count != 0 && currentRailScreen < displayRailScreens.count {
            
            print("Displaying rail \(currentScreen + 1) of \(displayScreens.count)")
            
            let splitHeadline = displayRailScreens[currentRailScreen]
            lcd.clearScreen()
            var y = 0
            
            let startIndex = (currentPage * height)
            let endIndex = min((currentPage * height) + height, splitHeadline.count) // 0 based start
            
            for line in startIndex ..< endIndex {
                lcd.printString(x: 0, y: y, what: splitHeadline[line], usCharSet: true)
                y += 1
            }
            
            // Have we finished the story, or do we need to scroll to the next page?
            if endIndex == splitHeadline.count {
                currentPage = 0
                currentRailScreen += 1
            } else {
                currentPage += 1
            }
            
            // Wait for 6 seconds
            wait(seconds: 6)
            
            continue
        } else if displayFactScreens.count != 0 && currentFactScreen < displayFactScreens.count {
            
            print("Displaying fact \(currentFactScreen + 1) of \(displayFactScreens.count)")
            
            let splitHeadline = displayFactScreens[currentFactScreen]
            lcd.clearScreen()
            var y = 0
            
            let startIndex = (currentPage * height)
            let endIndex = min((currentPage * height) + height, splitHeadline.count) // 0 based start
            
            for line in startIndex ..< endIndex {
                lcd.printString(x: 0, y: y, what: splitHeadline[line], usCharSet: true)
                y += 1
            }
            
            // Have we finished the story, or do we need to scroll to the next page?
            if endIndex == splitHeadline.count {
                currentPage = 0
                currentFactScreen += 1
            } else {
                currentPage += 1
            }
            
            // Wait for 6 seconds
            wait(seconds: 6)
            
            continue
        } else if displayCalendarScreens.count != 0 && currentCalendarScreen < displayCalendarScreens.count {
            
            print("Displaying calendar \(currentCalendarScreen + 1) of \(displayCalendarScreens.count)")
            
            let splitHeadline = displayCalendarScreens[currentCalendarScreen]
            lcd.clearScreen()
            var y = 0
            
            let startIndex = (currentPage * height)
            let endIndex = min((currentPage * height) + height, splitHeadline.count) // 0 based start
            
            for line in startIndex ..< endIndex {
                lcd.printString(x: 0, y: y, what: splitHeadline[line], usCharSet: true)
                y += 1
            }
            
            // Have we finished the story, or do we need to scroll to the next page?
            if endIndex == splitHeadline.count {
                currentPage = 0
                currentCalendarScreen += 1
            } else {
                currentPage += 1
            }
            
            // Wait for 6 seconds
            wait(seconds: 6)
            
            continue
        }
        
        if currentScreen == displayScreens.count {
            currentScreen = 0
            
            // Has enough time passed that we need to fetch the news again?
            if fetchNewsDate.timeIntervalSinceNow <= -newsFetchInterval {
                loadNews()
            }
        }
        
        if currentRailScreen == displayRailScreens.count {
            currentRailScreen = 0
        }
        
        if isCorrectDayToLoadTrainFeed() {
            // Has enough time passed that we need to fetch the rail info again?
            if fetchTrainDate.timeIntervalSinceNow <= -trainFetchInterval {
                loadTrain()
            }
        } else {
            displayRailScreens = []
            currentRailScreen = 0
        }
        
        if currentFactScreen == displayFactScreens.count {
            currentFactScreen = 0
            
            // Has enough time passed that we need to fetch the fact again?
            if fetchFactDate.timeIntervalSinceNow <= -factFetchInterval {
                loadFact()
            }
        }
        
        if currentCalendarScreen == displayCalendarScreens.count {
            currentCalendarScreen = 0
            
            // Has enough time passed that we need to fetch the fact again?
            if fetchCalendarDate.timeIntervalSinceNow <= -calendarFetchInterval {
                loadCalendar()
            }
        }
    } while (true)
}

// MARK: - Helper functions
func isCorrectDayToLoadTrainFeed() -> Bool {
    return isThis(days: ["Monday", "Friday"], between: 6, and: 10, forDate: Date())
}

func isThis(days: [String], between minTime: Int, and maxTime: Int, forDate date: Date) -> Bool {
    let weekdays = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday"
    ]
    
    let calendar = Calendar.current
    let components: DateComponents = calendar.dateComponents([.weekday, .hour], from: date)
    let hour = components.hour!
    let computedDay = weekdays[components.weekday! - 1]
    
    return days.contains(computedDay) && hour >= minTime && hour <= maxTime
}

func wait(seconds: UInt32) {
    usleep((seconds * 1000) * 1000)
}

func split(string: String) -> [String] {

    var splitString:[String] = []
    var currentString = ""
    
    let words = string.components(separatedBy: " ")
    
    for word in words {
        if currentString.isEmpty {
            currentString = word
        } else if currentString.count + word.count < 20 {
            currentString += " " + word
        } else {
            splitString.append(currentString)
            currentString = word
        }
    }
    if splitString.last != currentString {
        splitString.append(currentString)
    }

    return splitString
}

func relativeDateString(from date : Date, showTime: Bool = true, capitaliseIn: Bool = true) -> String {
    
    var inWord = "In"
    
    if capitaliseIn == false {
        inWord = "in"
    }
    
    if showTime {
        
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            let startOfNow = calendar.startOfDay(for: Date())
            let startOfTimeStamp = calendar.startOfDay(for: date)
            let components = calendar.dateComponents([.day], from: startOfNow, to: startOfTimeStamp)
            let day = components.day!
            if day < 1 {
                return "\(-day) days ago"
            } else {
                return "\(inWord) \(day) days at \(formatter.string(from: date))"
            }
        }
    } else {
        
        let calendar = Calendar.current
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let startOfNow = calendar.startOfDay(for: Date())
            let startOfTimeStamp = calendar.startOfDay(for: date)
            let components = calendar.dateComponents([.day], from: startOfNow, to: startOfTimeStamp)
            let day = components.day!
            if day < 1 {
                return "\(-day) days ago"
            } else {
                return "\(inWord) \(day) days"
            }
        }
    }
}

// MARK: - Lifecycle
func loadFeeds() {
    print("\nLoading Feeds")
    loadNews() {
        loadFact() {
            if isCorrectDayToLoadTrainFeed() {
                loadTrain() {
            
                }
            }
            loadCalendar()
        }
    }
}

formatter.dateFormat = "HH:mm"
loadFeeds()
displayInfo()

repeat {
} while (true)
