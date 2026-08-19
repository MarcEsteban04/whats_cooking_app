# Git Workflow

## Branches — trunk-based

```text
main        The trunk. One commit per completed sprint. Tagged at releases.
```

The project is a single developer working through a sequenced roadmap, so work lands
directly on `main`, one commit per completed sprint, with the sprint number in the
commit scope (`feat(sprint-07): ...`). Each sprint is therefore a distinct, reviewable
milestone in the history.

A `develop` integration branch was specified in Sprint 01 and dropped in Sprint 02 —
it added a merge step and a second branch to keep in sync while buying nothing, because
there is no second developer to integrate with and no parallel release train.

**Branch when work is genuinely parallel or risky**, and merge back into `main`:

```text
feature/<name>   Speculative or long-running work
fix/<name>       A bug fix that cannot ride along with the current sprint
experiment/<name>  Throwaway spikes
```

Revisit this the moment a second person joins, or when a release needs stabilising
while development continues — both are real reasons for an integration branch, and
neither applies yet.

### Tags

Releases are tagged on `main` as `v<version>`, e.g. `v1.0.0`.

---

## Commits

Conventional Commits. One logical change per commit.

```text
<type>(<scope>): <subject>
```

| Type       | Use for                                        |
| ---------- | ---------------------------------------------- |
| `feat`     | New user-facing functionality                  |
| `fix`      | Bug fix                                        |
| `refactor` | Behaviour-preserving restructuring             |
| `perf`     | Performance improvement                        |
| `style`    | Formatting only                                |
| `test`     | Adding or fixing tests                         |
| `docs`     | Documentation                                  |
| `chore`    | Tooling, dependencies, CI, config              |
| `build`    | Build system, release configuration            |

Scope is the feature or area: `roulette`, `meals`, `auth`, `pantry`, `db`, `ci`.

Examples:

```text
feat(roulette): add weighted meal scoring
fix(grocery): stop duplicate items on realtime insert
chore(deps): bump supabase_flutter to 2.5.11
docs: add environment setup instructions
```

Subject: imperative mood, lowercase, no trailing period, ≤ 72 characters.

---

## Verification before every commit

GitHub Actions is currently unavailable on this account, so `.github/workflows/ci.yml`
is **manual-trigger only** and these three commands are the sole gate. Run all three
and get a clean result before committing:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

A commit that has not been through them is unverified, and the commit message must say
so plainly rather than implying otherwise.

## Pull requests

Not used while this is a single-developer trunk-based project — a PR to yourself is
ceremony, not review.

When a branch *is* used (see above), merge it back into `main` with a squash-merge,
reference the sprint, state how it was verified, and delete the branch afterwards.

Reinstate mandatory PR review the moment a second person joins.

---

## Versioning

`pubspec.yaml` carries `<semver>+<build>`, e.g. `0.1.0+1`.

* Patch — bug fixes.
* Minor — new features, matching the roadmap versions (1.0, 1.1, 1.2, 1.3, 2.0).
* Major — breaking changes.

Build number increments on every store upload and never resets.

Releases on `main` are tagged `v<version>`, e.g. `v1.0.0`.

---

## Never commit

* `config/*.json` (real environment values) — only `*.example.json` is tracked.
* Keystores, `key.properties`, provisioning profiles, service-account JSON.
* Supabase `service_role` keys or AI provider API keys, anywhere, ever.
* Generated code (`*.g.dart`, `*.freezed.dart`).
