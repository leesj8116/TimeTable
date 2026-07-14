import Foundation
import SwiftData
import SwiftUI

enum ServiceType: String, CaseIterable {
    case fullGrooming      = "전체"
    case scissorCut        = "가위컷"
    case scissorCutBichon  = "가위컷(비숑)"
    case partialFace       = "부목얼"
    case partialFaceBichon = "부목얼(비숑)"
    case bath              = "목욕"
    case sanitary          = "위생"

    var baseDuration: Int {
        switch self {
        case .bath:              return 60
        case .fullGrooming:      return 120
        case .scissorCut:        return 180
        case .scissorCutBichon:  return 240
        case .partialFace:       return 120
        case .partialFaceBichon: return 180
        case .sanitary:          return 30
        }
    }

}

@Model
final class Appointment {
    var id: UUID
    var dogName: String
    var dog: Dog?
    var serviceTypeRaw: String
    var startTime: Date
    var durationMinutes: Int
    var memo: String = ""
    var isTwoDogs: Bool = false

    var serviceType: ServiceType {
        get { ServiceType(rawValue: serviceTypeRaw) ?? .bath }
        set { serviceTypeRaw = newValue.rawValue }
    }

    static let pastelColors: [Color] = [
        Color(red: 1.0,  green: 0.71, blue: 0.76),
        Color(red: 0.80, green: 0.73, blue: 0.93),
        Color(red: 0.74, green: 0.89, blue: 0.98),
        Color(red: 0.60, green: 0.91, blue: 0.80),
        Color(red: 0.71, green: 0.90, blue: 0.71),
        Color(red: 1.0,  green: 0.94, blue: 0.63),
        Color(red: 1.0,  green: 0.82, blue: 0.67),
        Color(red: 1.0,  green: 0.73, blue: 0.70),
        Color(red: 0.86, green: 0.73, blue: 0.89),
        Color(red: 0.68, green: 0.85, blue: 0.90),
    ]

    var customerKey: String {
        if let dog = dog {
            return dog.latestDogName + dog.name
        }
        return dogName
    }

    var endTime: Date {
        Calendar.current.date(byAdding: .minute, value: durationMinutes, to: startTime)!
    }

    var displayDogName: String {
        dogName
    }

    var dogNameParts: (name: String, code: String?) {
        (dogName, dog?.name)
    }

    init(dogName: String, dog: Dog? = nil, serviceType: ServiceType, startTime: Date, durationAdjustment: Int = 0, memo: String = "") {
        self.id = UUID()
        self.dogName = dogName
        self.dog = dog
        self.serviceTypeRaw = serviceType.rawValue
        self.startTime = startTime
        self.durationMinutes = serviceType.baseDuration + durationAdjustment
        self.memo = memo
    }
}
