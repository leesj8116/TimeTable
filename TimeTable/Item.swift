//
//  Item.swift
//  TimeTable
//
//  Created by 이승주 on 5/5/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
