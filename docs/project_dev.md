# What's Cooking? — Development Roadmap

> **A private app for two people on one phone. Rescoped at Sprint 37.**

This document was a 70-sprint plan for a product with users, a store listing, a
freemium tier and a couple-mode feature set. It is not that any more.

**What's Cooking? is for Marc and his girlfriend, on one phone.** One account, one
device, handed back and forth. Nothing to launch, nobody to acquire, no retention to
engineer, and — clarified before Sprint 37 started — **nothing to share**, because
they live in the same house and use the same phone.

Six features are wanted. Everything else is cut, including two sprints that existed
only to serve a second device.

---

# 📌 Why the numbering does not restart

Sprints 01–36 are **done and shipped**, and hundreds of code comments, doc
references and commit messages cite them by number — `Sprint 33`'s scoring engine,
`Sprint 25`'s dislike exclusion, `Sprint 32`'s repetition window. Renumbering
history to make the new plan tidy would silently invalidate every one of those.

So the history stays where it is, compressed into one table, and the new plan
continues from **Sprint 37**. Sprints **38** and **44** are cut notices in place —
both existed only to serve a second device — for the same reason: forward references
in code comments and in the sibling documents already point at 39 through 52, and
closing the gaps would redirect every one of them.

The roadmap is now **52 sprints**, not 70. **Fourteen** carry work.

---

# 🎯 The Six Features

| # | Feature | State |
| - | ------- | ----- |
| 1 | **Meal roulette** (our own meals) | Built, Sprints 28–36 |
| 2 | **Meals** (library, ours to write) | Built, Sprints 21–27 |
| 3 | **Pantry** | Not built |
| 4 | **Grocery** | Not built |
| 5 | **AI** | Backend built (Sprint 59 work, done early); no UI |
| 6 | **Restaurant roulette** (our own list) | Not built |

The core experience stays:

> **Open → Narrow it down → Spin → Decide → Eat**

---

# ✂️ Cut

Removed from the plan, with the reason, so each is a decision rather than
something that quietly never happened.

| Cut | Was | Why |
| --- | --- | --- |
| **Couple Mode** | Phase 8, Sprints 41–47 | No partner to invite, no second account, no compatibility score, no "can't agree" voting round. **There is one phone** — two people who live together, handing it to each other. Nothing survives as a feature; the `households` tables stay as an invisible scoping key. See Sprint 38. |
| **Realtime sync** | Sprint 44 | Existed so one of us could tick off chicken in the shop while the other watched from home. One device, nothing to sync to. |
| **Private-per-person data** | Was Sprint 38 | Favourites, dislikes and dietary needs kept private from a partner is theatre on a shared phone. One set of preferences, agreed out loud. |
| **Meal Planning** | Phase 10, Sprints 54–58 | We decide at seven in the evening. A weekly planner is the opposite of a roulette, and the roulette is the product. |
| **Personalization phase** | Sprints 37–40 as written | Budget intelligence, variety engine and preference learning were designed for a large catalogue and an unknown user. Over a library we curated ourselves, "learn what you like" is largely answered by the fact that we added it. Variety and repetition already ship (Sprints 32–33). |
| **Beta Release** | Phase 13, Sprints 67–68 | No alpha group, no closed beta, no bug backlog triage across testers. Two people find the bugs by using it. |
| **Store deployment** | Phase 14, Sprints 69–70 | No Play listing, no App Store review, no screenshots, no privacy policy, no store description. Replaced by **Sprint 52**: a release build installed on the phone. |
| **Gamification, statistics, notifications, monetization** | app_feature §16–18 | Retention and revenue mechanics for a product that has neither problem. |
| **Cooking mode** | app_feature §10 | Step-by-step recipe walkthrough. Genuinely nice, genuinely not one of the six. Listed so it is on the record. |
| **Restaurant discovery** | Future Features | No maps, no ratings API, no location search. Sprint 45 is a list we write. |

**Not cut: security.** Row Level Security, the service-role assertion, the AI-key
assertion and the query-side exclusions all stay. Supabase is on the public internet
whether it has one user or two million, and "only we use it" is not a security model.

**Also not cut: Sprint 66.** Performance, RLS verification and the stale test suite
become Sprint 51. Being your own only user is a reason to skip a beta programme, not a
reason to ship something broken to the two people who have to live with it.

---

# 🗺️ Phases

| Phase | Sprints | Focus | State |
| ----- | ------: | ----- | ----- |
| 1 | 01–05 | Planning & Product Architecture | ✅ Done |
| 2 | 06–10 | Flutter Foundation | ✅ Done |
| 3 | 11–15 | Supabase Backend | ✅ Done |
| 4 | 16–20 | Authentication & Onboarding | ✅ Done |
| 5 | 21–27 | Meal System | ✅ Done |
| 6 | 28–36 | Roulette, Recommendations & Mood | ✅ Done |
| 7 | 37 | Our Library | ✅ Done |
| 8 | 39–41 | Pantry | ✅ Done |
| 9 | 42–43 | Grocery | ✅ Done |
| 10 | 45–46 | Restaurant Roulette | ✅ Done |
| 11 | 47–50 | AI | ✅ Done |
| 12 | 51–52 | Hardening & Shipping | ✅ Done |

---

# ✅ Sprints 01–36 — Shipped

Kept as the record. Code and commits reference these numbers.

| Sprint | Delivered |
| -----: | --------- |
| 01 | Project initialization, repo, environments, coding standards |
| 02 | Product requirements, MVP scope |
| 03 | User flows, navigation map |
| 04 | Design system — colour, type, spacing, radius, icons, components |
| 05 | Technical architecture, database ERD, conventions |
| 06 | Feature-based folder structure; Riverpod, GoRouter, codegen |
| 07 | Material 3 light and dark themes, typography, spacing tokens |
| 08 | Reusable components — buttons, fields, cards, chips, states, sheets |
| 09 | Routing, shell, auth guards |
| 10 | Environment config, logging, error handling, network abstraction |
| 11 | Supabase project, SDK wiring, connectivity |
| 12 | Core tables — profiles, households, members, meals, ingredients |
| 13 | Meal relationships — meal_ingredients, favourites, dislikes, history |
| 14 | Pantry and grocery tables |
| 15 | Row Level Security across every table |
| 16 | Auth screens — welcome, login, register, forgot, reset |
| 17 | Supabase auth, session persistence, recovery, error mapping |
| 18 | Onboarding (social auth cancelled; see docs/MVP_SCOPE.md §7) |
| 19 | *Folded into 18. Left vacant rather than renumbered.* |
| 20 | Profile — avatar, display name, preferences, account settings |
| 21 | The 60-meal starting catalogue |
| 22 | Meal feed — search, categories, filters, sort, pagination |
| 23 | Meal detail screen |
| 24 | Favourites |
| 25 | Disliked meals, excluded in the query |
| 26 | Custom meals — write our own |
| 27 | Meal system optimisation — indexes, caching, offline states |
| 28 | Roulette UI — the reel, the reveal, try again |
| 29 | Basic randomiser |
| 30 | Roulette filters — budget, cuisine, category, time, difficulty, type |
| 31 | Meal history integration |
| 32 | Repetition prevention, configurable window |
| 33 | Weighted recommendation engine — scores become likelihoods |
| 34 | Roulette polish — anticipation, haptics, states, analytics |
| 35 | Preference engine; disliked *ingredients* finally excluded |
| 36 | Mood-based recommendations — nine moods as a bias |

