# CLAUDE.md

Project-level instructions. **MUST READ** before any code action. Overrides defaults; cannot be silently bypassed.

---

## 1. Project

**Stash** — local-first macOS menu-bar clipboard manager.
History (text + images), 9 pinned slots via `Option+1..9`, fuzzy search, plain-text paste, snippet variables, privacy exclusions.

- Active plan: `plans/260523-1357-macos-clipboard-manager-mvp/`
- Docs root: `docs/` (kept in sync after each phase)
- No first-party cloud, no backend, no login, no telemetry, no network code in this app.
- **Pinned-slot sync (Phase 10):** plain file I/O into a user-chosen folder (OneDrive / iCloud Drive / Dropbox / Google Drive). The external sync client handles transport — Stash itself never opens a socket. History never syncs.

---

## 2. Tech Stack

| Layer | Tech | Notes |
|-------|------|-------|
| App (primary) | **Swift 5.9+ / SwiftUI** | macOS 13.0 deployment target |
| Storage | **SQLite via GRDB.swift** | WAL mode, single file |
| Hotkeys | **soffes/HotKey** | Carbon HotKey wrapper |
| Backend (only if absolutely needed) | **Go 1.22+** | See §5 — must justify before adding |
| Tests | XCTest | Unit + integration, no UI snapshot tests for MVP |

**Hard rule:** do not introduce new languages, runtimes, frameworks, or third-party deps without first justifying in a phase plan or asking the user. No JavaScript, no Python, no Electron. Adding a dep requires (a) clear need, (b) license check (MIT/Apache/BSD only), (c) listed in plan.

---

## 3. Clean Architecture — Layer Rules (UNIVERSAL)

All code MUST fit into one of these four layers. **Dependencies point inward only.**

```
┌─────────────────────────────────────────┐
│ 4. Presentation  (SwiftUI views, NSPanel) │
├─────────────────────────────────────────┤
│ 3. Application   (use-cases, app state)   │
├─────────────────────────────────────────┤
│ 2. Domain        (entities, value objs)   │
├─────────────────────────────────────────┤
│ 1. Infrastructure (SQLite, NSPasteboard,  │
│    CGEvent, NSWorkspace, FileManager)     │
└─────────────────────────────────────────┘
```

### Dependency rules

- **Domain** depends on NOTHING. Pure Swift, no `import AppKit`, no `import GRDB`.
- **Application** depends on Domain only. Talks to Infrastructure through protocols defined in Application (or Domain).
- **Infrastructure** implements Application/Domain protocols. May import anything Apple.
- **Presentation** depends on Application + Domain. Never reaches into Infrastructure directly.
- Wiring (DI) happens once, in `AppDelegate` / a composition root. Nowhere else.

### Forbidden patterns

- ❌ SwiftUI view calling `NSPasteboard` or `GRDB` directly.
- ❌ Domain entity importing `AppKit`, `Foundation.URL` (use `String` paths in domain), `GRDB`.
- ❌ Use-case class holding a concrete `ClipboardRepository` — must hold the **protocol**.
- ❌ Singletons (`SomeClass.shared`). Use constructor injection. Composition root is the only place that knows about concrete types.
- ❌ Static mutable state. Period.

---

## 4. Swift / SwiftUI Standards (PRIMARY)

### Folder structure

```
Stash/
├── Domain/            # Entities, value objects, repository protocols
├── Application/       # Use-cases, app state, orchestration
├── Infrastructure/    # GRDB, NSPasteboard, CGEvent, HotKey impls
├── Presentation/      # SwiftUI views, view models, NSPopover host
├── Resources/         # Assets, Info.plist, entitlements
└── StashApp.swift # Composition root
```

Each `phase-*.md` lists files under these folders — do not invent new top-level dirs without updating the plan.

### Naming

- **Files:** PascalCase (`ClipboardWatcher.swift`, `PasteEngine.swift`).
- **Types:** PascalCase. Protocols use `-ing` / `-able` or noun (`ClipboardRepository`, `PasteboardReading`).
- **Functions / vars:** camelCase. Verbs for funcs (`captureNext()`), nouns for state (`recentItems`).
- **Bool vars / funcs:** start with `is`, `has`, `should`, `can` (`isPinned`, `shouldCapture`).
- **Constants:** camelCase inside a `enum` namespace (`enum Limits { static let maxItems = 500 }`).
- **No abbreviations** except universally known (`URL`, `UUID`, `SQL`, `DB`).

### Code quality

