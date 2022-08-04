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


import SwiftUI
import RealmSwift
import Combine

let appId = "<Copy your App Id>"
let app = App(id: appId)

class AppState: ObservableObject {
    @Published var user: User? = app.currentUser
    var cancellables = Set<AnyCancellable>()

    init() {
        app.objectWillChange.sink { app in
            if let currentUser = app.currentUser {
                self.user = currentUser
            } else {
                self.user = nil
            }
        }.store(in: &cancellables)
    }
}

@main
struct TrailTrackerAppApp: SwiftUI.App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState())
        }
    }
}