---

# PHASE 7 — Our Library

## Sprint 37 — Our Meals First

The roulette currently spins over sixty meals somebody else chose. The point of
this app is that it spins over ours.

Implement:

* An **"ours only"** switch on the spin, so the pool can be restricted to meals we
  wrote ourselves.
* A **weighting** for our own meals when the switch is off, so a meal we bothered
  to type in outranks a catalogue entry we have never cooked.
* **Add a meal from the spin screen** — the no-match state's best answer is often
  "because we have not told it about the thing we actually cook".
* Make the Meals screen's **"Yours"** count the primary figure it leads with.

The bundled catalogue stays. It is what makes the app usable before the library
fills up, and it is what "Surprise me" needs in order to surprise.

---

## Sprint 38 — *Cut — Two Phones, One Kitchen*

Removed before it started. Was: create a household, join it from a second phone
with a code, share history, pantry, grocery, restaurants and custom meals, keep
favourites and dislikes private.

**There is one phone.** Clarified before Sprint 37 began — Marc and his girlfriend
live in the same house and use the same device, so there is no second account to
join, nothing to synchronise, and nothing to keep private from somebody holding the
same screen. Preferences are joint because the people are in the same room agreeing
on them.

What survives is not a sprint. The `households` tables already exist and already
work: a trigger creates one personal household per user on signup, and every scoped
table carries a non-null `household_id`. That is a **scoping key**, and
docs/ARCHITECTURE.md §6.2 already argued for it on grounds that hold better now
than when it was written — one set of RLS policies, no `household or not` branch in
any query, provider or policy. It stays exactly as it is, invisible.

*Section number retained so 39 onward and every forward reference still resolve.*

---

# PHASE 8 — Pantry

## Sprint 39 — Pantry

Implement:

* Add and remove ingredients.
* Quantity and unit, both **optional**.
* Search against the shared ingredient vocabulary, adding to it when a word is
  missing — nobody is blocked because our list is incomplete.
* Grouped by aisle, because a pantry is read the way a shop is walked.

**Nothing converts units.** docs/DATABASE.md §9's open question is resolved here as
*neither*: both normalising on write and converting on read need a density table to
turn a bottle of soy sauce into grams, and neither has anything to say about "1 bulb"
of garlic. Sprint 41 asks **do we have any**, not do we have enough.

**A null quantity is the common case, not a gap.** Somebody at an open fridge is
answering *is there chicken*; requiring a number makes the fast answer the slow one,
and the app stops being told about half the kitchen.

---

## Sprint 40 — Expiry

Implement:

* Expiry dates, optional.
* An expiring-soon indicator.
* Expired items called out rather than silently ignored.
* Home surfacing what needs using tonight.

Staples — salt, oil, rice — are marked as such and never expire in the app's
opinion.

---

## Sprint 41 — Cook From What We Have

The pantry earns its keep here.

```text
Pantry
   ↓
Compare against meals
   ↓
Match %
   ↓
Weight the roulette
```

Implement:

* Ingredient match percentage per meal, ignoring staples — without that
  exclusion every meal caps near 80% and the number stops meaning anything.
* **The `ingredientMatch` weight (+20) the scorer has been declaring and not
  applying since Sprint 33.**
* "Everything but the bay leaves" on the result, naming what is short.
* A meals-screen filter for what we can cook right now.

---

# PHASE 9 — Grocery

## Sprint 42 — Grocery Lists

Implement:

* Create a list.
* Add, edit, delete an item.
* Check an item off.
* Clear completed.
* Quantities and units.

---

## Sprint 43 — From A Meal

```text
Accepted meal
      ↓
Required ingredients
      ↓
Compare pantry
      ↓
Missing only
      ↓
Grocery list
```

Duplicates combine. Two meals wanting chicken produce one line for 1.5 kg, not
two lines to puzzle over in an aisle.

---

## Sprint 44 — *Cut — Live Sync*

Removed before it started. Was Supabase Realtime on the grocery list, and only the
grocery list.

Its entire justification was two devices: one of us standing in the shop, the other
at home remembering something. **With one phone there is nothing to sync to**, and
an open socket is battery spend for no benefit.

docs/ARCHITECTURE.md §6.3 already said subscriptions open "only when the active
household has more than one member". That condition is now permanently false, so
the rule did not need changing — it simply never fires. Decision record 13 in the
same document resolves the same way.

Everything stays on refresh-and-invalidate, which is what the rest of the app
already does.

*Section number retained so 45 onward and every forward reference still resolve.*

---

# PHASE 10 — Restaurant Roulette

## Sprint 45 — The Restaurant List

Our own list. No discovery layer, no maps, no ratings API.

Table and screens for:

* Name.
* Cuisine.
* Cost a head.
* Proximity as **walk / short ride / worth the trip**, not kilometres — the
  distinction we actually make, and it needs no location permission.
* Whether it delivers.
* Notes, and what we order there.
* Tags, so moods work here too.

Add, edit, delete, favourite, hide — the same verbs as meals, because it is the
same job.

---

## Sprint 46 — Spin For Restaurants

The second roulette, reusing the first.

Implement:

* The same reel, the same haptics, the same reveal.
* Filters: budget a head, cuisine, proximity, delivers, mood.
* Its own **repetition window**, so we are not sent to the same place twice in a
  week.
* Its own history, and its own accepted-decision record.
* An entry point that makes the choice plainly: **cook something, or eat out.**

The scoring engine is shared. A restaurant scores on budget, cuisine preference,
variety, favourites and recency exactly as a meal does — the signals are the same
and only the pool changes.

