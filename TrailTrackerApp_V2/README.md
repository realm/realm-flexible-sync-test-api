![Realm](https://github.com/realm/realm-swift/raw/master/logo.png)

This Sample App is intended to showcase a different version of the flexible sync API, for A/B testing purposes.

## Sample App

The sample app showcase three different ways to use the proposed API in a SwiftUI App. 

- You can use `initialSubscriptions` and `rerunOnOpen` to subscribe to a query the first time the realm 
is opened or on every app startup.
- You can use the `@ObservedResults` property wrapper to subscribe to a query if the realm configuration 
for the corresponding property wrapper corresponds to a `flexibleSyncConfiguration()`.
- You can obtain a `Results` using the `try await realm.objects(Person.self, where: {})`, which can be
used to access data or unsubscribe to a query subscription.

To be able to use use this sample app please install your application following the instructions
[here](https://github.com/realm/realm-flexible-sync-test-api/blob/master/README.md), and copy the app id
to the sample app.

## Installation

### Swift Package Manager
You can use SPM to install the version of this API on your App.

In Xcode, select File > Add Packages....

And on the `Dependency Rule` box, select Branch instead of a version.
Use the following branch `jf/qbs-api-proposal-3`.

or add it to your `Package.swift` file 

```ruby
dependencies: [
    .package(url: "https://github.com/realm/realm-swift.git", .branch("jf/qbs-api-proposal-3"))
]
```

## How to use

### Get realm for the flexible sync configuration.

You can obtain the flexible sync configuration from the the user.
```swift
let app = App(id: "my-app-id")
let user = try await app.login(credentials: .anonymous)
let realm = try await Realm(configuration: user.flexibleSyncConfiguration())
```

Or you can instantly obtain the realm from the user, if no flexible sync extra configuration is needed.
```swift
let app = App(id: "my-app-id")
let user = try await app.login(credentials: .anonymous)
let realm = try user.realm(configuration: .defaultConfiguration)
```

### Initial Subscriptions & RerunOnOpen

You can use the configuration if you want to set an initial set of queries to the realm, this queries 
will be synced when the realm is opened and the data bootstrapped to the realm. This initial subscriptions
will be run once when the realm file is created unless the `rerunOnOpen` flag is set to true.
```swift
let app = App(id: "my-app-id")
let user = try await app.login(credentials: .anonymous)
let config = user.flexibleSyncConfiguration(initialSubscriptions: { subscriptions in
    subscriptions.append(ofType: Person.self,
                         where: { $0.age > 10 && $0.firstName == "john)" })
})
let realm = try await Realm(configuration: config, downloadBeforeOpen: .once)
```

Use the `rerunOnOpen` flag in cases where you want to re-run dynamic time ranges and other 
queries that require a re-computation of a static variable on every app startup.
```swift
let app = App(id: "my-app-id")
let user = try await app.login(credentials: .anonymous)
let config = user.flexibleSyncConfiguration(initialSubscriptions: { subscriptions in
    let date = Calendar.current.date(
                    byAdding: .year,
                    value: -18)
    subscriptions.append(ofType: Person.self,
                         where: { $0.birthdate > Date()" })
}, rerunOnOpen: true)
let realm = try await Realm(configuration: config, downloadBeforeOpen: .once)
```

### Subscribe To Query

You can subscribe to a query, using the await-able `try await realm.objects(Person.self, where: {})`, 
this will await for the sync client to bootstrapped the data to the realm.
```swift
let persons = try await realm.objects(SwiftPerson.self) // All documents for this object type
let dogs = try await realm.objects(SwiftDog.self, where: { $0.breed != "labradoodle" })
let birds = try await realm.objects(Bird.self, where: { $0.species.in(BirdSpecies.allCases) })

print(persons.count) //20
```

You can use your `Results` as you normally do, and perform the same operations with them.

### Writing to the Realm

The results will be updated if the values are within the subscription query, when a new object is added to the realm.
```swift
let persons = try await realm.objects(Person.self, where: { $0.age >= 18 })

let newPerson = Person()
newPerson.age = 18
try realm.write {
    realm.add(newPerson)
}

print(persons.count) //21 
```

And an error will occur if the data is outside the subscription queries.
```swift
let newPerson = Person()
newPerson.age = 7
try realm.write {
    realm.add(newPerson) // This will throw a compensating write error in the errorHandler on the app sync manager.
}
```

### Update subscription query

A `Results` subscription query can be updated if needed, this will automatically unsubscribe from the former query and subscribe to the new one.
This method is await-able as well so it waits for the new data from the most recent query to be bootstrapped.

```swift
var persons = try await realm.objects(Person.self, where: { $0.age >= 18 })
persons = try await persons.where { $0.age >= 21 }
```

### Unsubscribe to a query

Unsubscribe will remove the data from the realm, and remove the subscription from the subscription set.
```swift
let persons = try await realm.objects(Person.self, where: { $0.age >= 18 })
try await persons.unsubscribe()
```
If we don't unsubscribe from this `Results` data will be kept in the realm and can be accessed querying  
the same query. 

### Reusing a `Results`

Reusing a `Results` is as easy as querying again the same query using the await-able `try await realm.objects(Person.self, where: {})`
This is helpful in cases where you want to unsubscribe from the query and the data to be removed from the realm.
```swift
let persons: Results<Person>= try await realm.objects(Person.self, where: { $0.age >= 18 })
try await persons.unsubscribe()
```

### Batch Unsubscribe

You can use unsubscribeAll to remove all subscriptions from the subscription set, if you want a fresh clean realm.
```swift
try await realm.subscriptions.unsubscribeAll()
```

Or you can remove them by type, for example in cases where you want to remove a data from a user.
```swift
try await realm.subscriptions.unsubscribeAll(ofType: Person.self)
```

## SwiftUI

You can use `@ObservedResults` to add a query to the subscriptions, this will sync the given query 
if the sync configuration is from a flexible sync app.

Also, we are adding a new property to `@ObservedResults` property wrapper which includes a state value, this state 
will publish any subscription state changes to the view. This will very helpful in cases you want to know when the data 
is completely synced.

```swift
public enum SubscriptionState {
    case pending //Subscription has been added and waiting for data to bootstrap.
    case error(Error) // An error has occurred while adding the subscription (client or server side)
    case completed // Data has been bootstrapped and query results updated.
}
```

```swift
@available(macOS 12.0, *)
struct ObservedQueryResultsStateView: View {
    @ObservedResults(Person.self, where: { $0.age > 18 && $0.firstName == "john" })
    var persons

    var body: some View {
        VStack {
            switch $persons.state {
            case .pending:
                ProgressView()
            case .completed:
                List {
                    ForEach(persons) { person in
                        Text("\(person.firstName)")
                    }
                }
            case .error(let error):
                ErrorView(error: error)
                    .background(Color.red)
                    .transition(AnyTransition.move(edge: .trailing)).animation(.default)
            }
        }
    }
}

@available(macOS 12.0, *)
struct ObservedQueryResultsView: View {
    @ObservedResults(Person.self,  where: { $0.userId == app.currentUser!.id })
    var persons
    @State var searchFilter: String = ""

    var body: some View {
        VStack {
            if persons.isEmpty {
                ProgressView()
            } else {
                List {
                    ForEach(persons) { person in
                        HStack {
                            Text("\(person.firstName)")
                            Spacer()
                            Text("\(person.age)")
                        }
                    }
                }
            }
        }
        .onDisappear {
            Task {
                do {
                    try await $persons.unsubscribe()
                }
            }
        }
    }
}
```