- One type per file. File name = type name.
- File size cap: **200 lines**. Split when exceeded; do not weaken the cap by re-aliasing the file.
- `struct` over `class` unless reference identity or shared mutable state is required.
- `actor` for shared mutable state crossing threads (e.g. capture queue).
- All async work uses Swift Concurrency (`async/await`, `Task`). Combine ONLY where SwiftUI requires it (Phase 5/6 publishers).
- `let` over `var`. Mutate sparingly.
- Errors: typed `throws` with concrete error enums per module. NEVER `try!`, NEVER `as!` outside generated code, NEVER `fatalError` in production paths (only `preconditionFailure` for true invariants).
- `print` is BANNED in shipped code. Use `os.Logger` with category. **Never log clipboard content** — log size/kind/source only.

### SwiftUI specifics

- Views are dumb. State lives in `@MainActor` view models exposed via `@StateObject` / `@ObservedObject`.
- No DB calls in `View.body`. No `NSPasteboard` calls in `View.body`.
- `Equatable` conformance on `View` + `.equatable()` for any list row.
- Previews required for every reusable view (`#Preview { … }`).

---

## 5. Go Backend Standards (ONLY IF NEEDED)

**Do not create a backend until the user explicitly asks.** Local-first is the product. If approved:

### When a backend might be justified

- Cross-device sync (out of MVP scope — do not pre-build).
- License server / paid feature gating (not planned).
- Telemetry — explicitly forbidden by privacy charter.

If none apply, **do not add a backend**.

### If approved, structure

```
backend/
├── cmd/stash-api/main.go     # Entry; wiring only
├── internal/
│   ├── domain/                   # Entities, value objects, repo interfaces
│   ├── usecase/                  # Application services
│   ├── adapter/
│   │   ├── http/                 # HTTP handlers (transport)
│   │   └── persistence/          # Postgres/SQLite impls of repo ifaces
│   └── platform/                 # Config, logging, observability
├── pkg/                          # Only if reused externally; default empty
└── go.mod
```

### Go rules

- **Hexagonal / Ports & Adapters.** `domain` and `usecase` import NOTHING from `adapter` or `platform`.
- **Interfaces defined in `usecase`** (consumer-side), implemented in `adapter`. Idiomatic Go.
- **Dependency injection** via constructor functions (`func NewService(repo Repository) *Service`). No DI framework, no `wire`.
- **Error handling:** wrap with `fmt.Errorf("context: %w", err)`. Sentinel errors in `domain`. NEVER `panic` outside `main`.
- **Context first arg** on every function that does I/O: `func (s *Service) Get(ctx context.Context, id string)`.
- **No globals** except `var ErrNotFound = errors.New(...)` and config loaded in `main`.
- **Files:** snake_case (`clipboard_repository.go`, `paste_handler.go`).
- **Packages:** lowercase, single word, no underscores (`usecase`, not `use_case`).
- **HTTP:** `net/http` + `chi` router OK. NOT `gin`, NOT `echo` (heavier, less idiomatic).
- **DB:** `pgx` for Postgres, `database/sql` + `modernc.org/sqlite` for SQLite. NO ORMs (no GORM).
- **Tests:** `_test.go` next to code. Table-driven. Use `testify/require` only for assertions, not for mocking.
- **Logging:** `log/slog` (stdlib). Structured. Never log secrets / clipboard content.

---

## 6. Universal Principles (NON-NEGOTIABLE)

### YAGNI · KISS · DRY (in that priority order)

- **YAGNI beats DRY.** Three similar lines are fine. Premature abstraction is worse than duplication.
- **KISS:** if a junior dev cannot follow it in 30 seconds, simplify.
- **DRY** only after the third repetition AND when the abstraction is obvious.

### Scope discipline

- Implement exactly what the active phase specifies. No "while I'm here" refactors.
- No feature flags, no "future-proofing", no abstraction "in case we need it".
- If you discover scope creep is necessary, STOP and report — don't silently expand.

### Code shape

- No dead code. No commented-out blocks. Delete what you remove.
- No `TODO` / `FIXME` without a linked issue or plan ref.
- No comments explaining WHAT — names should do that. Comments only for non-obvious WHY (invariants, workarounds, surprising constraints).
- No emojis in code, comments, commit messages, or filenames.
- No AI-attribution lines in commits or PRs.

### Files

- Prefer **editing existing** over creating new. Do not create `*_v2.swift`, `*_new.swift`, `*_enhanced.swift`. Modify in place.
- Never create README / docs files unless the active phase plan asks for it.

---

## 7. Privacy Charter (HARD CONSTRAINTS)

These rules are inviolable. Any code that violates them is a defect.

1. **No network code.** No `URLSession`, no `Network.framework`, no sockets, nothing. Adding a `URL` literal that points to a remote host requires explicit user approval.
   - *Phase 10 exception:* writing local files into a user-chosen folder that an external client (OneDrive/iCloud Drive/Dropbox) happens to sync is plain file I/O and does NOT violate this rule. The app never speaks to the cloud directly.
