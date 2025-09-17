//: # Main Actor in Swift Concurrency
//: ---
//: ## Summary (detailed)
//: 1) Task { @MainActor in ... } — create a *new* MainActor-isolated task; good for flows that should all stay on the main actor.
//:    What it does: Starts a new task that is entirely isolated to the Main Actor.
//:    Use when: You want an asynchronous flow whose whole lifetime belongs on the main actor (e.g., a UI-driven sequence).
//:    Pros: Simple mental model; everything inside is MainActor-isolated (no extra hops); you can call non-async @MainActor funcs directly.
//:    Cons: You’ve committed the entire task to MainActor—even steps that could have been off-main.
//:
//: 2) await MainActor.run { ... } — *brief hop* to the main actor for a specific UI block after background work.
//:    What it does: Performs a brief hop to the Main Actor for the duration of the closure, then returns.
//:    Use when: You did work off-main and just need to update UI (or touch main-actor state) once.
//:    Pros: Minimal contention; you only isolate the small block that truly needs MainActor.
//:    Cons: You must remember to call it at the right boundaries (easy to forget a hop).
//:
//: 3) MainActor.assumeIsolated { ... } (advanced) — advanced/zero-cost; use only when you're *already* on the main actor and can *prove* it.
//:    What it does: Asserts “we’re already on the Main Actor—treat this block as such” with near-zero overhead.
//:    Use when: Inside a known @MainActor context (e.g., an @MainActor function) on a performance-sensitive path where you want to avoid an extra hop.
//:    Pros: Cheapest option; avoids suspension and context switch.
//:    Cons: Dangerous if misused—if you aren’t actually on MainActor, you invite undefined behavior. Treat as an expert tool.
//:
//: Quick rules of thumb:
//: • One-off UI update after background work? → await MainActor.run { ... }
//: • Keep background work off-main; do a *single hop* for UI.
//: • UI-first workflow that naturally lives on MainActor? → Task { @MainActor in ... }
//: • Inside an @MainActor function and you need the absolute lightest touch? → MainActor.assumeIsolated { ... } (only if you can prove you’re on MainActor)

//: # Main Actor in Swift Concurrency — Revised (Functions per Section)
//: Each section is wrapped in a function so you can call them individually from the bottom.
//: The examples are warning-free and show best practices for MainActor usage.

import UIKit
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