---

# PHASE 11 — AI

The Edge Function, the three-provider failover chain, rate limiting and usage
tracking are **already deployed** (built ahead of schedule during Sprint 34's
window). What is missing is everything a person can see.

## Sprint 47 — Ask In Words

The assistant screen.

> "What can we cook tonight?"

> "We only have chicken and eggs."

> "Something cheap, under 20 minutes."

Implement:

* Conversation UI with streaming where the provider supports it.
* Context assembly — pantry, budget, dietary needs, avoided foods, recent meals.
* Answers that name a meal **from our library**, or say honestly that nothing
  fits rather than inventing one.
* Rate-limit and provider-failure states that read as sentences, not error codes.

---

## Sprint 48 — Generate A Recipe

> "Make something from chicken, eggs and rice."

Out: name, ingredients with quantities, instructions, cooking time, estimated
cost.

**Saveable to our library**, which is how the library grows without typing — and
the reason this ranks above the fridge scanner.

**Delivered.** `/meals/invent`. The pantry supplies the ingredients as chips —
whatever needs using first, pre-ticked — plus a free-text line for "nothing
fried". The reply is a labelled block rather than JSON (`GeneratedRecipe`), so a
cut-off answer still yields a name, a time and four steps instead of nothing; a
brace-balance failure is all-or-nothing and this is the one AI feature whose
output gets *stored*.

**Nothing is saved by the AI.** The recipe is shown to be read, and "Keep it"
opens the ordinary meal form pre-filled — the same form, the same
`MealDraft.validate`, the same single create path as a meal typed by hand. Two
steps rather than one on purpose: a form is a bad way to read a recipe, and
rejecting one there costs a "discard this meal?" dialog where the button on the
generator just says try another.

Entry points: the pantry's action row (`Invent`, beside Add) and the Meals
header, which is where somebody runs out of ideas. The household context that
feeds it was lifted out of the chat controller into `householdAiContext` so both
purposes honour the same dietary needs — two copies would have drifted, and the
drift would have shown up as an allergy respected in the chat and forgotten in a
recipe.

---

## Sprint 49 — Read The Fridge

Implement:

* Image capture and upload.
* Vision analysis.
* Detected ingredients presented **for confirmation**, never inserted silently.
* Correction before anything is written.

Image recognition is wrong often enough that trusting it would poison the pantry,
and a poisoned pantry poisons the roulette.

**Delivered.** `/pantry/scan`, reached from the camera circle in the Kitchen
header — the header you are looking at while standing in front of the thing being
photographed. `image_picker` downscales to 1280 px and 80% quality *on the
platform*, so a twelve-megapixel photo never becomes a twelve-megapixel
`Uint8List`, and the send is a tenth of the bytes for the same answer.

**Nothing is uploaded and nothing is stored.** No Storage bucket, no row, no log
line: the photo goes into one request, on to whichever provider answers, and then
nowhere. That is also why there is no "recent scans" list — there is nothing to
list. The iOS usage strings say so in the permission prompt, because "needs
camera access" is the prompt people decline.

**The confirmation list is the feature.** Every line can be unticked or corrected
in place; `addKept()` is only ever called by a button, and it is sequential and
tolerant, so one unrecognisable name costs that name rather than the other seven
("six of eight added" is the honest sentence). No quantities are guessed — a
photo establishes *that* there is rice, which is exactly what the pantry's null
quantity already means.

**No aisles are asked for either.** A vision model guessing "kangkong is a
vegetable" would let the list group itself, but `IngredientCategory` already
records the decision: guessing "bagoong" is a condiment is not easy, and a wrong
aisle is worse than no aisle. The catalogue owns the aisle; a photo does not get a
vote. **No context is sent with the photo**, unlike every other purpose — a model
told what is already in the kitchen and then shown a picture has been handed the
answer, and it will find chicken.

