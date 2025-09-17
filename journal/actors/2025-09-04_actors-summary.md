
# All About Actors

**Date:** 2025-09-04  
**Tags:** #actor #quick-note

## Context
Actors are the foundation for safe concurrency in Swift. Each actor has its own executor, ensuring shared state access is serialized and isolated. 

## What I learned
- An **actor** is a type that protect its own data by guaranteeing that only one task can access its mutable state at a time (aka actor isolation).
- Actors are reference types like classes.
    - Actors are reference types so copies refer to the same piece of data. Modifying the copy will also modify the original instance as they point to the same shared instance.
    - Actors have an important difference compared to classes: they do not support inheritance (with one exception with NSObject for Objective-C interoperability).
- Actors are the foundation for safe concurrency in Swift. 
    - Can safely use this counter across threads without worrying about data races. For more details on what a data race is, go here [TBD].
    - Forces you to go through actor methods without accessing property directly (will get a compile error).
    - All access needs to be done using await since you’ll never know whether somebody is accessing the actor already.
- Under hood, each actor has its own executor (tasks get run on essentially a queue) and state stays consistent when accessed on multiple threads / tasks.
 - Executor is like a serial dispatch queue that manages who gets access to the actor’s isolation domain.
 - It uses a default executor under the hood which makes all access run via the cooperative thread pool (can also change executor, but generally don't need to)
- Actors synchronize access to shared mutable state and makes sure there’s only one thread accessing mutable state at the same time.
- You can only modify properties via an actor’s method, but you can read properties directly.

## Code
Since an actor manages who can access shared state, you’ll have to await access, since the actor might just have given access to another task.
```swift
let actor = BankAccount()
await actor.deposit(1)
print(await actor.balance)
```

## Gotchas
- Pitfalls to keep in mind:
    - Over-annotating types with @MainActor can push heavy work onto main—split UI

## Follow-ups
- Why not make the property private instead of exposing it to be accessed if we should go through the actor's method in an nonisolated context?
- What cases would you want to use a global actor as opposed to isolating it? 
