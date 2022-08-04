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
import CoreLocation
import RealmSwift

struct ContentView: View {
    var body: some View {
        LogInView()
    }
}

struct LogInView: View {
    @EnvironmentObject var state: AppState
    @State var email: String = ""
    @State var password: String = ""
    @State var showErrorMessage: Bool = false
    @State var errorMessage: String?

    var body: some View {
        VStack {
            if let user = state.user {
                AsyncView()
                    .environment(\.realmConfiguration, user.flexibleSyncConfiguration(initialSubscriptions: { subscriptions in
                        subscriptions.append(ofType: Trail.self, where: {
                            $0.visibility == .public
                        })
                    }))
            } else {
                Spacer()
                VStack {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                    SecureField("Password", text: $password)
                        .textInputAutocapitalization(.never)
                    Button("Log In") {
                        Task {
                            do {
                                _ = try await app.login(credentials: .emailPassword(email: email, password: password))
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    Button("Create Account") {
                        Task {
                            do {
                                try await app.emailPasswordAuth.registerUser(email: email, password: password)
                                _ = try await app.login(credentials: .emailPassword(email: email, password: password))
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                }
                .padding()
                Spacer()
                VStack {
                    Button("Log In Anonymously") {
                        Task {
                            do {
                               _ = try await app.login(credentials: .anonymous)
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showErrorMessage) {
            Alert(title: Text("Error"), message: Text("\(errorMessage ?? "")"), dismissButton: .default(Text("Ok"), action: { showErrorMessage = false }))
        }
    }
}

struct AsyncView: View {
    @AsyncOpen var asyncOpen
    @State var showErrorMessage: Bool = false
    @State var errorMessage: String?

    var body: some View {
        VStack {
            switch asyncOpen {
            case .waitingForUser:
                EmptyView()
            case .connecting, .progress:
                ProgressView()
            case .error(let error):
                EmptyView()
                    .onAppear(perform: {
                        showErrorMessage = true
                        errorMessage = error.localizedDescription
                    })
            case .open(let realm):
                HomeView()
                    .onAppear(perform: {
                        Task {
                            do {
                                let users: Results<Profile> = try await realm.objects(Profile.self, where: { $0.identifierId == app.currentUser!.id })
                                if users.first == nil {
                                    try realm.write {
                                        let profile = Profile()
                                        profile.identifierId = app.currentUser!.id
                                        realm.add(profile)
                                    }
                                }
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    })
            }
        }
        .alert(isPresented: $showErrorMessage) {
            Alert(title: Text("Error"), message: Text("\(errorMessage ?? "")"), dismissButton: .default(Text("Ok"), action: { showErrorMessage = false }))
        }
    }
}

struct HomeView: View {
    @ObservedResults(Profile.self) var users

    var body: some View {
        TabView {
            if let user = users.first {
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass.circle")
                    }
                MyCreatedTrailsView()
                    .tabItem {
                        Label("My Created Trails", systemImage: "map.circle")
                    }
                ProfileView(user: user)
                    .tabItem {
                        Label("Tagged Trails", systemImage: "tag.circle")
                    }
            } else {
                ProgressView()
            }
        }
    }
}

struct SearchView: View {
    @ObservedResults(Profile.self) var users
    @ObservedResults(Trail.self, where: { $0.visibility == .public }) var trails
    @State var searchString: String = ""
    @State var showErrorMessage: Bool = false
    @State var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                switch $trails.state {
                case .pending:
                    ProgressView()
                case .completed:
                    EmptyView()
                    List {
                        ForEach(trails) { trail in
                            NavigationLink {
                                TrailDetailView(trail: trail)
                            } label: {
                                TrailRowView(trail: trail)
                            }
                        }
                        .searchable(text: $searchString, collection: $trails, keyPath: \.name) {

                        }
                    }
                case .error(let error):
                    EmptyView()
                        .onAppear(perform: {
                            showErrorMessage = true
                            errorMessage = error.localizedDescription
                        })
                }
            }
            .navigationTitle("Public Trails")
            .alert(isPresented: $showErrorMessage) {
                Alert(title: Text("Error"), message: Text("\(errorMessage ?? "")"), dismissButton: .default(Text("Ok"), action: { showErrorMessage = false }))
            }
        }
    }
}

struct MyCreatedTrailsView: View {
    @ObservedResults(Trail.self, where: { $0.creatorId == app.currentUser!.id }) var trails
    @Environment(\.realm) var realm
    @State var showErrorMessage: Bool = false
    @State var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack {
                switch $trails.state {
                case .pending:
                    ProgressView()
                case .completed:
                    List {
                        ForEach(trails) { trail in
                            NavigationLink {
                                TrailDetailView(trail: trail)
                            } label: {
                                TrailRowView(trail: trail)
                            }
                        }
                    }
                case .error(let error):
                    EmptyView()
                        .onAppear(perform: {
                            showErrorMessage = true
                            errorMessage = error.localizedDescription
                        })
                }
            }
            .alert(isPresented: $showErrorMessage) {
                Alert(title: Text("Error"), message: Text("\(errorMessage ?? "")"), dismissButton: .default(Text("Ok"), action: { showErrorMessage = false }))
            }
            .navigationTitle("My Trails")
            .toolbar() {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let newTrail = Trail(creatorId: app.currentUser!.id)
                        $trails.append(newTrail)
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            do {
                                try await app.currentUser!.logOut()
                                try await realm.subscriptions.unsubscribeAll(ofType: Profile.self)
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Log Out")
                    }
                }
            }
        }
    }
}

struct ProfileView: View {
    var user: Profile
    @Environment(\.realm) var realm
    @State var favouriteResults: Results<Trail>?
    @State var wantsToDoResults: Results<Trail>?
    @State var doneResults: Results<Trail>?
    @State var tagType: Tag = .favourite
    @State var showErrorMessage: Bool = false
    @State var errorMessage: String?

    var body: some View {
        NavigationView {
            List {
                if let favouriteResults = favouriteResults {
                    Section(header: Text("Favourites")) {
                        ForEach(favouriteResults) { trail in
                            NavigationLink {
                                TrailDetailView(trail: trail)
                            } label: {
                                TrailRowView(trail: trail)
                            }
                        }
                    }
                }
                if let wantsToDoResults = wantsToDoResults {
                    Section(header: Text("Wants To Do")) {
                        ForEach(wantsToDoResults) { trail in
                            NavigationLink {
                                TrailDetailView(trail: trail)
                            } label: {
                                TrailRowView(trail: trail)
                            }
                        }
                    }
                }
                if let doneResults = doneResults {
                    Section(header: Text("Done")) {
                        ForEach(doneResults) { trail in
                            NavigationLink {
                                TrailDetailView(trail: trail)
                            } label: {
                                TrailRowView(trail: trail)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tagged Trails")
        }
        .alert(isPresented: $showErrorMessage) {
            Alert(title: Text("Error"), message: Text("\(errorMessage ?? "")"), dismissButton: .default(Text("Ok"), action: { showErrorMessage = false }))
        }
        .onAppear(perform: {
            Task {
                do {
                    self.favouriteResults = try await realm.objects(Trail.self, where: { $0._id.in(user.favourites) })
                    self.wantsToDoResults = try await realm.objects(Trail.self, where: { $0._id.in(user.wantsToDo) })
                    self.doneResults = try await realm.objects(Trail.self, where: { $0._id.in(user.done) })
                } catch {
                    showErrorMessage = true
                    errorMessage = error.localizedDescription
                }
            }
        })
        .onDisappear(perform: {
            Task {
                do {
                    try await favouriteResults?.unsubscribe()
                    try await wantsToDoResults?.unsubscribe()
                    try await doneResults?.unsubscribe()
                } catch {
                    showErrorMessage = true
                    errorMessage = error.localizedDescription
                }
            }
        })
    }
}

struct TrailRowView: View {
    @ObservedRealmObject var trail: Trail

    var body: some View {
        VStack {
            HStack {
                CircleView(trailType: trail.trailType)
                Spacer()
                VStack {
                    Text(trail.name)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text(String(format: "%.2f Kms", trail.distance))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer()
                    Text(trail.startDate, style: .date)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.all)
            }.padding(7)
        }
    }
}

struct CircleView: View {
    let trailType: TrailType

    var body: some View {
        ZStack {
            Text(trailType.emoji)
                .shadow(radius: 3)
                .font(.largeTitle)
                .frame(width: 65, height: 65)
                .overlay(
                    Circle().stroke(Color.purple, lineWidth: 3)
                )
        }
    }
}

struct TrailDetailView: View {
    @ObservedRealmObject var trail: Trail
    @Environment(\.realm) var realm
    @State var showErrorMessage: Bool = false
    @State var errorMessage: String?

    var body: some View {
        Form {
            Section(header: Text("Name")) {
                TextField("Select text", text: $trail.name)
            }
            Section(header: Text("Info")) {
                HStack {
                    Text("Distance")
                    Spacer()
                    Text(String(format: "%.2f Kms", trail.distance))
                }
                TextField("Elevation", value: $trail.elevationDifference, format: .number)
            }
            Section(header: Text("Training Type")) {
                Picker(selection: $trail.trailType, label: Text("")) {
                    ForEach(TrailType.allCases, id: \.self) { trailType in
                        Text("\(trailType.rawValue)").tag(trailType)
                    }
                }
            }
            Section(header: Text("Visibility")) {
                Picker(selection: $trail.visibility, label: Text("")) {
                    ForEach(Visibility.allCases, id: \.self) { visibility in
                        Text("\(visibility.rawValue.capitalized)").tag(visibility)
                    }
                }
            }
            Section(header: Text("Duration")) {
                DatePicker("Start Time", selection: $trail.startDate, displayedComponents: .hourAndMinute)
                DatePicker("End Time", selection: $trail.endDate, displayedComponents: .hourAndMinute)
            }
            .listRowBackground(Color.yellow.opacity(0.3))
            Section(header: Text("Start Location")) {
                if let startPoint = trail.startPoint {
                    LocationView(location: startPoint)
                    Button("Update from current location") {
                        if let trailLocal = realm.object(ofType: Trail.self, forPrimaryKey: trail._id) {
                            do {
                                try realm.write {
                                    let currentLocation = LocationHelper.currentLocation
                                    trailLocal.startPoint?.latitude = currentLocation.latitude
                                    trailLocal.startPoint?.longitude = currentLocation.longitude
                                }
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
            Section(header: Text("End Location")) {
                if let endPoint = trail.endPoint {
                    LocationView(location: endPoint)
                    Button("Update from current location") {
                        if let trailLocal = realm.object(ofType: Trail.self, forPrimaryKey: trail._id) {
                            do {
                                try realm.write {
                                    let currentLocation = LocationHelper.currentLocation
                                    trailLocal.endPoint?.latitude = currentLocation.latitude
                                    trailLocal.endPoint?.longitude = currentLocation.longitude
                                }
                            } catch {
                                showErrorMessage = true
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                }
            }
            Section() {
                Button("Add To Favourites") {
                    tagTrail(trail, tag: .favourite)
                }
                Button("Add To Want To Do") {
                    tagTrail(trail, tag: .wantsToDo)
                }
                Button("Add To Done") {
                    tagTrail(trail, tag: .done)
                }
            }
        }
        .alert(isPresented: $showErrorMessage) {
            Alert(title: Text("Error"), message: Text("\(errorMessage ?? "")"), dismissButton: .default(Text("Ok"), action: { showErrorMessage = false }))
        }
    }

    func tagTrail(_ trail: Trail, tag: Tag) {
        if let user = realm.objects(Profile.self).where({ $0.identifierId == trail.creatorId }).first {
            do {
                try realm.write {
                    switch tag {
                    case .favourite:
                        user.favourites.append(trail._id)
                    case .wantsToDo:
                        user.wantsToDo.append(trail._id)
                    case .done:
                        user.done.append(trail._id)
                    }
                }
            } catch {
                showErrorMessage = true
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct LocationView: View {
    @ObservedRealmObject var location: Location

    var body: some View {
        TextField("Latitude", value: $location.latitude, format: .number)
        TextField("Longitude", value: $location.longitude, format: .number)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