The provider chain gained vision: `ChatRequest.image`, a per-provider vision model
(`GROQ_VISION_MODEL` and friends — Groq's text default cannot see at all), and
providers with none configured are skipped rather than sent a picture they reject
with a 400, which does not fail over. **`ai-assistant` needs redeploying** for any
of that to exist.

---

## Sprint 50 — AI Personalization

Feed the assistant everything the app knows: history, preferences, budget,
pantry, the restaurant list, and previous conversations.

Bounded deliberately. Context is tokens and tokens are money, so what goes in is
chosen rather than dumped.

**Delivered.** `householdAiContext` gained five lines, and the theme of all five
is *observed* rather than *stated*:

* `usually_spends_per_head` beside `budget_per_head_pesos` — what somebody typed
  once, next to what actually happens. A household with a ₱200 budget that spends
  ₱90 is not asking for a ₱200 dinner.
* `recent_cuisines` — the real thirty-day mix with counts. The heart of the
  sprint: when the stated favourites and the eaten mix disagree, the second one is
  true.
* `going_off_soon` — the urgent shelf, on its own line. Buried in twenty pantry
  names it was invisible.
* `this_week` — cooked against eaten out, so "you have already been out twice" is
  a sentence the model can say.
* `places_we_go` — the restaurant list, so "we cannot face cooking" gets real
  names.

All read **through `homeDashboard`** rather than recomputed. Home already turns
history and spend into exactly these numbers, and a second implementation of
"what we usually spend" would drift from the chart that shows it — the assistant
and the chart would then disagree about the same household.

**A latent truncation bug went with it.** Values were capped by item count and
the Edge Function slices each at 300 characters, so twenty pantry names arrived
cut mid-word — "chicken thigh, spring onio" teaches the model an ingredient
nobody has. `_capped` now stops on an item boundary inside a 280-character
budget.

**Previous conversations** are delivered as continuity rather than as a context
line: the chat is persisted on the device (`AssistantMemory`, seven-day TTL,
`cache.` prefix so the sign-out sweep clears it without knowing it exists). A
transcript table would be a migration, a policy and a browsing screen for a
household of two. Summarising old turns into a line was rejected too — it would
cost a second AI call to produce what the transcript already says.

**And the eat-out roulette finally asks.** The meal spin got the
assistant-chooses-from-a-vetted-shortlist path at 47c and the night out did not,
which made "the AI decides" half true. Eating out is the decision where a model
has *more* to add: the shortlist cannot see that you were at the ramen place on
Friday. Same shape throughout — engine pick first, index from a pre-filtered
twelve, four-second budget, 1.5-second grace on the reveal, rate limit rests the
session — so the two roulettes cannot drift.

The meal spin's own prompt gained `going_off_soon` as well. It is the line that
most changes which of twelve valid meals wins, and it gives the reason under the
answer something real to say.

---

# PHASE 12 — Hardening & Shipping

## Sprint 51 — Make It Solid

The sprint that used to be a beta programme.

* **Fix the stale test suite.** Roughly a dozen assertions have been wrong since
  the card and filter redesigns. It compiles and lies, which is worse than
  failing.
* **Widget tests for the dashboard components under a `ListView`** — the gap that
  let an unbounded-height bug ship three times.
* Verify every RLS policy, including the negative cases.
* Query performance and index review.
* Slow-network and offline behaviour.
* Memory and animation performance on the real device.
* Confirm no service-role key and no AI provider key reach the client.

**Delivered, with one item explicitly handed over.**

**The biggest find was not in the tests.** `RemoteCall.guard` took an *optional*
`timeout`, and five of fifty-four call sites passed one — so on a stalled
connection the other forty-nine waited indefinitely. The symptom is not a slow
app: it is a spinner that never resolves, with no error, no retry and nothing to
tap, because a request that never completes never reaches the retry logic either.
`timeout` now defaults to `RemoteCall.defaultTimeout` (15 s), chosen against the
*retry budget* rather than a single request: three attempts plus backoff puts the
worst honest wait at about fifty seconds, which is long and, for the first time,
finite. `Duration.zero` opts out.

**Stale assertions found and fixed** — by reading the tests against the current
widgets rather than by running them, per how this project works:

* `MealCardData.formattedCostPerServing` returns `₱90`, not `₱90 a head` — the
  " a head" is the card's own second span, in a quieter style.
* `find.text('₱90 a head')` could never match: the cost is a `Text.rich`, and a
  plain `find.text` matches on `Text.data`, which rich text has none of. Needs
  `findRichText: true`.
* `find.text('35 min')` and `find.text('Easy')` — both live inside the single
  `detailLine` Text, `Dinner · 35 min · Easy`.
* `find.text('Clear')` — **there is no Clear button.** The filter redesign moved
  clearing onto the header subtitle, which reads "filtered — tap to clear".
* Two search tests typed into `find.byType(TextField)` without opening search
  first. The field renders only after the header's search circle is tapped, so
  they were addressing a widget that was not on screen.

**The `ListView` gap is closed with a harness, not with one test.**
`pumpComponent` wraps its subject in a `Center`, which hands down a *bounded*
height — which is exactly why three separate widgets shipped a
`CrossAxisAlignment.stretch` that only fails under a `ListView`'s
`maxHeight: infinity`. New `pumpInList`/`testInList` put a component under an
unbounded parent in both themes and at 1.3× on 320 px, and
`test/core/widgets/dashboard_test.dart` runs every dashboard component and both
charts through it. Any future component with a full-height divider, rail or
stretched child belongs there.

**RLS: `supabase/tests/rls_check.sql`.** Eight groups of checks, and it is honest
about its limit — the real cross-household negative needs a second account,
because `household_members.user_id` references `auth.users` and a fabricated uuid
cannot be inserted. So it tests the closest strong thing: RLS actually enabled on
every table, no table with zero policies, no policy that is unconditionally true
(bar `ingredients`, which is deliberately open), and an authenticated stranger who
belongs to no household seeing zero rows and being refused every write. Those are
the two failures that actually happen, and both are silent — the app keeps working
perfectly, because the app only ever asks for its own rows.

**Index review: one finding**, migration 0026. The pantry autocomplete runs
`ilike 'term%'` against `ingredients`, and `ingredients_name_idx` — a plain btree
— cannot serve `ILIKE` at all. `meals.name` has had a trigram index for this exact
query since migration 0008; the ingredient vocabulary was missed. Honest about the
size of it: a few hundred rows today, so nobody would feel the sequential scan —
but the table grows every time somebody adds food the catalogue lacks, which is a
deliberate feature, and the query is on the interactive path.

**Keys: verified clean.** `assertNoPrivilegedKey` and `assertNoProviderKey` both
run on the first frame in `main.dart`, before anything else. `config/development.json`
carries four keys — flavour, URL, publishable key, verbose flag — and none of the
six forbidden names. The publishable key is not `sb_secret_`-prefixed and is not a
JWT, so it cannot be carrying a `service_role` claim. `config/*.json` and `.env.*`
are both git-ignored and only the example file is tracked.

**Handed over: running the suite, and the device work.** Pinpointing any remaining
wrong assertion means executing the suite, which is Marc's call by standing
agreement — `flutter test` when he wants it. Memory and animation profiling needs
the real device rather than the emulator, and so does the slow-network end of this
sprint: the timeout default is the fix, and confirming what a two-bar connection
now feels like is a phone-in-hand job.

---

## Sprint 52 — Onto The Phone

Not a launch. An install.

* Replace `com.example.whats_cooking` with a real application id, and update the
  **Supabase auth redirect URLs** to match — the deep link back from email
  confirmation and password reset is keyed to the scheme, and getting it wrong
  silently breaks sign-up.
* Real release signing config, replacing the debug keys.
* Production Supabase project, migrations applied, backups on.
* Edge Function secrets set in production.
* `flutter build apk --release`, installed on the phone.
* iOS via a development profile if it ever moves platforms.

No store listing. No screenshots. No privacy policy. No review process.

**Note:** with no Play listing, `com.example.*` stops being a hard blocker and
becomes a tidiness issue — but the application id is still permanent per install,
so it is worth setting once, here, before either phone has data worth keeping.

**Delivered — see docs/RELEASE.md for the parts that are yours.**

**The deep link was broken, and silently.** The app has been sending
`whatscooking://reset-password` as its `redirectTo` on every reset email since the
auth sprint, and **nothing on either platform claimed the scheme** — no intent
filter on Android, no `CFBundleURLTypes` on iOS. So the link in the email opened
nothing at all: no error, no log, a tap that did nothing, which reads as a broken
email rather than as a missing manifest entry. That is now registered on both
platforms, scheme-only rather than pinned to a host, because Supabase sends more
than one path back and a filter pinned to `reset-password` would fail the same
silent way for the next one. The Dart side was already right —
`AuthChangeEvent.passwordRecovery` is handled ahead of the signed-in cases
precisely so a recovery link cannot land on Home.

**`com.acoretechnology.whatscooking`**, replacing the template's
`com.example.whats_cooking`: Android `applicationId` and `namespace`, the Kotlin
package directory, and the iOS and macOS `PRODUCT_BUNDLE_IDENTIFIER`. Reverse DNS
on a domain the household controls, and no underscore. **Change it before the
first install if it should be something else** — after that it is a one-way door,
because Android treats a changed id as a different app.

**Release signing reads `android/key.properties`** — git-ignored, alongside a
committed `.example` and the `keytool` line that makes the keystore — and **falls
back to debug signing when it is absent**. That fallback is deliberate: "does this
app build with the tree shaker on" and "is this the artifact for the phone" are
different questions, and failing the first because of the second would put the
useful check behind the key.

R8 is **off**. It needs keep rules for anything reached by reflection, and the
plugins here — secure storage, shared preferences, the image picker — are exactly
the shape that breaks silently: the build succeeds and a feature stops working in
release only. Two megabytes is not worth that.

**A release APK was built and it compiles clean** — 64.6 MB universal, which the
release doc corrects to `--target-platform android-arm64` for roughly a third of
that. The build also surfaced a missing `cupertino_icons`: nothing here imports
Cupertino, but Material's adaptive widgets and the iOS text-selection toolbar
reference its glyphs regardless, and without the package those would be absent on
an Apple device. Added; the tree shaker removes it when genuinely unreferenced.

**Left to Marc, and written down rather than guessed at:** the keystore, the
Supabase dashboard's redirect allow-list (an entry that is missing is not an error
the app can see — Supabase quietly substitutes its own hosted page), the
production project with backups on, the function secrets, and the on-device
checks that an emulator cannot answer.

