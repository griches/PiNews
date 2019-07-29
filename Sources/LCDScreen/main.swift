import SwiftyGPIO
import Foundation
import Glibc
import HD44780LCD

let gpios = SwiftyGPIO.GPIOs(for: .RaspberryPi2)
var rs = gpios[.P27]!
var e = gpios[.P22]!
var d4 = gpios[.P25]!
var d5 = gpios[.P24]!
var d6 = gpios[.P23]!
var d7 = gpios[.P18]!
let lcd = HD44780LCD(rs:rs,e:e,d7:d7,d6:d6,d5:d5,d4:d4,width:20,height:4)
var story = 0
var headlines: [[String]] = []
var currentLine = 0
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
    let trainServices: [TrainService]
    let busServices, ferryServices: JSONNull?
    let generatedAt, locationName, crs, filterLocationName: String
    let filtercrs: String
    let filterType: Int
    let nrccMessages: [NrccMessage]
    let platformAvailable, areServicesAvailable: Bool
}

// MARK: - NrccMessage
struct NrccMessage: Codable {
    let value: String
}

// MARK: - TrainService
struct TrainService: Codable {
    let origin, destination: [Destination]
    let currentOrigins, currentDestinations: JSONNull?
    let rsid, sta, eta, std: String?
    let etd, platform, trainServiceOperator, operatorCode: String?
    let isCircularRoute, isCancelled, filterLocationCancelled: Bool
    let serviceType, length: Int
    let detachFront, isReverseFormation: Bool
    let cancelReason: JSONNull?
    let delayReason, serviceID, serviceIDPercentEncoded, serviceIDGUID: String?
    let serviceIDURLSafe: String?
    let adhocAlerts: JSONNull?

    enum CodingKeys: String, CodingKey {
        case origin, destination, currentOrigins, currentDestinations, rsid, sta, eta, std, etd, platform
        case trainServiceOperator = "operator"
        case operatorCode, isCircularRoute, isCancelled, filterLocationCancelled, serviceType, length, detachFront, isReverseFormation, cancelReason, delayReason, serviceID
        case serviceIDPercentEncoded = "serviceIdPercentEncoded"
        case serviceIDGUID = "serviceIdGuid"
        case serviceIDURLSafe = "serviceIdUrlSafe"
        case adhocAlerts
    }
}

// MARK: - Destination
struct Destination: Codable {
    let locationName, crs: String
    let via: String?
    let futureChangeTo: JSONNull?
    let assocIsCancelled: Bool
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

let newsURL = URL(string: "https://newsapi.org/v2/top-headlines?country=us&apiKey=2c5ede941f6546c0a3ce330b9c03af8b")!
let trainURL = URL(string: "https://huxley.apphb.com/all/gtw/from/vic/1?accessToken=DA1C7740-9DA0-11E4-80E6-A920340000B1")!
		
func loadNews(){
    
    print()

    headlines = []
    story = 0

    let session = URLSession.shared.dataTask(with: newsURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("error")
            usleep(6000*1000)
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
            usleep(6000*1000)
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
                let splitHeadline = split(headline: article.title)
                headlines.append(splitHeadline)
            }

            displayInfo()
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

func loadTrain(){

    headlines = []
    story = 0

    let session = URLSession.shared.dataTask(with: trainURL) { (data: Data?, response: URLResponse?, error: Error?) in
        if error != nil {
            // Handle Error
            print("error")
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
            return
        }
        // Handle Decode Data into Model

        do {
            let trainInfo = try JSONDecoder().decode(TrainInfo.self, from: data)
            
        } catch let error {
            print(error)
        }
    }
    session.resume()
}

func displayInfo() {
    repeat{
	if headlines.count != 0 {
            let splitHeadline = headlines[story]
            lcd.clearScreen()
            var y = 0 
            for line in splitHeadline {
                lcd.printString(x:0,y:y,what:line,usCharSet:true)
                y += 1
            }
            story += 1
            if story == headlines.count {
                story = 0
                
                // Has enough time passed that we need to fetch the news again?
                if fetchNewsDate.timeIntervalSinceNow <= -3600 {
                    loadNews()
                    return
                }
            }
            usleep(6000*1000)
        }
    }while(true) 
}

func split(headline: String) -> [String] {
    
    var splitHeadline:[String] = []
    var currentString = ""
    
    let words = headline.components(separatedBy: " ")

    for word in words {
        if currentString.isEmpty {
            currentString = word
        } else if currentString.count + word.count < 20 {
            currentString += " " + word
        } else {
            splitHeadline.append(currentString)
            currentString = word
        }
    }
    if splitHeadline.last != currentString {
        splitHeadline.append(currentString)
    }
    
    while splitHeadline.count > 4 {
        _ = splitHeadline.popLast()
    }
    
    return splitHeadline
}

var loaded = false
loadNews()
loadTrain()

repeat{
	if loaded == false {
		
		loaded = true
	}
}while(true) 




