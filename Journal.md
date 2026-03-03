# Journal.md — JobsTracker

## The Big Picture

Imagine you're job hunting. You find a posting, you skim it, you try to figure out: "Do I actually know the tech they want?" Now multiply that by 50 postings. Your eyes glaze over.

**JobsTracker** is a macOS desktop app that eats job descriptions for breakfast. You paste in a raw job posting, and a local AI (Ollama running llama3.1) chews through it, spits out the company name, address, website, job title, and — most importantly — a checklist of every technical skill mentioned. You tick off the ones you know. When you've got them all? Gold star.

It's like a personal job-hunting CRM that actually understands what the job is asking for.

## Architecture Deep Dive

Think of JobsTracker like a restaurant:

- **The Dining Room** (SwiftUI Views) — `ContentView`, `JobListView`, `JobDetailView`, `NewJobSheet`. This is what the customer sees. A `NavigationSplitView` gives you a sidebar of jobs on the left, details on the right.

- **The Waiter** (`JobAnalysisCoordinator`) — Takes orders from the dining room ("analyze this job") and relays them to the kitchen. Lives on `@MainActor` because it handles SwiftData's `ModelContext`, which must stay on the main thread. But it doesn't *block* the waiter — it `await`s the kitchen and goes back to serving other tables.

- **The Kitchen** (`OllamaService`) — An `actor` (explicitly *not* `@MainActor`) that does the heavy lifting. Fires HTTP requests to Ollama's localhost API, waits for the LLM to think, then parses the JSON response. The `actor` isolation means no two orders get mixed up, and the cooperative thread pool keeps things off the main thread.

- **The Pantry** (SwiftData: `JobEntry` + `TechnicalSkill`) — Persistent storage. `JobEntry` is the main dish; `TechnicalSkill` is a side that gets cascade-deleted if the entry goes away. The `@Relationship` between them is the glue.

- **The Recipe Book** (3-Tier JSON Fallback) — LLMs are... creative. Sometimes they return perfect JSON. Sometimes they wrap it in markdown. Sometimes they go rogue. So `OllamaService.parseResponse` tries three strategies in order:
  1. **Direct decode** — parse the whole string as JSON
  2. **Brace-balanced extraction** — find the first `{...}` block and decode that
  3. **Regex salvage** — yank individual fields with regex; always returns *something*

### The Critical Concurrency Dance

The project uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, meaning *everything* is `@MainActor` by default. This is a bold choice — it means you have to explicitly opt out for anything that shouldn't be on the main thread.

`OllamaService` is declared as `actor` (not a class, not a struct) specifically to escape this default. Network calls run on the cooperative thread pool. The `Codable` conformances on its internal structs are marked `nonisolated` so they can be called during encoding/decoding without triggering actor-isolation warnings.