---

---

# PHASE 13 — After the first install

Not planned. What the first real phone turned up, and what it asked for.

## Sprint 53 — Import A List

> "Can we add an import on the grocery screen — image, txt or pdf — and the AI
> extracts and imports the list?"

`/grocery/import`, from an `Import` tile beside `Add` on the Kitchen list's action
row. Pick a photo of a list, a `.txt` or a PDF; the assistant copies out what is
on it; **nothing reaches the list until it has been read back.** Same rule as the
fridge scanner and for a sharper reason: a misread line here is not a wrong row in
a database, it is something somebody buys.

**Quantities survive, unlike the fridge scan's.** A photo of a fridge cannot say
how much rice is in the bag; a shopping list that says "2 kg rice" said it on
purpose, and dropping the 2 would make the import worse than the paper. Units are
*not* snapped to a vocabulary either — `grocery_items.unit` is free text by design,
because the list is read in an aisle rather than computed with, so "sachet" and
"bundle" pass through as written.

**Three formats, three paths.** A `.txt` is decoded on the device and sent as
text: text does not need to be an attachment, and sending it as one would narrow
the provider chain for no benefit. A photo reuses Sprint 49's vision path
unchanged. A PDF goes as an attachment too — and **only Gemini takes a document
inline**, so the chain now filters on a per-provider `acceptsDocuments` rather
than sending a PDF to a provider that answers `400`, which deliberately does not
fail over.

The wire field was renamed `image` → `file` while it was still undeployed. A field
named for a picture that carries a PDF is the kind of lie that costs somebody an
hour.

Adds `file_picker`. The image picker cannot open a document, and a list arriving as
a PDF from a delivery app is the case worth handling.

## Fixes the first install turned up

Each of these was invisible in every build type reachable from this desk.

* **No `INTERNET` permission in release.** The Flutter template declares it in
  `src/debug/` and `src/profile/` only, so debug and profile builds have network
  access and the release build does not — and Android fails the *DNS lookup*
  rather than refusing the connection, so it reads as a broken phone. An evening
  went into Private DNS settings.
* **A partial-ABI APK.** `--target-platform android-arm64` compiles the engine for
  one architecture but plugin AARs ship every one, so the APK carried
  `lib/x86_64/` and `lib/armeabi-v7a/` directories with no `libflutter.so` in
  them. Android picks the app's ABI as the first entry of `Build.SUPPORTED_ABIS`
  present in the APK, so an engine-less directory is one the installer may choose.
  Fixed with `abiFilters`, which is the only thing that reaches plugin libraries.
* **A DNS failure reported as a wrong password.** gotrue wraps a failed fetch in
  `AuthRetryableFetchException`, which extends `AuthException`, so it arrived on
  the auth branch of the mapper and fell through to "Those details did not
  match" — the worst available wording, because it sends somebody to change a
  password that was already correct.
* **The reason was unreachable.** design_ui §31's "never show technical exception
  text" was being applied to development builds too, which made a device-only
  failure undiagnosable without a debugger. `InlineErrorBanner` now shows
  `AppException.detail` in a verbose build. That one change is what found the two
  above.
* **A stale auth banner.** `AuthController` is shared by both forms and moving
  between them never drops its listener count to zero, so a failure on one was
  still on the other — over an empty field that was separately complaining.
* **The dashboard header overlapped its own buttons.** A `Text` inside a `Row`
  with no `Flexible` gets an *unbounded* width, so `maxLines`/`ellipsis` never
  applied and the subtitle ran under the action circles. The same
  unbounded-constraints family as the `ListView` bugs, and invisible in release
  because Flutter's overflow stripe is a debug-only paint. Sprint 48's third
  circle on Meals is also gone: three of them plus the logo leave about 124dp for
  the title, and the row never fitted.

## Sprint 54 — The Kitchen Filter, And Keeping It True

> "the narrow it down on spin roulette for meals, it should be connected to
> pantry, and ai should suggest based on ALL the info of the user."

`PantryReach` on the filter sheet — **Anything / Mostly in / All in** — applied in
`SpinController` against the server's own match map rather than inside
`SpinFilters.allows`, because the match is a query result and the filter object is
a value. A meal the pantry cannot speak about (`null` match) passes: "nothing
countable" is not "nothing in", and treating it as a miss would hide every meal
whose ingredients nobody has ever added.

The spin's prompt now carries the *whole* household context — the same
`householdAiContext` the chat and the recipe writer send — plus the reach the
reader asked for. The shortlist already encodes the filters, so restating those
was tokens on a filter that had run; but once the model is the thing **choosing**
rather than decorating, "which of these twelve suits this household tonight" is
answered by what the shortlist cannot express.

**And the pantry had to start going down.** Accepting a meal filled the shopping
list and never touched the shelf, so a household added chicken, cooked it, and the
app went on believing the chicken was there. Survivable while the pantry was a
twenty-point nudge; not survivable now it is a filter. `pantry_used_by_meal()`
(migration 0029) returns the overlap and decides nothing; `PantryUsedSheet` asks.
That is the whole design — the recipe wanting 500 g says nothing about whether
that was the last of it, and only the person who cooked knows.

