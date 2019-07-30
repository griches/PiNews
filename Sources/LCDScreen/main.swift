import SwiftyGPIO
import Foundation
import Glibc
import HD44780LCD

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
var currentPage = 0
var fetchNewsDate = Date()

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

let newsURL = URL(string: "https://newsapi.org/v2/top-headlines?sources=bbc-news&apiKey=2c5ede941f6546c0a3ce330b9c03af8b")!
let trainURL = URL(string: "https://huxley.apphb.com/next/rys/none/ctk?accessToken=3a02290d-e8cc-4eb9-abb2-709ea77e3e69")!

func loadNews(){

    displayScreens = []
    currentScreen = 0
    
    let session = URLSession.shared.dataTask(with: newsURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("error")
            wait(seconds: 6)
            loadNews()
            return
        }
        if response != nil {
            // Handle Empty Response
            print("empty response")
            //return
        }
        guard let data = data else {
            print("empty data")
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
            
            for article in articles {
                let splitHeadline = split(string: article.title)
                displayScreens.append(splitHeadline)
            }
            
            displayInfo()
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

func loadTrain(){
    
    displayRailScreens = []
    currentRailScreen = 0
    
    let session = URLSession.shared.dataTask(with: trainURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("error")
            wait(seconds: 6)
            loadTrain()
            return
        }
        if response != nil {
            // Handle Empty Response
            print("empty response")
            //return
        }
        guard let data = data else {
            print("empty data")
            // Handle Empty Data
            wait(seconds: 6)
            loadTrain()
            return
        }
        // Handle Decode Data into Model
        
        do {
            let trainInfo = try JSONDecoder().decode(TrainInfo.self, from: data)
            var splitInfo:[String] = []
            
            if let departure = trainInfo.departures?.first {
                if let service = departure.service, let locationName = trainInfo.locationName, let destination = service.destination?.first?.locationName, let standardDeparture = service.std, let estimatedDeparture = service.etd {
                    splitInfo.append("Train service")
                    splitInfo.append("\(locationName) to \(destination)")
                    splitInfo.append("\(standardDeparture) (\(estimatedDeparture))")
                    displayScreens.append(splitInfo)
                }
            }
            
            if let nrccMessages = trainInfo.nrccMessages {
                for message in nrccMessages {
                    if let splitMessage = message.value?.split(separator: ".").first {
                        displayScreens.append(split(string: String(splitMessage)))
                    }
                }
            }
            
        
            displayInfo()
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

func displayInfo() {
    repeat{
        if displayScreens.count != 0 {
            
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
            
            if currentScreen == displayScreens.count {
                
                currentScreen = 0
                
                // Has enough time passed that we need to fetch the news again?
                if fetchNewsDate.timeIntervalSinceNow <= -3600 {
                    loadNews()
                    return
                }
            }
            
            // Wait for 6 seconds
            wait(seconds: 6)
        }
    }while(true) 
}

func wait(seconds: UInt32) {
    usleep((seconds * 1000) * 1000)
}

func split(string: String) -> [String] {
    
    var newString = string

    // Remove the source if it is there
    if let index = string.lastIndex(of: "-") {
        let modifiedIndex = string.index(index, offsetBy: -1)
        newString = String(string.prefix(upTo: modifiedIndex))
    }
    
    var splitString:[String] = []
    var currentString = ""
    
    let words = newString.components(separatedBy: " ")
    
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

var loaded = false
//loadNews()
loadTrain()

repeat{
    if loaded == false {
        
        loaded = true
    }
}while(true) 




