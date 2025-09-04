import Foundation
import PlaygroundSupport
PlaygroundSupport.PlaygroundPage.current.needsIndefiniteExecution = true

// ================================================
// Swift Concurrency Demo: Race Conditions vs Actor Isolation
//
// This playground compares two counters:
//
// 1. ClassCounter (unsafe, no isolation):
//    - Uses a plain class property `value`.
//    - Multiple concurrent tasks increment it directly.
//    - Demonstrates potential race conditions (final result often < expected).
//
// 2. ActorCounter (safe, isolated):
//    - Protects `value` inside an actor.
//    - All increments go through serialized actor execution.
//    - Guarantees correctness (final result == expected).
//
// Three scenarios are tested:
//   A) Many workers, each doing 1 increment
//   B) One worker, many increments
//   C) A mix of both
//
// Expected outcome:
//   - ClassCounter often fails in A and C due to races.
//   - ActorCounter always matches expected, showing serialization.
// ================================================

// ========= UNSAFE: class (no isolation) to demo races =========
// @unchecked Sendable: we *know* this isn't thread-safe; allow it to cross concurrency boundaries for the demo.
final class ClassCounter: @unchecked Sendable {
    var value = 0
    func increment() { value += 1 }  // not thread-safe
    func get() -> Int { value }
}

// ========= SAFE: actor (isolated) =========
// Safe and serialized
actor ActorCounter {
    var value = 0
    func increment() { value += 1 }  // serialized inside actor
    func get() -> Int { value }
}

// ========= Runner =========
struct Scenario {
    let label: String
    let workers: Int
    let perWorker: Int
}

// ========= Structured Tasks =========
func runClassCounter(_ s: Scenario) async -> Int {
    let c = ClassCounter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<s.workers {
            group.addTask { 
                for _ in 0..<s.perWorker {
                    c.increment()   // intentionally unsafe
                }
            }
        }
    }
    return c.get()
}

func runActorCounter(_ s: Scenario) async -> Int {
    let c = ActorCounter()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<s.workers {
            group.addTask { @Sendable in
                for _ in 0..<s.perWorker {
                    await c.increment() // serialized by the actor
                }
            }
        }
    }
    return await c.get()
}

func run(_ scenario: Scenario) async {
    let expected = scenario.workers * scenario.perWorker

    let classGot = await runClassCounter(scenario)
    if scenario.workers == 1 {
        // No concurrency here → no race
        print("[Class] \(scenario.label)   got \(classGot), expected \(expected)   ← (single worker, no race expected)")
    } else {
        // Multiple workers → potential races
        print("[Class] \(scenario.label)   got \(classGot), expected \(expected)   ← ⚠️ likely lower due to races")
    }
    
    let actorGot = await runActorCounter(scenario)
    print("[Actor] \(scenario.label)   got \(actorGot), expected \(expected)    ← ✅ should match")
}

// ========= Define the three isolates =========
// A) High workers, no per-worker loop (each task does 1 increment)
let highWorkers = Scenario(label: "A: high workers, perWorker=1", workers: 100_000, perWorker: 1)

// B) One worker, high per-worker loop (single task loops a lot)
let highPerWorker = Scenario(label: "B: workers=1, high perWorker", workers: 1, perWorker: 100_000)

// C) Mix of both (moderately many tasks, each loops moderately)
let mixed = Scenario(label: "C: mixed both", workers: 100, perWorker: 1_000)

// ========= Execute - Structured =========
Task {
    print("Classes vs. Actors")
    await run(highWorkers)
    await run(highPerWorker)
    await run(mixed)
    PlaygroundSupport.PlaygroundPage.current.finishExecution()
}