Four confirmation lists now share one square-tick row: the fridge scan, the list
import, bulk meal selection, and this.

## Sprint 55 — Knowing When The Job Is Done

Three things the app was silent about.

**1. Home did not know tonight was settled.** It asked "What are we eating
tonight?" over a large accent-coloured SPIN whether or not a decision had been
made an hour earlier — and spinning again wrote a *second* dinner, so the week's
count and the spend chart both claimed they ate twice. `decidedNow` keys on
`MealMoment.mealName` rather than the calendar day, and on a food day starting at
**04:00** to match `MealMoment.at`'s own boundary: a decision at eight in the
evening is still the answer at half past midnight. When it is settled the panel
leads with the name, in ink rather than the accent, and SPIN is demoted to
"Change our mind".

**2. The eat-out half had a diary it never showed anybody.** `restaurant_history`
has been written on every accepted night out since Sprint 46 and read by exactly
one thing: the scorer, which used it to push down places visited recently. So the
app knew where they had been, quietly used it against them, and had no screen that
said so — while the cooked side got a whole "What we ate" from the same shape of
table. `/eat-out/history` is that screen, in the same vocabulary deliberately, and
it is declared **before** `/eat-out/:id/edit` because `history` is a literal
segment where that pattern wants an id.

`restaurantVisits` is now the single source both it and Home's settled panel read,
and `accept()` invalidates it — otherwise deciding to eat out left Home still
asking the question it had just answered, which is bug 1 reintroduced on the other
half of the app.

**3. Every recipe is written for four.** A household of two has been dividing in
their head at the counter since the app shipped, which is exactly the arithmetic a
computer is for. A stepper on the meal detail, defaulting to the household's own
`preferredServings`, scales the amounts and **writes nothing** — the meal a partner
opens on the same phone is the meal as its author wrote it.

`MealIngredient.scaledBy` rounds **countable** units up and leaves measured ones
alone. Halving four eggs gives two and halving three gives two, because nobody has
ever used 1.5 eggs; halving 500 g of chicken gives 250 g, and rounding *that* up
would be the app inventing a hundred grams of meat. A unit not on the countable
list is treated as measured, which is the safe direction. The caveat is printed:
the cost and time above did not move, and a screen that quietly rescaled half its
numbers would be worse than one that rescaled none.

## Sprint 56 — Being The Reason The App Gets Opened

> "1. the fill in the rest in meals doesn't populate description, also change the
> placeholder because when i add meal sometimes its common and not mine.
> 2. do "The app cannot remind anyone it exists""

**"Fill in the rest" filled eleven fields and skipped the twelfth.** The
description was left blank on a written argument — a blurb invented about a dish
nobody has cooked is decoration — which was wrong about what the field is for: it
is the line under the name on the meal detail, and it was the one field with
nothing to look up. Now `ABOUT:` in the recipe block, placed **second** so a
reply the function truncates loses a late step rather than this, and asked for as
*what the dish is* rather than what is nice about it. The prompt forbids
"delicious", "family favourite" and "everyone will love" by name.

**And both placeholders assumed the meal was somebody's own.** "Tita Baby adobo"
on the name and "What makes it yours?" on the description — a personal example on
the first field of the form reads as an instruction, and most meals added here are
ordinary dishes going into the common list, which is what the toggle already
defaults to. "What makes it yours?" has no answer for sinigang.

## The reminder

**The app could not tell anyone it existed.** `/profile/settings/notifications`
had been a `PlaceholderScreen` marked "Sprint 49 (P2)" for two sprints, there was
no notification package in `pubspec.yaml`, and `SettingsScreen` deliberately
omitted the tile with a comment explaining that a tile leading to a placeholder
teaches people tiles do not work. Meanwhile every feature in the app answers a
question that arrives at half five, in a kitchen, from somebody who is hungry and
is not thinking *let me open an app*.

**A short queue, not a repeating alarm, and not one-at-a-time.** Both obvious
designs fail. A daily repeat has fixed text, so it says the same nine words all
year and fires on evenings dinner was decided at four. Scheduling only the *next*
one fails more quietly: the reminder arrives, nobody opens the app because they
already decided out loud, and there is never another — a feature that switches
itself off after one use. So `MealReminder.replaceAll` lays down a week from a
fixed block of ids, clearing the block first, and every app open replaces the
whole queue.

* **Only the first one carries facts.** "2 things to use up" is true this evening
  and a guess by Thursday. The rest carry the plain invitation.
* **It skips an evening that is already settled**, through Sprint 55's
  `decidedNow`. A reminder that asks a question already answered is the last one
  somebody leaves switched on.
* **It follows the clock.** `MealMoment.at(when).mealName`, so a reminder set for
  eleven asks about lunch — the same vocabulary as Home's heading.
* **Permission is asked when the switch is turned on**, never at startup, and the
  switch does not move on a refusal.
* **Off by default.** A notification nobody asked for is the fastest route to
  every notification from this app being blocked at the OS, which cannot be undone
  from inside it.

Inexact alarms on purpose: `SCHEDULE_EXACT_ALARM` is restricted by Google Play to
apps needing alarm-clock precision, and "around half five" is the whole
requirement.

Three Android things that are each silent when wrong. `RECEIVE_BOOT_COMPLETED`
plus the plugin's two receivers, which it ships as classes and not as
declarations — without them the feature compiles, installs, schedules and shows
nothing, and a reboot or a sideloaded APK clears every pending alarm.
`isCoreLibraryDesugaringEnabled` in the *app* module, since the plugin is compiled
against `java.time` and `minSdk` is 24. And `ic_notification.xml`, because Android
masks a small icon to its alpha channel — the usual `@mipmap/ic_launcher` shortcut
puts a solid white square in the status bar.

The setting lives in `SharedPreferences` beside the appearance one, not in the
household row: the permission is granted per device and the alarm is held by that
device's OS.

**Zone handling is deliberately small.** No tz database and no second plugin to
read the device's zone name — a fixed-offset `tz.Location` built from
`DateTime.now().timeZoneOffset`, which is exactly right for the horizon being
scheduled and self-corrects on the next open. The failure mode is one reminder an
hour out for a household that crosses a daylight-saving boundary and does not open
the app for a day. The Philippines has not observed daylight saving since 1978.

## Sprint 57 — Where Confirmations Go, And Asking Before Deleting

> "how about the success or error alert? can we make it show at the top like a
> dynamic island? … then add confirm delete confirmation on all screens that has
> delete feature"

