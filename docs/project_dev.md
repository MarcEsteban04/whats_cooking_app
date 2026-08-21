# What's Cooking? — Development Roadmap

> **A private app for one household of two. Rescoped at Sprint 37.**

This document was a 70-sprint plan for a product with users, a store listing, a
freemium tier and a couple-mode feature set. It is not that any more.

**What's Cooking? is for Marc and his girlfriend.** Two accounts, one shared
kitchen, two phones. Nothing to launch, nobody to acquire, no retention to
engineer. Six features are wanted; everything else has been cut.

---

# 📌 Why the numbering does not restart

Sprints 01–36 are **done and shipped**, and hundreds of code comments, doc
references and commit messages cite them by number — `Sprint 33`'s scoring engine,
`Sprint 25`'s dislike exclusion, `Sprint 32`'s repetition window. Renumbering
history to make the new plan tidy would silently invalidate every one of those.

So the history stays where it is, compressed into one table, and the new plan
continues from **Sprint 37**. The roadmap is now **52 sprints**, not 70 — sixteen
remain.

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
| **Couple Mode** | Phase 8, Sprints 41–47 | No partner to invite twice, no compatibility score worth computing, no "can't agree" voting round — two people in a kitchen can talk. What survives is **Sprint 38**: one shared household so both phones see the same pantry, grocery list and history. |
| **Meal Planning** | Phase 10, Sprints 54–58 | We decide at seven in the evening. A weekly planner is the opposite of a roulette, and the roulette is the product. |
| **Personalization phase** | Sprints 37–40 as written | Budget intelligence, variety engine and preference learning were designed for a large catalogue and an unknown user. Over a library we curated ourselves, "learn what you like" is largely answered by the fact that we added it. Variety and repetition already ship (Sprints 32–33). |
| **Beta Release** | Phase 13, Sprints 67–68 | No alpha group, no closed beta, no bug backlog triage across testers. Two people find the bugs by using it. |
| **Store deployment** | Phase 14, Sprints 69–70 | No Play listing, no App Store review, no screenshots, no privacy policy, no store description. Replaced by **Sprint 52**: release builds installed on two phones. |
| **Gamification, statistics, notifications, monetization** | app_feature §16–18 | Retention and revenue mechanics for a product that has neither problem. |
| **Cooking mode** | app_feature §10 | Step-by-step recipe walkthrough. Genuinely nice, genuinely not one of the six. Listed so it is on the record. |
| **Restaurant discovery** | Future Features | No maps, no ratings API, no location search. Sprint 45 is a list we write. |

**Not cut: security.** Row Level Security, the service-role assertion, the AI-key
assertion and the query-side exclusions all stay. Supabase is on the public
internet whether it has two users or two million.

**Also not cut: Sprint 66.** Performance, RLS verification and the stale test
suite become Sprint 51. Two users is a reason to skip a beta programme, not a
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
| 7 | 37–38 | Our Library, Our Kitchen | ▶ Next |
| 8 | 39–41 | Pantry | |
| 9 | 42–44 | Grocery | |
| 10 | 45–46 | Restaurant Roulette | |
| 11 | 47–50 | AI | |
| 12 | 51–52 | Hardening & Two Phones | |

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

# PHASE 7 — Our Library, Our Kitchen

## Sprint 37 — Our Meals First

The roulette currently spins over sixty meals somebody else chose. The point of
this app is that it spins over ours.

Implement:

* A **"ours only"** switch on the spin, so the pool can be restricted to meals
  this household wrote.
* A **weighting** for our own meals when the switch is off, so a meal we bothered
  to type in outranks a catalogue entry we have never cooked.
* **Add a meal from the spin screen** — the no-match state's best answer is often
  "because we have not told it about the thing we actually cook".
* Make the Meals screen's **"Yours"** count the primary figure it leads with.

The bundled catalogue stays. It is what makes the app usable before the library
fills up, and it is what "Surprise me" needs in order to surprise.

---

## Sprint 38 — Two Phones, One Kitchen

Everything shared, nothing ceremonial. This is what remains of Couple Mode.

Implement:

* **One household**, created on first run.
* **Join by code**, once — the second account joins the first's household.
* Shared: **meal history, pantry, grocery, restaurants, custom meals**.
* Private: **favourites, hidden meals, dietary needs, avoided foods**. A partner
  seeing what you dislike is a social cost with no product benefit; the engine
  reads both server-side regardless.
* Household name and members on the profile screen.

Explicitly **not** built: invitation management, roles beyond owner/member,
compatibility scores, voting rounds, per-partner preference merging.

---

# PHASE 8 — Pantry

## Sprint 39 — Pantry

Implement:

* Add and remove ingredients.
* Quantity and unit.
* Search against the shared ingredient vocabulary.
* Categories.
* Shared across both phones.

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

## Sprint 44 — Live Sync

Supabase Realtime on the grocery list, and **only** the grocery list.

This is the one place realtime is worth its complexity: one of us is standing in
the shop and the other is at home remembering something.

> Partner A checks ☑ Chicken → Partner B sees ☑ Chicken

Everything else stays on refresh-and-invalidate. Realtime subscriptions on
favourites and history would be plumbing for a problem two people who live
together do not have.

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

---

## Sprint 49 — Read The Fridge

Implement:

* Image capture and upload.
* Vision analysis.
* Detected ingredients presented **for confirmation**, never inserted silently.
* Correction before anything is written.

Image recognition is wrong often enough that trusting it would poison the pantry,
and a poisoned pantry poisons the roulette.

---

## Sprint 50 — AI Personalization

Feed the assistant everything the app knows: history, preferences, budget,
pantry, the restaurant list, and previous conversations.

Bounded deliberately. Context is tokens and tokens are money, so what goes in is
chosen rather than dumped.

---

# PHASE 12 — Hardening & Two Phones

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
* Memory and animation performance on the two real devices.
* Confirm no service-role key and no AI provider key reach the client.

---

## Sprint 52 — Two Phones

Not a launch. An install.

* Replace `com.example.whats_cooking` with a real application id, and update the
  **Supabase auth redirect URLs** to match — the deep link back from email
  confirmation and password reset is keyed to the scheme, and getting it wrong
  silently breaks sign-up.
* Real release signing config, replacing the debug keys.
* Production Supabase project, migrations applied, backups on.
* Edge Function secrets set in production.
* `flutter build apk --release`, installed on both phones.
* iOS via a development profile if wanted.

No store listing. No screenshots. No privacy policy. No review process.

**Note:** with no Play listing, `com.example.*` stops being a hard blocker and
becomes a tidiness issue — but the application id is still permanent per install,
so it is worth setting once, here, before either phone has data worth keeping.

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

* [ ] Both real phones tested.
* [ ] Small and large screens.
* [ ] Dark mode.
* [ ] Slow network.
* [ ] Offline behaviour.
* [ ] Loading, empty and error states.
* [ ] Reduced motion.
* [ ] Text scaling at both clamp bounds.
* [ ] Realtime grocery sync between the two phones.
* [ ] Deep links, after the application-id change.

---

# 🎯 Done Definition For The Whole Thing

The app is finished when the two of us can:

1. Sign in on both phones and share one kitchen.
2. Write our own meals, and spin over only those if we want.
3. Get a recommendation that knows our budget, our time, our mood and what we ate
   yesterday.
4. Accept it, and have it recorded.
5. See what is in the pantry, and what is about to go off.
6. Be offered meals we can cook right now.
7. Get a grocery list that updates in the other person's hand.
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
