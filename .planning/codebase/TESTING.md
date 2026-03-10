# Testing Patterns

**Analysis Date:** 2026-03-09

## Test Framework

**Runner:**
- No test framework configured
- No test targets defined in `ErestorApp/project.yml`
- No XCTest files exist in the project

**Assertion Library:**
- Not applicable

**Run Commands:**
```bash
# No test commands available
# The project has no test target
```

## Test File Organization

**Location:**
- No test files exist anywhere in the codebase
- No `Tests/` or `*Tests/` directories

**Naming:**
- Not established

## Current State

**Zero test coverage.** The entire ErestorApp codebase (~3,400 lines of Swift across 17 files) has no automated tests of any kind.

## What Could Be Tested

**Unit-testable components (pure logic, no UI/network dependencies):**

1. **Time parsing** in `ActionHandler`:
   - `parseTime(_:)` at `ErestorApp/ErestorApp/Services/ActionHandler.swift` (line 437)
   - `parseRelativeTime(_:)` at `ErestorApp/ErestorApp/Services/ActionHandler.swift` (line 450)
   - Parses "30s", "5m", "5min", "2min", "1h", "1 minuto", "2 minutos", "1 hora"

2. **Time formatting** in `ContextPanelView`:
   - `formatMinutes(_:)` at `ErestorApp/ErestorApp/Views/ContextPanelView.swift` (line 215)
   - `timeUntil(_:)` at `ErestorApp/ErestorApp/Views/ContextPanelView.swift` (line 244)
   - `eventProgress(start:end:)` at `ErestorApp/ErestorApp/Views/ContextPanelView.swift` (line 224)

3. **Event type classification** in `ContextPanelView`:
   - `eventTypeFromTitle(_:)` at `ErestorApp/ErestorApp/Views/ContextPanelView.swift` (line 264)
   - Maps Portuguese keywords to `.work`, `.rest`, `.free`

4. **ISO time extraction** in `GCalEvent`:
   - `extractTime(from:)` at `ErestorApp/ErestorApp/Models/Message.swift` (line 107)
   - Extracts "HH:mm" from ISO 8601 strings

5. **JS string escaping**:
   - `ChatWebViewVC.escapeForJS(_:)` at `ErestorApp/ErestorApp/Views/ChatWebViewVC.swift` (line 135)

6. **Codable models** (JSON decoding):
   - `ContextSummary`, `GCalEvent`, `ChatAction`, `PushEvent` at `ErestorApp/ErestorApp/Models/Message.swift`
   - `SSEChunk`, `APIResponse` at `ErestorApp/ErestorApp/Services/ChatService.swift`

**Integration-testable (requires mocking URLSession):**

7. **ChatService networking**:
   - `sendMessageStreaming(_:)` SSE parsing
   - `loadContext()` JSON decoding
   - `loadHistory()` with legacy format fallback
   - Status polling progressive backoff logic

8. **ActionHandler backend calls**:
   - `callBackendEndpointAsync(_:body:actionType:)` success/failure paths

## How to Add Tests

**Step 1: Add test target to `ErestorApp/project.yml`:**
```yaml
  ErestorAppTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: ErestorAppTests
    dependencies:
      - target: ErestorApp
    settings:
      base:
        SWIFT_VERSION: "5.9"
```

**Step 2: Create test directory:**
```
ErestorApp/ErestorAppTests/
```

**Step 3: Suggested test structure:**
```
ErestorAppTests/
├── Services/
│   ├── ActionHandlerParsingTests.swift   # parseTime, parseRelativeTime
│   └── ChatServiceDecodingTests.swift    # SSEChunk, APIResponse decoding
├── Models/
│   ├── MessageTests.swift                # ChatMessage, ContextSummary Codable
│   └── GCalEventTests.swift              # extractTime, title defaults
├── Views/
│   └── ContextPanelHelpersTests.swift    # formatMinutes, eventTypeFromTitle
└── Helpers/
    └── JSEscapingTests.swift             # escapeForJS edge cases
```

**Step 4: Example test pattern (XCTest):**
```swift
import XCTest
@testable import ErestorApp

final class ActionHandlerParsingTests: XCTestCase {
    func testParseRelativeTimeMinutes() {
        let handler = ActionHandler.shared
        // Note: parseRelativeTime is private -- extract to a testable helper
        // or use @testable import reflection
        XCTAssertEqual(parseRelativeTime("5m"), 300)
        XCTAssertEqual(parseRelativeTime("5min"), 300)
        XCTAssertEqual(parseRelativeTime("2 minutos"), 120)
    }

    func testParseRelativeTimeSeconds() {
        XCTAssertEqual(parseRelativeTime("30s"), 30)
        XCTAssertEqual(parseRelativeTime("90s"), 90)
    }

    func testParseRelativeTimeHours() {
        XCTAssertEqual(parseRelativeTime("1h"), 3600)
        XCTAssertEqual(parseRelativeTime("2 horas"), 7200)
    }

    func testParseTimeValid() {
        XCTAssertEqual(parseTime("10:30"), (10, 30))
        XCTAssertEqual(parseTime("00:00"), (0, 0))
        XCTAssertEqual(parseTime("23:59"), (23, 59))
    }

    func testParseTimeInvalid() {
        XCTAssertNil(parseTime("25:00"))
        XCTAssertNil(parseTime("abc"))
        XCTAssertNil(parseTime("10:60"))
    }
}
```

**Testability Barriers:**
- Many helper functions are `private` -- to test them, either:
  - Extract to standalone utility functions/types
  - Change access to `internal` (visible to `@testable import`)
  - Or test indirectly through public API
- `ActionHandler` is a singleton with `private override init()` -- difficult to instantiate in tests
- `ChatService` tightly couples networking and state -- needs protocol-based URLSession injection for mocking

## Coverage

**Requirements:** None enforced

**Current Coverage:** 0% -- no tests exist

## Test Types

**Unit Tests:**
- Not implemented
- Recommended priority: time parsing, Codable models, JS escaping

**Integration Tests:**
- Not implemented
- Would require URLSession mocking for network layer

**UI Tests:**
- Not implemented
- Complex due to NSPanel-based floating UI (not standard SwiftUI navigation)

**E2E Tests:**
- Not applicable in current architecture -- app depends on external backend server

---

*Testing analysis: 2026-03-09*