**Every confirmation in this app was competing with the navigation.** The theme
set `SnackBarBehavior.floating` and the shell runs `extendBody` under a floating
capsule, so all twenty-one of them surfaced in the same eighty pixels as the
primary navigation — sitting on it or shouldering it aside. Two things wanted one
place, and one of them is how you move around the app.

`AppToast` is a pill at the top, owned by a single `ToastHost` installed in
`MaterialApp.builder` — below the theme and the media query, above the router's
navigator, so one host covers every route, sheet and full-screen takeover.

**It takes no `BuildContext`, and that fixes a class of bug rather than saving a
parameter.** Several callers pop a sheet and *then* confirm — the pantry deduction
sheet and the meal form both do — so the context they were holding is on its way
out of the tree at the moment it gets used.

**Success and failure no longer look identical.** They did: "6 things came out of
the kitchen" and "That could not be saved" were the same grey rectangle, which
made success and error the two tones in the palette that nothing used. A glyph
carries the difference alongside the colour, because DESIGN_SYSTEM §11 forbids
colour meaning anything on its own. The ground stays ink — a full-width coloured
banner would be the loudest thing in the app for three seconds, and the one accent
belongs to SPIN.

Not literally a Dynamic Island. The morphing is Apple's hardware affordance doing
a job; there is no notch to grow out of here, and imitating it would read as a
copy rather than as this app. It slides down, holds, slides up. Tap or swipe up to
send it away early.

Deliberate details, each of which was a bug first:

* A **serial** on every message. Without it, ticking two items in a row shows one
  pill and then nothing — an equal value does not notify.
* **One at a time, replacing.** A queue would make somebody who ticks six things
  wait eighteen seconds to hear about the sixth.
* **Cleared when the fade finishes, not when it starts.** `Opacity` of zero still
  hit-tests, so a pill left in the tree would silently swallow every tap across
  the top of the screen for the rest of the session — and `IgnorePointer` covers
  the hundred and fifty milliseconds it spends leaving.
* **`Positioned.fill` for the app content.** A non-positioned child of a `Stack`
  gets *loosened* constraints, which is fine until one screen holds an unbounded
  scroll view.
* **The tone follows the count, not the failure.** "9 added — the rest could not
  be" is nine things on a list; calling that a failure would be the app disowning
  work it did.

## Asking before deleting

Six of the nine destructive paths already confirmed. Three did not, and they were
the three that could be triggered by accident:

* **A grocery line, swiped.** A swipe is deliberate right up until the list is
  long enough to scroll, and then it is something a thumb does by accident while
  walking. The dialog names where the line came from when a meal put it there,
  because that changes the decision.
* **`Clear done`.** The most destructive tap on the screen and it had nothing at
  all: `clear_completed` is a `delete … where is_completed`, one tile away from
  `Add`, so a mistimed thumb threw away a whole shop. The ability to un-tick a
  line — the safety net everywhere else on that list — stops existing the moment
  the row is gone. The count is in the question, because clearing twelve is a
  different decision from clearing one.
* **A pantry line, swiped.** More to lose than the shopping list: the row carries
  an amount and often a date somebody typed, and it is what the roulette's "cook
  what we have" filter reads. A row deleted by a stray thumb quietly narrows what
  the app offers for dinner, which is the last place a mistake shows up as itself.

The cost is one tap on an action nobody performs often. Ticking is what happens
twenty times in a shop, and ticking is untouched.

**Three paths deliberately left alone**, because none of them deletes anything
stored: removing an ingredient row from an unsaved meal draft, un-picking a name
on the recipe generator, and the pantry deduction sheet — which *is* a
confirmation.

## Sprint 57b — The Island, Properly, And A Table You Can Scan

> "1. make the dynamic island alert DESIGN 100x BETTER! 2. why the meals list so
> messy? make it 100x better and more compact!"

### Three bugs the first pill was wearing as a style

**A double yellow underline under every message.** The toast layer hangs off
`MaterialApp.builder`, so it is under the theme and under **no `Material`** — and
a `Text` there merges its style with `WidgetsApp`'s fallback `DefaultTextStyle`,
which carries `decoration: underline, decorationColor: yellow, decorationStyle:
double`. None of this app's typography sets `decoration`, and a null field is
exactly what `merge` fills in. So every confirmation in the app was drawn with
Flutter's own "you forgot a Material" marker on it, and it read as a design
choice.

**The action gave no feedback.** Same root cause from the other end: an `InkWell`
with no `Material` ancestor has nothing to paint ink on. The one tappable thing in
the pill did nothing visible when pressed.

**And in the dark theme it was a white slab.** `surfaceInverse` is the right token
for "the opposite of the page" and the wrong one for this. A notification is not
an inversion of the page, it is an object *above* it — and the thing being
modelled here is darker than what it floats over, in every wallpaper. It is now
ink at both ends of the theme, with a hairline in the dark one, because with no
value difference to shadow against a shadow separates nothing.

### And the design

* **The tone is a filled disc with the glyph knocked out of it** — the app's own
  vocabulary, from `ConfirmationDialog`'s tinted circle and
  `DashboardActionRow`'s filled square. A bare coloured glyph on ink was the
  weakest possible version: at 16 px a mid-green tick and an amber warning read as
  the same grey mark, so the one thing the pill exists to distinguish was the one
  thing invisible.
* **Outlined, not filled, for a plain statement.** Not news, so it does not arrive
  wearing a colour.
* **It grows the last six per cent into place** alongside the slide. That is the
  whole difference between a rectangle appearing and an object arriving, and it is
  deliberately small — a pill that bounces is a pill somebody watches instead of
  reads.
* Inset from both edges rather than flush. An object touching both sides of the
  screen is a banner, and a banner is part of the page.

### The meals table

Four things, and every one of them was the same mistake: saying something once per
row that only needed saying once per column.

* **`A HEAD` under sixty figures.** Six characters of boilerplate, and it was
  doing active harm rather than just taking space: the value column is `Flexible`,
  so it took the width of the *longest thing in it* — and the longest thing was
  the caption, not the price. That is what was squeezing the cooking time off the
  line above. It now sits once in the `COST A HEAD` heading, which is where a
  column label belongs.
* **`FILIPINO · 30 MI…`** The metadata line had four items and room for two, so
  what a reader saw was a cuisine the coloured dot already gave them and a cooking
  time cut in half. Difficulty never rendered on any row at any width — nothing in
  the app filters on it and the time says most of what it meant — so it is gone,
  and that is what buys the time enough room to be a number.