`JobAnalysisCoordinator.analyze()` is `@MainActor` and uses `await` to call into the `OllamaService` actor. This *suspends* the main actor (doesn't block it), so the UI stays responsive while the LLM crunches.

## The Codebase Map

```
JobsTracker/
  JobsTrackerApp.swift      -- App entry point, static sharedModelContainer
  ContentView.swift          -- NavigationSplitView coordinator
  JobListView.swift          -- Sidebar: @Query list, swipe-to-delete, star badges
  JobDetailView.swift        -- Detail: editable fields, skills CRUD, delete job, re-analyze
  NewJobSheet.swift          -- Modal sheet for pasting job descriptions
  JobEntry.swift             -- @Model: the main data entity
  TechnicalSkill.swift       -- @Model: child entity (name + isKnown)
  AnalysisStatus.swift       -- enum: pending/analyzing/done/failed
  JobAnalysisCoordinator.swift -- @MainActor bridge between UI and OllamaService
  OllamaService.swift        -- actor: HTTP calls to Ollama, 3-tier JSON parsing
  SampleData.swift           -- ModelContainer.preview + sample entries
  JobsTracker.entitlements   -- com.apple.security.network.client for localhost HTTP
```

## Tech Stack & Why

| Technology | Why |
|---|---|
| **SwiftUI** | Declarative UI is the right tool for a data-driven app. `@Query` gives us reactive lists for free. `@Bindable` makes inline editing trivial. |
| **SwiftData** | Native persistence that plays perfectly with SwiftUI's observation system. No Core Data boilerplate. Cascade deletes handled via `@Relationship`. |
| **Ollama (llama3.1)** | Local LLM means no API keys, no cloud dependency, no cost per query. Privacy-friendly — job descriptions never leave your machine. |
| **Swift Concurrency** | `actor` for thread-safe network isolation. `async/await` for non-blocking UI. No Combine, no callback pyramids. |
| **macOS 26.2** | Targeting the latest means we get all the new SwiftUI goodies without compatibility hacks. |

## The Journey

### Bug: The Off-By-One That Broke Tier 2 Parsing

**Symptom**: The 3-tier JSON fallback was always falling through to Tier 3 (regex salvage), even when the LLM returned perfectly valid JSON wrapped in some text.

**Root Cause**: In `extractBalancedJSON`, the return statement was:
```swift
return String(text[start...text.index(after: idx)])
```
This included one character *past* the closing `}`. If `}` was the last character, it would crash. If not, it captured a trailing character that invalidated the JSON.

**Fix**: `return String(text[start...idx])` — the inclusive range already captures the closing brace.

**Lesson**: Off-by-one errors with `String.Index` in Swift are sneaky. The inclusive range `...` already includes both endpoints. Adding `index(after:)` on top of that double-counts.

### Bug: "A server with the specified hostname could not be found"

**Symptom**: Every Ollama request failed with a DNS resolution error — for `localhost`.

**Root Cause**: The `JobsTracker.entitlements` file existed in the project navigator but was **never wired** to the build target. `CODE_SIGN_ENTITLEMENTS` was completely missing from `project.pbxproj`. The app ran sandboxed with zero network permissions.

**Fix**: In Xcode's Signing & Capabilities tab, add the Outgoing Connections (Client) capability, which links the entitlements file to the target.

**Lesson**: Just having an entitlements file in your project doesn't mean anything. It must be referenced in `CODE_SIGN_ENTITLEMENTS` in the build settings. If your sandboxed app can't make network calls, check this *first*.

### Bug: Analysis Completes but UI Never Updates

**Symptom**: Ollama returns valid data, coordinator saves it, but the UI shows the entry stuck at its initial state.

**Root Cause**: `JobAnalysisCoordinator` was creating a *new* `ModelContext` via `ModelContext(container)`. This is a separate context from the one SwiftUI provides via `.modelContainer()`. Changes saved in the coordinator's context went to the persistent store but never reached the UI's context.

**Fix**: Changed to `container.mainContext` — the same context SwiftUI injects into the environment. Changes are immediately visible to `@Query` and `@Bindable`.

**Lesson**: SwiftData's `ModelContainer` can have multiple `ModelContext` instances, but they don't automatically sync with each other in-memory. If you want SwiftUI to see your changes instantly, use the *same* context — `mainContext`.

### Feature: Re-Analyze Button

Added a "Re-analyze" button that appears in two places:
1. In the **failed status banner** — so you can retry after a failure
2. Inside the **Original Job Description** disclosure group — so you can edit the description and re-run analysis

The coordinator was updated to clear all previously extracted data (company fields, skills, error message) before re-analyzing, preventing duplicate skills.

### Feature: Editable Fields Everywhere

All company fields (Position, Company, Address, Website) are now editable `TextField`s instead of read-only `Text` views. A helper `optionalBinding(_:)` bridges `String?` model properties to `Binding<String>`, writing `nil` back when cleared. The job description is also editable via `TextEditor`.

### Feature: Delete Job

A trash button in the detail view's toolbar with a confirmation alert. Clears the selection so the detail pane returns to the placeholder. The cascade delete rule on `@Relationship` automatically removes all associated `TechnicalSkill` objects.

## Engineer's Wisdom

### 1. Actor Isolation is Your Friend (Until It Isn't)

The `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project setting is powerful — it means you can't accidentally do UI work off the main thread. But it also means you have to *consciously* opt out for anything that shouldn't be on the main thread. `OllamaService` being an `actor` is the right call — it needs its own isolation domain for network I/O.

### 2. The Codable + Actor Dance

When you have Codable types inside an actor, the compiler gets confused about which actor context `encode(to:)` and `init(from:)` should run on. The fix: mark them `nonisolated`. These methods don't access actor state — they just transform data.

### 3. ModelContext is Not a Singleton

This is maybe the biggest gotcha in SwiftData. Creating `ModelContext(container)` gives you a fresh context. It's not the same as the one SwiftUI uses. If you need UI-visible changes, use `container.mainContext`. If you need background work that doesn't need immediate UI updates, a separate context is fine — but know what you're getting into.

### 4. Defensive Parsing for LLM Output

Never trust an LLM to return perfectly formatted JSON. The 3-tier fallback strategy (direct parse → brace extraction → regex salvage) ensures you always get *something* back, even if the model goes off-script. This is a pattern worth stealing for any LLM integration.

### 5. Binding Helpers for Optional Properties

SwiftData models often have `String?` properties, but `TextField` wants `Binding<String>`. The `optionalBinding(_:)` pattern — returning `""` for `nil` on get, writing `nil` for `""` on set — is a clean bridge that avoids cluttering every text field with inline binding logic.

## If I Were Starting Over...

1. **Schema Migration from Day 1**: There's no `SchemaMigrationPlan`. Right now, any model change means deleting the app's persistent store. For a personal tool this is fine; for anything shipped to users, you'd want lightweight migration set up before the first release.

2. **Error Handling with More Context**: The coordinator catches errors and stores `error.localizedDescription`, but network errors from URLSession can be cryptic. Wrapping them in a custom error with more context ("Is Ollama running? Is the model downloaded?") would save debugging time.

3. **Configurable Model Selection**: The Ollama model is hardcoded to `llama3.1:latest`. A settings screen to pick from installed models (via the `/api/tags` endpoint) would make this more flexible.

4. **Test Coverage**: There are no tests. The 3-tier JSON parsing in `OllamaService` is the most testable part of the codebase and the most likely to break with different LLM outputs. Unit tests for `parseResponse` with various malformed inputs would be high-value.

5. **Entitlements Wiring Check**: The entitlements file not being linked was a silent failure that produced a confusing error message. A build-time check or a runtime assertion ("am I sandboxed without network access?") would catch this immediately.
