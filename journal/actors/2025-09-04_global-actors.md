# Global Actors

**Date:** 2025-09-04  
**Tags:** #actors #globalactors #deepdive

## TL;DR
Global actors allow us to use actor isolation globally. We can benefit from compile-time synchronized access via the actor’s executor across our entire codebase. Global actors are flexible in that they allow us to enforce isolation on entire types, global variables, methods, and more. However, we should not expose the initializer as we want to run on the same executor and creating a new instance will create a new executor.

## Notes
- Specific actor called the **Global Actor** which is an actor that's globally accessible
- Useful for shared state that lives outside of a single actor (i.e. global variable, static property)
- Has actor isolation — safe, serialized access to data — but instead of being tied to a single instance, it’s tied to something broader
    - like a function, a property, or even an entire type
    - one popular example is the @MainActor
- Global state is risky in concurrent programs. 
  - Without proper isolation, you can easily introduce data races as shared mutable state might be accessed globally from different threads.
  - Global actors resolve these cases by allowing you to apply actor isolation to global variables, static properties, functions that access shared state, and even entire types such as view models or service layers.
- Using global actors puts on a "Serialized access only" sign. 
- A class can only be annotated with a global actor if it has no superclass, the superclass is annotated with the same global actor, or the superclass is NSObject. A subclass of a global-actor-annotated class must be isolated to the same global actor.
 
### @MainActor
Behind the scenes, @MainActor is a global actor who performs tasks on the main thread. It ensures that everything it touches is run on the same actor executor— in this case, the executor tied to the main thread. That makes it perfect for UI updates, which must happen on the main thread in apps.
- Can be used on properties, methods or entire types.
- Before Swift Concurrency, we would use the traditional `DispatchQueue.main` methods to ensure our code runs on the main thread. In Swift Concurrency, we can make use of the `@MainActor`.
- This is great when working with MVVM in SwiftUI as you only want to trigger view redraws on the main thread.


#### Notes:
`@MainActor` is a Swift concurrency annotation that says: “this thing (function/type/property) is isolated to the main actor,” i.e., it must run on the main thread. The compiler then:
- Enforces access rules: touching main-actor-isolated APIs from a background actor requires an await hop.
- Inserts hops when needed: await MainActor.run { ... } or Task { @MainActor in ... } perform the jump for you.
- Prevents data races: main-actor state can’t be mutated off the main thread.

Useful to use for:
- UI updates (UIKit/AppKit/SwiftUI), view models feeding UI, navigation, alerts.
- Callbacks that must fire on main (e.g., delegate methods consumed by UI).
- XCTest UI tests (or tests that interact with main-thread-only APIs).

* Avoid slapping @MainActor on big model/data layers—doing so serializes too much work on the main thread.

#### Different ways to use MainActor
* **Task { @MainActor in … }** creates a new async task whose entire body is isolated to the MainActor (i.e., it always runs on the main thread), no matter where you create it.
- Because it’s a Task, the body may suspend (await) and will resume on the MainActor each time.
- It schedules work; it does not run inline immediately.

* **await MainActor.run { … }**
- Runs a non-suspending block inline on the main actor and returns immediately. You can’t await inside the closure.

* **@MainActor func foo() async { … }**
Makes the function itself main-isolated. Callers hop to main; inside, you can await and you’ll still be on main when you resume.

* **Task { … } (no annotation)**
Inherits the current actor. If you start it from a main-actor context, it’s effectively main anyway; from a background actor, it stays there. Adding @MainActor removes the ambiguity and forces main.

### Custom Global Actor
Can create custom global actors to group and isolate access to global or static state
- Need `@globalActor` attribute to make an actor `ExampleType` (see code) a globally accessible actor
- It can be used similarly to `@MainActor`
- Code will execute on the actor isolation domain, allowing you to centralize work related to it such as image processing.
- Note: should use a private initializer for the actor instance to prevent anyone using actor directly which creates a new executor underneath


## Code
```swift
@globalActor
actor ExampleType {
    public static let shared = ExampleType()
    private init() { }
}

@ExampleType
final class Example {
    
}
```
```
func fetchImage(for url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
    URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data, let image = UIImage(data: data) else {
            DispatchQueue.main.async {
                completion(.failure(ImageFetchingError.imageDecodingFailed))
            }
            return
        }

        DispatchQueue.main.async {
            completion(.success(image))
        }
    }.resume()
}

@MainActor
func fetchImage(for url: URL) async throws -> UIImage {
    let (data, _) = try await URLSession.shared.data(from: url)
    guard let image = UIImage(data: data) else {
        throw ImageFetchingError.imageDecodingFailed
    }
    return image
}

```

## References
- Proposal [SE-0316 Global Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0316-global-actors.md) introduced the main actor as an example of a global actor, inheriting the GlobalActor protocol.
- Link 2