2. **No telemetry, no analytics, no crash reporters that phone home.** Crash logs stay local (`~/Library/Logs/Stash/`).
3. **Never log clipboard content.** Log only: size in bytes, kind (`text|image|fileURL`), source bundle ID. Test that grep of `os.Logger` call sites never references content fields.
4. **DB is plaintext SQLite on disk.** The user is warned in onboarding. Do not add encryption silently — it's a Phase-out-of-MVP feature.
5. **Privacy filter is part of the capture path.** Do not bypass `PrivacyFilter.shouldCapture()` for any reason, including "debug mode".

---

## 8. Testing Requirements

- Every PR / phase landing requires its tests pass: `xcodebuild test -scheme Stash` returns 0.
- Use the `InMemoryDatabase` helper for repository tests — never hit the real DB path.
- Mock at the protocol boundary, not below. Do not mock `NSPasteboard` directly — wrap it in `PasteboardReading` and mock that.
- No test that reads/writes the system `NSPasteboard.general` — always use a named, isolated pasteboard.
- **Failing tests are blockers.** Do not commit `XCTSkip(...)`, do not comment out, do not add `XCTExpectFailure` to silence them. Fix the code or fix the test.

---

## 9. Git Workflow

- Conventional commits: `feat:`, `fix:`, `refactor:`, `test:`, `perf:`, `build:`, `chore:`.
  Examples: `feat(capture): handle file URL pasteboard type` · `fix(eviction): respect pinned slot during cleanup`.
- One logical change per commit. Stage with explicit paths — never `git add .`.
- Commit messages describe **why**, not **what** the diff already shows.
- Never commit `.env*`, signing keys, provisioning profiles, `~/Library/Application Support/Stash/*`.
- Never amend pushed commits. Never force-push to `main`.

---

## 10. Common Claude Mistakes — DO NOT (READ THIS LAST, REMEMBER FIRST)

These are mistakes Claude has historically made on Swift / clean-arch projects. Each one is a regression if it ships.

1. ❌ **Importing `GRDB` from a domain entity** to "make it work faster". → Define a `record` adapter in `Infrastructure/` that maps the entity.
2. ❌ **Calling `NSPasteboard.general` from a SwiftUI view** because "it's one line". → Always go through `PasteboardReading` protocol.
3. ❌ **Creating `Stash/Utils/` or `Stash/Helpers/`** as a dumping ground. → Put utilities in the layer that owns them; if it's shared, it belongs in `Domain` and must be tested.
4. ❌ **Using `Task { @MainActor in … }` inside business logic** to "fix a warning". → Mark the view model `@MainActor`, keep logic actor-agnostic.
5. ❌ **Adding `ObservableObject` to non-view types** like repositories. → Repositories return values; the store/view-model owns the `@Published`.
6. ❌ **Logging `os_log("Item: %@", item)`** which can capture content. → Log `os_log("Captured %{public}@ size=%d", kind, size)`.
7. ❌ **Catching errors and returning empty defaults silently.** → Propagate; let the composition root decide. Empty defaults hide bugs.
8. ❌ **Adding GRDB / HotKey / any third-party type to a `@Published` property** that ends up in a view. → View must not transitively depend on infrastructure types.
9. ❌ **`if #available(macOS 14, *)` branches** for APIs we don't need yet. → Deployment target is 13.0; don't write code for unreleased macOS or future minimums.
10. ❌ **Writing a test that calls `sleep(1)` to "wait for the watcher".** → Use expectations / async/await with timeouts.
11. ❌ **Putting `String` literals for SQL inline** in the repository. → Use GRDB's query interface or `SQLRequest` with parameters.
12. ❌ **Skipping the active plan to "improve the design".** → If the plan is wrong, update the plan first, then code.
13. ❌ **Adding a Go backend "in case we need it".** → §5 forbids until explicitly approved.
14. ❌ **`fatalError` to "satisfy the compiler".** → Either return a real value, throw, or model the case in the type.
15. ❌ **Writing comments like `// Phase 4 fix` or `// see plan §3.2`.** → Comments describe stable WHY, not transient origin. (See `~/.claude/rules/review-audit-self-decision.md`.)

---

## 11. When in Doubt

1. Re-read the current `phase-*.md`.
2. If still unclear, ask the user — do NOT guess on architecture-shaping decisions.
3. Trivial implementation choices: pick the simpler one and move on.
4. If a rule above conflicts with a phase plan: phase plan wins for tactical details, this file wins for architecture / privacy / dependency rules.

---

**Last review:** initial draft, 2026-05-23. Update this file when an architectural decision changes, NOT when adding features.
