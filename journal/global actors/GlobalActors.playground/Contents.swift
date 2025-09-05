import UIKit

/// The following code gives an example on how to use and define custom global actors

/// The @globalActor attribute makes the Cache actor a globally accessible actor.
/// It also requires the type to conform to the GlobalActor protocol, for which defining the static shared property will be enough.

@globalActor
actor CacheActor {
    static let shared = CacheActor()
    private init() {}
}

/// Once defined, we can start using it just like we can with @MainActor.
/// The Cache class will now execute on the CacheActor actor isolation domain.

@CacheActor
class Cache {
    var fakeCache: Int = 0
    func mutateCache(number: Int) {
        CacheActor.assertIsolated("must be on ImageCacheActor")
        fakeCache = number
    }
}

/// Access to the fakeCache is isolated with the CacheActor, ensuring thread-safe execution.

Task {
    let cache = Cache()
    await cache.mutateCache(number: 1)
    print("Variable on ImageCacheActor: \(await cache.fakeCache)")
}

Task { @CacheActor in
    let cache = Cache()
    cache.mutateCache(number: 2)
    print("Variable on ImageCacheActor: \(cache.fakeCache)")
}

