# Isolated vs. non-isolated access in actors

**Date:** 2025-09-17 
**Tags:** #actors #isolated #nonisolated #deepdive

## TL;DR
- Isolation domains help us access data in a safe way, but sometimes we need a little more control. We can use `isolated` parameters to isolate a function to a given actor parameter. In other cases, we can use the `nonisolated` keyword to opt-out of an actor’s isolation and allow access to immutable properties.
- Using `isolated deinit` will be a great escape route in cases you want to clean up state when an object gets released. Without it, you would need to explicitly call methods like cancel() before the object gets released. This is tricky, as it’s not always clear where objects will be released. 

## Notes
- Actos provide synchronization for shared mutable state in Swift Concurrency, but sometimes we want to step outside of isolated domain.
- By default, methods of an actor becomes isolated. So may run into errors:
    - Actor-isolated property ‘balance’ can not be referenced from a non-isolated context
    - Expression is ‘async’ but is not marked with ‘await’
- Both errors have the same root cause: actors isolate access to its properties to ensure mutually exclusive access.
- Can add a

## Tips
- Using the `isolated` keyword for parameters can be pretty useful for preventing unnecessary suspensions points. In other words, you’ll need fewer await statements for the same result. (see code example)
- Isolated parameters can be used inside closures as well. This can be useful if you want to perform constant operations around a given dynamic action. (see code example)
- Marking methods or properties as `nonisolated` can be used to opt-out to the default isolation of actors. Opting out can be helpful in cases of accessing immutable values or when conforming to protocol requirements.
    - The compiler can understand accessing an immutable let, but we may need to add nonisolate to a computed var. 
    - The `nonisolated` keyword is a way to opt-out of the actor isolation, removing the need to access the value using `await`.
    - The compiler is smart enough to warn us if we accidentally access isolated properties within a nonisolated environment.
- There’s a new way of adding conformance to protocols using global actor isolation. We will discuss this in one of the following lessons.

### Isolated synchronous deinit
The `deinit` method is `nonisolated` by default. The compiler issue also mentions it’s synchronous, as it will always execute synchronously. This is simply because it’s executed at the moment the object is being released. An asynchronous deinit would extend the lifetime of a type, making it unpredictable when it’s really released.
-  With the introduction of `isolated deinit` in Swift 6.2 (SE-371) we can solve compile issues of calling actor-isolated instance in nonisolated context.
- The deinit happens at the moment an object is being released. Extending this lifetime would be troublesome and introduce all kinds of new implications. That’s also why you’ll find out that this feature is only available for iOS 18.4+ and macOS 15.4+.

### Isolated conformance to protocols
- Previously can use `MainActor.assumeIsolated {}`.
- SE-470 introduced global-actor isolated conformance. You can enable the same feature inside packages by using `InferIsolatedConformances`.
- This is effectively saying that a protocol is only considered on the main actor. Violating this assumption will result in a run-time error. Such as if conforming to `Equatable`, then when == is called from outside the main actor, we get an error.

```
.target(
    name: "YourPackageTarget",
    swiftSettings: [
        .enableUpcomingFeature("InferIsolatedConformances")
    ]
)

/// Upcoming feature `InferIsolatedConformances` allows us to write `: @MainActor Equatable`:
extension PersonViewModel: @MainActor Equatable {
    static func == (lhs: PersonViewModel, rhs: PersonViewModel) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}
```

## Code
As you can see, we have two different suspension points:
- One to withdraw the given amount
- Another one to read the new balance
```swift
struct Charger {
    static func charge(amount: Double, from bankAccount: BankAccount) async throws -> Double {
        try await bankAccount.withdraw(amount: amount)
        let newBalance = await bankAccount.balance
        return newBalance
    }
}
```
- We could optimize this in several ways, one including to add a new method to BankAccount. - However, sometimes you’re not in control of the actor internals. In this case, we can use the isolated keyword in front of the parameter:
  - By using the isolated parameter, we basically instruct the whole method to be isolated to the given actor.Since there can only be one isolation at the same time, you can only use one isolated parameter.

```swift
/// Due to using the `isolated` keyword, we only need to await at the caller side.
static func charge(amount: Double, from bankAccount: isolated BankAccount) async throws -> Double {
    try bankAccount.withdraw(amount: amount)
    let newBalance = bankAccount.balance
    return newBalance
}
```

The transaction closure contains an isolated parameter using the Database actor. This results in a way for us to perform multiple database queries from outside the Database while only having to await once:

```swift
actor Database {
    func beginTransaction() {
        // ...
    }
    
    func commitTransaction() {
        // ...
    }
    
    func rollbackTransaction() {
        // ...
    }
    
    /// By using an isolated `Database` parameter inside the closure, we can access `Database`-actor isolation from anywhere
    /// allowing us to perform multiple database queries with just one `await`.
    func transaction<Result>(_ transaction: @Sendable (_ database: isolated Database) throws -> Result) throws -> Result {
        do {
            beginTransaction()
            let result = try transaction(self)
            commitTransaction()
            
            return result
        } catch {
            rollbackTransaction()
            throw error
        }
    }
}

let database = Database()
try await database.transaction { database in
    database.insert("<some entity>")
    database.insert("<some entity>")
    database.insert("<some entity>")
}
```

If we ever want to add a general perform method, so that any actor can perform multiple operations in one go here `performInIsolation`.
```swift
extension Actor {
    /// Adds a general `perform` method for any actor to access its isolation domain to perform
    /// multiple operations in one go using the closure.
    @discardableResult
    func performInIsolation<T: Sendable>(_ block: @Sendable (_ actor: isolated Self) throws -> T) async rethrows -> T {
        try block(self)
    }
}
```
## Questions
- Link 1
- Link 2
