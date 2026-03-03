# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open and run in Xcode (primary workflow):
```bash
open JobsTracker.xcodeproj
```

Build from command line:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project JobsTracker.xcodeproj -scheme JobsTracker build
```

There are no tests configured in this project.

## Architecture

**JobsTracker** is a macOS SwiftUI app using SwiftData for persistence. Targets macOS 26.2, Swift 5.0, with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` set project-wide.

### Key Files

- `JobsTrackerApp.swift` — App entry point. Exposes `static sharedModelContainer` (used by `JobAnalysisCoordinator`).
- `JobEntry.swift` — Primary `@Model`. Holds company info, job position, and a cascade-delete `@Relationship` to `[TechnicalSkill]`. Has computed `status: AnalysisStatus` and `allSkillsKnown: Bool`.
- `TechnicalSkill.swift` — Child `@Model`. Each skill has `name: String`, `isKnown: Bool`, and an inverse `entry: JobEntry?`.
- `OllamaService.swift` — `actor` (explicitly not `@MainActor`) that calls `http://localhost:11434/api/generate` with `llama3.1:latest`. Implements 3-tier JSON fallback (see below).
- `JobAnalysisCoordinator.swift` — `@MainActor` bridge between `OllamaService` and SwiftData. Uses `container.mainContext` (the same context SwiftUI observes) to ensure UI updates immediately.
- `SampleData.swift` — `ModelContainer.preview` extension + 4 sample entries (all-known/star, mixed, failed, analyzing).
- `ContentView.swift` — Thin `NavigationSplitView` coordinator with `@State private var selectedEntry: JobEntry?`.
- `JobListView.swift` — Sidebar with `@Query`, star badge (`allSkillsKnown`), status icons, swipe-to-delete.
- `JobDetailView.swift` — Detail panel with editable company fields, skill CRUD (toggle/rename/delete), editable raw description, re-analyze button, and delete job button with confirmation.
- `NewJobSheet.swift` — Paste-text sheet; inserts entry, dismisses, then fires `Task.detached` → coordinator.
- `JobsTracker.entitlements` — `com.apple.security.network.client = true` for Ollama HTTP calls.

### Data Flow

1. User pastes job description in `NewJobSheet` → `JobEntry` inserted with `status = .pending`.
2. `Task.detached` → `JobAnalysisCoordinator.analyze(entryID:)` (hops to `@MainActor`).
3. Sets `status = .analyzing`, then `await OllamaService.shared.analyze(...)` suspends MainActor during network I/O.
4. On success: fills fields, creates `TechnicalSkill` objects, sets `status = .done`.
5. On failure: sets `status = .failed` with `errorMessage`.
6. `@Query` in `JobListView` reactively updates; `@Bindable` in `JobDetailView` drives live skill toggles.

### 3-Tier JSON Fallback (OllamaService)

`parseResponse(_:)` tries in order:
1. **Direct** — `JSONDecoder().decode(JobAnalysisResult.self, ...)`
2. **Brace-balanced extraction** — scans for first balanced `{...}` block, then decodes
3. **Regex salvage** — `NSRegularExpression` extracts individual fields; always returns partial result, never throws

### Concurrency Notes

- Project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — ALL types inherit `@MainActor` unless explicitly overridden.
- `OllamaService` is declared `actor` to opt out of MainActor and run network I/O on the cooperative thread pool.
- Codable methods on network structs must be `nonisolated` to avoid actor-isolation warnings when called from inside the `actor`.
- `ModelContext` is always used on `@MainActor`; coordinator uses `container.mainContext` — the same context SwiftUI's `.modelContainer()` injects — so changes are immediately visible to `@Query` and `@Bindable`.

### Entitlements

`JobsTracker.entitlements` must be wired to the Xcode target's `CODE_SIGN_ENTITLEMENTS` build setting (via Signing & Capabilities tab in Xcode). The file grants `com.apple.security.network.client` for outbound TCP to Ollama's localhost API. ATS exempts `http://localhost` by default — no plist exception needed.

### SwiftData Migration

Schema: `[JobEntry.self, TechnicalSkill.self]`. If the model changes, delete the app's persistent store (or reinstall) — no `SchemaMigrationPlan` is configured.
