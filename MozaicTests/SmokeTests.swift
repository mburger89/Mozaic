import Testing
@testable import Mozaic

/// Proves the test target compiles, links against Mozaic, and runs.
/// If this fails, nothing else in the suite can be trusted.
@Suite struct SmokeTests {
	@Test func testTargetCanSeeTheAppModule() {
		#expect(Module.vlong2short.rawValue == "vlong2short")
	}
}