* **Names wrapping to two lines.** "Garlic Fried Rice and Egg" made its row taller
  than its neighbours, and a list of uneven rows is what "messy" means: the eye
  stops being able to use the rhythm to scan. `DashboardRow` takes
  `titleMaxLines` now, defaulting to two so every other screen is unchanged, and
  the table asks for one.
* **A panel's spacing on a table's rows.** `DashboardRow` gained `isDense`. The
  default is right for four rows and wrong for sixty, where it was two thirds of a
  screen spent on air. Roughly a third more meals per screen.

`MealTableRow.ruleInset` moved from `space3` to `space2` with it — the hairlines
were lining up with a gap that no longer existed.

## Sprint 57c — Two bugs, one of them mine twice

> "1. theres empty space in meals list, meal names cant even display full, take
> advantage of that empty space. 2. i cant edit grocery name"

### A loose flex child does not give its allocation back

`DashboardRow` has had three versions of the same twelve lines, and the comment on
the second one asserted the exact thing that was untrue.

Version one: a bare `Column` for the figure. Non-flex, so it takes its full
intrinsic width and the `Expanded` title gets the remainder — "Food preferences"
beside "Filipino, Japanese · 1 avoided" rendered as `Food pr / efere…`.

Version two: `Flexible`. The comment said "a short figure still takes only what it
needs and the title keeps the rest". **The first half is true and the second is
not.** Both children carry flex 1, so each is *allocated* half the free space; the
`Expanded` title fills its half, the loose figure takes only what `₱100` needs —
and the remainder of the figure's allocation stays where it was, as dead space at
the end of the row. The title never sees it. A list of sixty prices with a hundred
pixels of nothing beside each one, and `Fried Siomai R…` on the left.

Version three, and the one that was wanted from the start: **a cap, not a flex.**
Non-flex children are laid out before the flex pass, so the figure takes its
intrinsic width and `Expanded` gets every pixel it does not use — while the cap
stops a long value starving the title, which is the only thing the flex was ever
for. A fixed 132 dp scaled by the reader's text size rather than a fraction
measured by a `LayoutBuilder`: a number cannot throw, and `DashboardRow` appears
in enough layouts that adding a widget which fails under intrinsic sizing is the
worse trade.

Meal names gained roughly a hundred pixels.

### The grocery sheet could not rename anything

Add-only, on the reasoning that the heading already says the name so a field under
it would be the same fact twice. Exactly the mistake the pantry sheet made two
sprints earlier, and the same answer: **a heading is not a control.** A line
imported from a photo of a shopping list arrives misspelled, a line typed
one-handed in an aisle arrives wrong, and the only fix available was to delete it
and start again.

The rename itself cannot be an update. `GroceryItem.name` reads `ingredientName ??
customName`, so a line that came from the shared vocabulary shows the
*ingredient's* name — writing a new `custom_name` on it would change a column and
nothing on screen. So `GroceryController.rename` is **add then remove**, matching
`PantryController.rename`: `add` resolves the new name against the vocabulary,
which is also what puts the line in the right aisle, and doing it in that order
means a failure leaves the original intact rather than deleting the only copy.

The tick does not carry across, which is correct rather than a shortcut — what was
bought was the old thing. And the suggestion chips now appear on an edit too,
where they matter more than on an add: a renamed line that misses the vocabulary
lands in "Everything else".

A case-insensitive comparison decides whether it is a rename at all, so fixing a
capital stays an update and does not spend a round trip resolving to the same row.

---

# 🚦 Definition of Done

A sprint is complete when:

* The feature works.
* Loading, empty and error states exist.
* Auth rules are respected and queries are secured.
* RLS policies are tested where applicable.
* It runs on the real device.
* No critical bugs remain.
* Code is committed **and pushed** to `main`.
* Documentation is updated where it stopped being true.

---

# 🌿 Git Workflow

Commit straight to `main`. Two developers, one of whom is an agent, do not need a
`develop` branch and a feature-branch convention to coordinate — that ceremony
exists to stop a team stepping on each other.

Conventional commits:

```text
feat: add restaurant roulette
fix: resolve pantry unit conversion
refactor: simplify recommendation engine
docs: update setup instructions
chore: update dependencies
```

Push before the next sprint starts.

---

# 🔐 Security Checklist

Unchanged by the rescope. Two users is not a security model.

* [ ] Supabase RLS enabled on every table.
* [ ] RLS policies tested, including negative cases.
* [ ] No service-role key inside Flutter.
* [ ] No AI provider key inside Flutter.
* [ ] Environment files git-ignored, values never logged.
* [ ] Storage policies configured.
* [ ] Auth redirects verified after the application-id change.
* [ ] Household access verified — the other household's data is unreachable.
* [ ] Edge Functions authenticated.
* [ ] Rate limiting on AI.
* [ ] No credential or technical exception text in user-facing copy.
* [ ] Debug logging off in release.

---

# 📱 Quality Checklist

* [ ] The real phone tested.
* [ ] Small and large screens.
* [ ] Dark mode.
* [ ] Slow network.
* [ ] Offline behaviour.
* [ ] Loading, empty and error states.
* [ ] Reduced motion.
* [ ] Text scaling at both clamp bounds.
* [ ] Deep links, after the application-id change.

---

# 🎯 Done Definition For The Whole Thing

The app is finished when the two of us can:

1. Sign in once, and stay signed in.
2. Write our own meals, and spin over only those if we want.
3. Get a recommendation that knows our budget, our time, our mood and what we ate
   yesterday.
4. Accept it, and have it recorded.
5. See what is in the pantry, and what is about to go off.
6. Be offered meals we can cook right now.
7. Get a grocery list built from the meal we just accepted.
8. Ask the app in words, and get an answer from our own library.
9. Photograph the fridge and have the pantry mostly fill itself in.
10. Spin for a restaurant on the nights nobody is cooking.
11. Use all of it for a month without hitting a bug that matters.

---

# ⏱️ The One Metric

## Time to Decision — under 60 seconds

Recorded on every accepted meal, measured from app open rather than from the
spin: the browsing and the filter-fiddling before the first tap are part of the
cost, and a measurement starting at the spin would flatter it.

Everything else recorded is diagnostic — how many spins it took, what emptied the
pool, how long the pick took against the animation.

---

# 🏁 Final Goal

> **"I don't know."**
>
> **"You decide."**
>
> **"Anything is fine."**

into:

# **🎰 What's Cooking? has decided.**

# **Spin. Decide. Eat.**
