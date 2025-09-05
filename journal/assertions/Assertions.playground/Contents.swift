import UIKit

/// The following code gives an example on how to use assertions to detect if we are on the main thread or not.
/// Whenever we start using modern concurrency (async/await) we should start thinking more in terms of actors
/// rather than in terms of threads.

// MARK: GCD example

class GrandCentralDispatchExample {
    func somethingAsync() {
        DispatchQueue.main.async {
            // It's fine to check with `Thread.isMainThread` here
            print(Thread.isMainThread ? "is on Main Thread" : "not on Main Thread")
            assert(Thread.isMainThread)
        }

        DispatchQueue.global().async {
            // This is fine too
            print(Thread.isMainThread ? "is on Main Thread" : "not on Main Thread")
            assert(!Thread.isMainThread)
        }
    }
}

// MARK: Task example

@MainActor
class TaskExample {
    func somethingAsync() {
        Task {
            // The following line has an error if uncommented
//            print(Thread.isMainThread ? "is on Main Thread" : "not on Main Thread")
            MainActor.assertIsolated("This should run on the main actor")
        }
    }
}

// MARK: Async await example

@MainActor
class AsyncFunctionExample {
    func somethingAsync() async {
        // The following line has an error if uncommented
//        print(Thread.isMainThread ? "is on Main Thread" : "not on Main Thread")

        // This will crash only on debug builds
        MainActor.assertIsolated("This should run on the main actor")

        // This will crash on both release and debug builds
        MainActor.preconditionIsolated("This should run on the main actor")
    }
}

GrandCentralDispatchExample().somethingAsync()
TaskExample().somethingAsync()
Task {
    await AsyncFunctionExample().somethingAsync()
}
