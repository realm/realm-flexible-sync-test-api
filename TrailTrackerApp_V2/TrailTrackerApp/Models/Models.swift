////////////////////////////////////////////////////////////////////////////
//
// Copyright 2022 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

import Foundation
import RealmSwift

enum TrailType: String, PersistableEnum, CaseIterable {
    case trek = "Trek"
    case bike = "Bike"
    case run = "Run"
    case kayak = "Kayak"
    case paddle = "Paddle"

    var emoji: String {
        switch self {
        case .trek:
            return "🥾"
        case .bike:
            return "🚴"
        case .run:
            return "🏃"
        case .kayak:
            return "🚣"
        case .paddle:
            return "🏄"
        }
    }
}

enum Visibility: String, PersistableEnum, CaseIterable {
    case `private`
    case `public`
}

class Trail: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId = ObjectId.generate()
    @Persisted var name: String = ""
    @Persisted var startDate: Date = Date()
    @Persisted var endDate: Date = Date()
    @Persisted var startPoint: Location?
    @Persisted var endPoint: Location?
    @Persisted var elevationDifference: Double = 0
    @Persisted var visibility: Visibility = .private
    @Persisted var trailType: TrailType = .trek
    @Persisted var creatorId: String

    var distance: Double {
        guard let startPoint = startPoint,
           let endPoint = endPoint else {
               return 0
        }
        return LocationHelper.calculateDistanceFrom(startPoint, to: endPoint) / 1000
    }

    convenience init(creatorId: String) {
        self.init()
        self.creatorId = creatorId
        self.startPoint = Location()
        self.endPoint = Location()
    }
}

class Profile: Object, ObjectKeyIdentifiable {
    @Persisted(primaryKey: true) var _id: ObjectId = ObjectId.generate()
    @Persisted var identifierId: String
    @Persisted var favourites: List<ObjectId> = List<ObjectId>()
    @Persisted var wantsToDo: List<ObjectId> = List<ObjectId>()
    @Persisted var done: List<ObjectId> = List<ObjectId>()
}

enum Tag: Int, PersistableEnum {
    case favourite
    case wantsToDo
    case done
}

class Location: EmbeddedObject, ObjectKeyIdentifiable {
    @Persisted var latitude: Double = 0
    @Persisted var longitude: Double = 0
}