// Shared UI
let label = UILabel(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
label.backgroundColor = .systemYellow
label.textAlignment = .center
PlaygroundPage.current.liveView = label

// Common helpers
func fetchGreeting() async -> String {
    try? await Task.sleep(nanoseconds: 10_000)
    return "Hello from MainActor"
}

func fetchData() async -> String {
    try? await Task.sleep(nanoseconds: 50_000)
    return "Fetched Data"
}

func computeHeavyWork() async -> Int {
    try? await Task.sleep(nanoseconds: 30_000)
    return (1...200_000).reduce(0, +)
}

func maybeBackgroundWork() async -> String {
    try? await Task.sleep(nanoseconds: 20_000)
    return "BG"
}

@MainActor
func updateUILabel(_ label: UILabel, with text: String) {
    label.text = text
}

// MARK: - Section 1: Basic async work + MainActor UI update (merged)
func runSection1() async {
    let greeting = await fetchGreeting() // background work
    await MainActor.run {                // single hop to UI
        updateUILabel(label, with: greeting)
        print("[Section 1] On main thread?", Thread.isMainThread) // teaching aid
    }
}

// MARK: - Section 2: Marking entire types as @MainActor
@MainActor
final class ViewModel {
    var title: String = "Default"
    func updateTitle(_ newTitle: String) {
        print("[Section 2] On main thread?", Thread.isMainThread)
        title = newTitle
    }
}
let vm = ViewModel()
func runSection2() async {
    await vm.updateTitle("New Title")
}

// MARK: - Section 3: MainActor hop performance
func runSection3() async {
//    MainActor.preconditionIsolated("This should run on the main actor") - Confirm that not on main thread.
    let result = await computeHeavyWork() // stays off-main
    await MainActor.run {
        print("[Section 3] On main thread?", Thread.isMainThread)
        label.text = "Sum = \(result)"
    }
}

// MARK: - Section 4: Avoid blocking inside @MainActor
@MainActor
func refreshUIWithRemoteData() {
    // Spawn async work and keep the MainActor responsive
    Task {
        let data = await fetchData()
        label.text = "Refreshed: \(data)"
        // Seems to run on main too, but Task.detached does not
        MainActor.preconditionIsolated("This should run on the main actor")
    }
}
func runSection4() async {
    await refreshUIWithRemoteData()
}

// MARK: - Section 5: Task { @MainActor } vs MainActor.run vs MainActor.assumeIsolated
@MainActor
func renderFastPath() {
    MainActor.assumeIsolated { // zero-cost; only safe if already on MainActor
        label.text = "Fast path update"
    }
}

func runSection5() async {
    // 5A) Entire workflow on MainActor
    Task { @MainActor in
        MainActor.assertIsolated("This should run on the main actor")
        label.text = "From Task @MainActor"
        setTitleNonAsync("Still on MainActor")
    }

    // 5B) Brief hop just for UI update
    let data = await fetchData()
    await MainActor.run {
        label.text = "run() update: \(data)"
    }

    // 5C) Zero-cost assumption when already isolated
    await renderFastPath()
}

// MARK: - Section 6: Cross-actor calls and `await`
@MainActor
func setTitleNonAsync(_ text: String) { label.text = text }
@MainActor
func setTitleAsync(_ text: String) async { label.text = text }

func runSection6() async {
    await setTitleNonAsync("Non-async OK")
    await setTitleAsync("Async OK")
}

// MARK: - Section 7: Checking if on Main Thread vs MainActor
@MainActor
func checkIsolation() {
    print("Guaranteed on MainActor ✅")
    print("[Section 7] On main thread?", Thread.isMainThread)
}

func runSection7() async {
//    print("Immediate check, on main thread?", Thread.isMainThread)
    await checkIsolation()
    await MainActor.run {
        print("Inside MainActor.run: Thread.isMainThread =", Thread.isMainThread)
    }
}

// MARK: - Section 8: Misuse vs Correct Usage of @MainActor with async

// Sample JSON we’ll pretend came from disk
let sampleJSON = "[\"apple\", \"banana\", \"cherry\"]"

// ❌ Misuse: heavy work trapped on MainActor
@MainActor
func misuse_loadAndParseData() async throws -> [String] {
    MainActor.preconditionIsolated()
    print("[Misuse] Guaranteed on MainActor (blocking work here)")
    // Pretend this is “file IO” but we’re doing it synchronously on main
    let data = Data(sampleJSON.utf8)
    return try JSONDecoder().decode([String].self, from: data)
}

// ✅ Correct: heavy work off-main, only UI update on MainActor
func correct_loadAndParseData() async throws -> [String] {
    // MainActor.preconditionIsolated() - playground never finishes, so assuming this means that this is not on main thread.
    // Pretend this parsing is heavy and should be off-main
    let data = Data(sampleJSON.utf8)
    return try JSONDecoder().decode([String].self, from: data)
}

@MainActor
func correct_showResults(_ items: [String]) {
    MainActor.preconditionIsolated()
    print("[Section 10] Correct in updating UI on MainActor ✅")
    label.text = "Loaded \(items.count) items"
}

func runSection8() async {
    do {
        // Misuse: decoding work pinned to main actor
        _ = try await misuse_loadAndParseData()

        // Correct: decoding off-main, UI update on main
        let items = try await correct_loadAndParseData()
        await correct_showResults(items)
    } catch {
        print("Section10 error:", error)
    }
}

// MARK: - Runner helpers
func runAllSectionsSequentially() {
    Task {
        await runSection1()
        await runSection2()
        await runSection3()
        await runSection4()
        await runSection5()
        await runSection6()
        await runSection7()
        await runSection8()
        print("Finished!")
    }
}

// MARK: - Choose what to run
// Uncomment exactly what you want to run:
 runAllSectionsSequentially()
// Task { await runSection1() }
// Task { await runSection2() }
// Task { await runSection3() }
// Task { await runSection4() }
// Task { await runSection5() }
// Task { await runSection6() }
// Task { await runSection7() }
// Task { await runSection8() }

/**
 1. What @MainActor actually means

 When you mark a type, property, or function with @MainActor, you’re telling the compiler:
 - Isolation guarantee: All accesses must go through the MainActor executor.
 - At compile time: Calls to those APIs require await (unless you’re already on the MainActor).
 - At runtime: Swift ensures execution is scheduled onto the main actor, which in practice is tied to the main thread.
 - This work will always execute on the main thread, no matter where I call it from — unless I explicitly opt out with nonisolated or misuse unsafe APIs.
 */
