# Coding Standards

These rules keep the codebase predictable as it grows across 70 sprints. Most are
enforced automatically by `analysis_options.yaml`; the rest are conventions.

---

## 1. Language & formatting

* Dart SDK `^3.8.0`, Flutter `>=3.35.0`. Developed against Flutter 3.47.0 / Dart 3.13.0.
* Format with `dart format .` before every commit. 80-column default.
* Single quotes for strings. Trailing commas on every multi-line argument list.
* Always declare return types, including `void`.
* `const` wherever the analyzer allows it.

---

## 2. Naming

| Kind                | Convention            | Example                        |
| ------------------- | --------------------- | ------------------------------ |
| Files & folders     | `snake_case`          | `meal_card.dart`               |
| Classes, enums      | `UpperCamelCase`      | `MealRepository`               |
| Members, variables  | `lowerCamelCase`      | `estimatedCost`                |
| Constants           | `lowerCamelCase`      | `defaultBudget`                |
| Global constants    | `k` prefix            | `kAppEnv`                      |
| Private members     | leading underscore    | `_scoreMeal`                   |
| Providers           | noun + `Provider`     | `mealListProvider`             |
| Booleans            | `is` / `has` / `can`  | `isFavorite`, `hasPantryMatch` |

Widget files contain **one** public widget matching the filename.

---

## 3. Imports

* **Always use package imports** — `package:whats_cooking/...`, never relative `../..`.
* Ordered: `dart:` → `package:` (third-party) → `package:whats_cooking/` → relative.
  `directives_ordering` enforces this.
* Each feature exposes a barrel file (`features/roulette/roulette.dart`). Cross-feature
  code imports the barrel, never a file deep inside another feature.

---

## 4. Architecture

Feature-based Clean Architecture. Every feature owns the same three layers:

```text
features/<feature>/
├── data/            # DTOs, Supabase datasources, repository implementations
├── domain/          # Entities, value objects, repository interfaces, use cases
├── presentation/
│   ├── screens/     # Route-level widgets
│   ├── widgets/     # Feature-local widgets
│   └── providers/   # Riverpod providers and notifiers
└── <feature>.dart   # Barrel export
```

Dependency rule: `presentation → domain ← data`. **Domain depends on nothing.**

Anything shared by two or more features moves to `core/`.

---

## 5. State management — Riverpod

* Prefer code-generated providers (`@riverpod`) over manual constructors.
* Screens are `ConsumerWidget` / `ConsumerStatefulWidget`. No `setState` for anything
  that outlives a single widget.
* Async state is surfaced as `AsyncValue` and rendered with `.when(...)` so that
  loading, error and data states are impossible to forget.
* Never call `ref.read` inside `build`. Use `ref.watch` in `build`, `ref.read` in
  callbacks.
* Business logic lives in notifiers and use cases — never inside a widget.

---

## 6. Models

* All models are `freezed` + `json_serializable`.
* Generated files (`*.g.dart`, `*.freezed.dart`) are **git-ignored**. Regenerate with:

  ```bash
  dart run build_runner build
  ```

* Domain entities are separate from data DTOs. DTOs own `fromJson`/`toJson`; entities
  stay free of serialization concerns.

---

## 7. Error handling

* Repositories never leak `PostgrestException`, `AuthException` or `DioException` past
  the data layer. They are mapped to typed failures in `core/errors/`.
* The UI never displays a raw exception message. Every error state renders a friendly
  message plus a retry action (see `docs/design_ui.md` §31).
* Use `Result`/`Either`-style returns or typed exceptions consistently — chosen and
  documented in Sprint 05.

---

## 8. UI

* No magic numbers. Colors, spacing, radii and text styles come from `core/theme/`.
* Screens compose widgets; they do not contain large widget trees inline
  (`docs/design_ui.md` §40).
* Every list/async surface implements four states: **loading, empty, error, data**.
* Respect `SafeArea`, `MediaQuery` and `LayoutBuilder`. No hard-coded screen sizes.
* Touch targets ≥ 48dp. Meaningful `Semantics` labels on icon-only controls.

---

## 9. Testing

* Unit tests for the recommendation engine, budget math, ingredient matching and
  household permissions are **mandatory** (Sprint 64).
* Mock with `mocktail`. No network calls in unit tests.
* Test files mirror the source path: `lib/features/x/y.dart` → `test/features/x/y_test.dart`.

---

## 10. Security

* The Supabase `service_role` key and any AI provider key must **never** appear in
  Flutter source, assets or config files.
* All tables have Row Level Security enabled before any feature ships against them.
* No `print`. Use the logger in `core/utils/`, and strip sensitive fields from logs.

---

## 11. Conventions fixed in Sprint 05

These follow from [ARCHITECTURE.md](ARCHITECTURE.md) and [DATABASE.md](DATABASE.md). Where a
rule below and an earlier section disagree, this section wins.

### Errors — exceptions, not `Result`

Repositories **throw** typed `AppException`s; they do not return `Result<T>`. `AsyncValue`
already models failure as a first-class state, so a `Result` wrapper would be unwrapped and
immediately re-wrapped at every call site. Callers that must branch on failure catch the
specific exception type.

Mapping from `PostgrestException` / `AuthException` / `SocketException` happens **exactly
once**, in the data layer. A Supabase type reaching a widget is a review failure.

### Use cases

Write one only when the logic is non-trivial or spans repositories. A use case that forwards
a single repository call adds a file, a test and an indirection to buy nothing. Simple reads
go provider → repository directly.

### Providers

* `autoDispose` is the default. Keeping state alive is the exception and must be justified
  in a comment.
* Async state is always `AsyncValue`. Never a hand-rolled
  `bool isLoading` + `String? error` + `List<T> items` — three fields that can disagree.
* Realtime subscriptions live in `StreamProvider`s so disposal is automatic.

### Theme access

Feature code reads semantic roles through the theme extension — `context.colors.textTertiary`
— never the raw palette. **A feature file importing `app_colors.dart` directly is a review
failure.** Same rule for spacing, radius, shadow and motion tokens: no literals in feature
code.

### The domain layer stays pure

`domain/` imports nothing from Flutter, Supabase or `dio`. This is what lets the
recommendation engine be tested as a pure function in milliseconds, with no device and no
network. Sprint 40's scenario suite depends on it.

### SQL and migrations

* `snake_case`, plural tables, singular columns. Primary keys are `uuid`; timestamps are
  `timestamptz`. Money is `numeric(10,2)` — **never** `float`.
* RLS is enabled on **every** table. No policy means no access.
* Every `SECURITY DEFINER` function sets `search_path = public`. Omitting it is a
  privilege-escalation vector.
* Migrations are forward-only and are never edited once applied to staging. Apply to
  development, then staging, then production, in that order.
* `updated_at` is maintained by trigger. Clients never write it.

### RLS tests

Every policy is tested for **grant and denial**. A policy that grants correctly but fails to
deny is indistinguishable from a working one until it is a breach.

### Analytics

`meal_accepted` must carry `seconds_since_app_open` — that field *is* the north-star metric
and cannot be measured retroactively. Events carry IDs only: no PII, no meal names.

---

## 12. Definition of Done

A change is done when it is implemented, all four UI states exist, auth and RLS rules
are respected, `flutter analyze` is clean, tests pass, and the docs are updated.
The full checklist lives in `docs/project_dev.md`.
