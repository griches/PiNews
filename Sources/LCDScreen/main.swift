import SwiftyGPIO
import Foundation
import Glibc
import HD44780LCD

// MARK: - Fact
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

// MARK: - End Fact

// MARK: - News
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

// MARK: - End News

// MARK: - TrainInfo
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

// MARK: - End TrainInfo

let width = 20
let height = 4

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
var currentPage = 0
var fetchNewsDate = Date()
var fetchTrainDate = Date()
var fetchFactDate = Date()

// Interval is in seconds * minutes
let newsFetchInterval: TimeInterval = 60 * 10
let trainFetchInterval: TimeInterval = 60 * 2
let factFetchInterval: TimeInterval = 60 * 30

let newsURL = URL(string: "https://newsapi.org/v2/top-headlines?sources=bbc-news&apiKey=2c5ede941f6546c0a3ce330b9c03af8b")!
let trainURL = URL(string: "https://huxley.apphb.com/next/rys/none/ctk?accessToken=3a02290d-e8cc-4eb9-abb2-709ea77e3e69")!
let factURL = URL(string: "https://uselessfacts.jsph.pl/random.json?language=en")!

func loadNews(closure: (()->())? = nil){
    
    let session = URLSession.shared.dataTask(with: newsURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("News error")
            usleep(6000 * 1000)
            loadNews()
            return
        }
        guard let data = data else {
            print("empty news data")
            // Handle Empty Data
            usleep(6000 * 1000)
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

func loadTrain(closure: (()->())? = nil){
    
    let session = URLSession.shared.dataTask(with: trainURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("Train error")
            usleep(6000 * 1000)
            loadTrain()
            return
        }
        guard let data = data else {
            print("empty train data")
            // Handle Empty Data
            usleep(6000 * 1000)
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

func loadFact(closure: (()->())? = nil){
    
    let session = URLSession.shared.dataTask(with: factURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("Fact error")
            usleep(6000 * 1000)
            loadFact()
            return
        }
        guard let data = data else {
            print("empty fact data")
            // Handle Empty Data
            usleep(6000 * 1000)
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
            usleep(6000 * 1000)
            
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
            usleep(6000 * 1000)
            
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
            usleep(6000 * 1000)
            
            continue
        }
        
        print("\n\nResetting\n\n")
        
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
    } while (true)
}

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

func loadFeeds() {
    print("🥰 LOADING FEEDS")
    loadNews() {
        loadFact() {
            if isCorrectDayToLoadTrainFeed() {
                loadTrain()
            }
        }
    }
}

loadFeeds()
displayInfo()

repeat {
} while (true)
