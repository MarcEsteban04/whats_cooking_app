# What's Cooking? — 70-Sprint Development Roadmap

> **Complete development roadmap from project initialization to production deployment.**

This document defines the full development plan for **What's Cooking?**, a Flutter + Supabase application that helps couples, households, and individuals decide what to eat.

The project is divided into **70 sprints**, progressing from planning and architecture through development, testing, beta release, and production deployment.

---

# 📋 Project Overview

**App:** What's Cooking?
**Platform:** Mobile
**Frontend:** Flutter / Dart
**Backend:** Supabase / PostgreSQL
**Authentication:** Supabase Auth
**Storage:** Supabase Storage
**Realtime:** Supabase Realtime
**Server Logic:** Supabase Edge Functions
**State Management:** Riverpod
**Navigation:** GoRouter
**Version Control:** Git + GitHub

---

# 🎯 Development Goals

The development process should prioritize:

* A fast and intuitive meal-decision experience.
* A fun roulette/randomization system.
* Couple and household collaboration.
* Personalized recommendations.
* Pantry and grocery management.
* Meal planning.
* Budget awareness.
* Reliable synchronization.
* Strong security.
* Excellent performance.
* Production-ready architecture.

The core experience should always remain:

> **Open → Choose preferences → Spin → Decide → Eat**

---

# 🗺️ Development Phases

| Phase | Sprints | Focus                            |
| ----- | ------: | -------------------------------- |
| 1     |   01–05 | Planning & Product Architecture  |
| 2     |   06–10 | Flutter Foundation               |
| 3     |   11–15 | Supabase Backend                 |
| 4     |   16–20 | Authentication & Onboarding      |
| 5     |   21–27 | Meal System                      |
| 6     |   28–34 | Roulette & Recommendation Engine |
| 7     |   35–40 | Personalization                  |
| 8     |   41–47 | Couple Mode                      |
| 9     |   48–53 | Pantry & Grocery                 |
| 10    |   54–58 | Meal Planning                    |
| 11    |   59–63 | AI Features                      |
| 12    |   64–66 | Testing & Optimization           |
| 13    |   67–68 | Beta Release                     |
| 14    |   69–70 | Production Deployment            |

---

# PHASE 1 — Planning & Product Architecture

## Sprint 01 — Project Initialization

### Objectives

Establish the project and development workflow.

### Tasks

* Create GitHub repository.
* Initialize Flutter project.
* Define project name and package identifiers.
* Create initial README.
* Configure `.gitignore`.
* Establish Git branching strategy.
* Create development, staging, and production environments.
* Define project coding standards.

### Deliverables

* Working Flutter project.
* GitHub repository.
* Initial project documentation.

---

## Sprint 02 — Product Requirements

### Objectives

Define exactly what the application needs to accomplish.

### Tasks

Document:

* Target users.
* Core problem.
* Core value proposition.
* MVP features.
* Future features.
* User stories.
* Success metrics.
* Non-goals.

### Deliverables

* Product requirements document.
* MVP scope.

---

## Sprint 03 — User Flows

### Objectives

Map the major application journeys.

### Tasks

Design flows for:

* First launch.
* Registration.
* Login.
* Onboarding.
* Home.
* Meal discovery.
* Roulette.
* Meal acceptance.
* Meal history.
* Favorites.
* Pantry.
* Grocery list.
* Couple mode.
* Meal planning.
* Profile.

### Deliverables

* User-flow documentation.
* Navigation map.

---

## Sprint 04 — UI/UX Design System

### Objectives

Create a consistent visual language.

### Tasks

Define:

* Colors.
* Typography.
* Spacing.
* Border radius.
* Icons.
* Buttons.
* Cards.
* Bottom navigation.
* Dialogs.
* Bottom sheets.
* Loading states.
* Empty states.
* Error states.

### Deliverables

* UI design system.
* Reusable component specifications.

---

## Sprint 05 — Technical Architecture

### Objectives

Finalize the application's technical architecture.

### Tasks

Define:

* Flutter architecture.
* Feature-based folder structure.
* State management strategy.
* Repository pattern.
* Supabase architecture.
* Database relationships.
* Authentication architecture.
* Security model.
* API/Edge Function strategy.

### Deliverables

* Technical architecture document.
* Database ERD.
* Initial development conventions.

---

# PHASE 2 — Flutter Foundation

## Sprint 06 — Flutter Project Structure

### Tasks

Create:

```text
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── extensions/
│   ├── network/
│   ├── router/
│   ├── theme/
│   └── utils/
│
├── features/
│   ├── auth/
│   ├── onboarding/
│   ├── home/
│   ├── meals/
│   ├── roulette/
│   ├── couple/
│   ├── pantry/
│   ├── grocery/
│   ├── planner/
│   ├── history/
│   ├── ai/
│   └── profile/
│
└── main.dart
```

Configure:

* Riverpod.
* GoRouter.
* Freezed.
* JSON serialization.

---

## Sprint 07 — Theme Implementation

### Tasks

* Implement Material 3.
* Create light theme.
* Create dark theme.
* Create typography system.
* Create spacing constants.
* Create reusable button styles.
* Create card styles.
* Create input styles.

---

## Sprint 08 — Reusable UI Components

Build reusable components:

* AppButton.
* AppTextField.
* MealCard.
* CuisineChip.
* FilterChip.
* LoadingIndicator.
* EmptyState.
* ErrorState.
* ConfirmationDialog.
* AppBottomSheet.

---

## Sprint 09 — Navigation

Implement:

* Splash route.
* Auth routes.
* Onboarding routes.
* Main application shell.
* Home.
* Meals.
* Pantry.
* Grocery.
* Planner.
* Couple.
* Profile.

Add authentication-based route guards.

---

## Sprint 10 — Application Infrastructure

Implement:

* Environment configuration.
* Logging.
* Error handling.
* App constants.
* Network abstraction.
* Repository interfaces.
* Service layer.
* Global exception handling.

---

# PHASE 3 — Supabase Backend

## Sprint 11 — Supabase Setup

### Tasks

* Create Supabase project.
* Configure Flutter Supabase SDK.
* Configure environment variables.
* Connect Flutter to Supabase.
* Test database connectivity.

---

## Sprint 12 — Core Database

Create:

* `profiles`
* `households`
* `household_members`
* `meals`
* `ingredients`

Add:

* Primary keys.
* Foreign keys.
* Constraints.
* Timestamps.
* Indexes.

---

## Sprint 13 — Meal Database Relationships

Create:

* `meal_ingredients`
* `favorite_meals`
* `disliked_meals`
* `meal_history`

Implement relationships between meals and ingredients.

---

## Sprint 14 — Pantry & Grocery Database

Create:

* `pantry_items`
* `grocery_lists`
* `grocery_items`

Add household relationships.

---

## Sprint 15 — Security & RLS

Implement Row Level Security.

Ensure users can only access:

* Their own profile.
* Their own preferences.
* Their household data.
* Their own private information.

Test unauthorized access attempts.

---

# PHASE 4 — Authentication & Onboarding

## Sprint 16 — Authentication Screens

Build:

* Welcome.
* Login.
* Registration.
* Forgot password.
* Reset password.

---

## Sprint 17 — Supabase Authentication

Implement:

* Session persistence.
* Authentication state.
* Login.
* Registration.
* Logout.
* Password recovery.
* Auth error handling.

---

## Sprint 18 — Onboarding

**Social Authentication was cancelled here** — see docs/MVP_SCOPE.md §7. Onboarding
moved forward into this slot. Numbering from Sprint 20 is unchanged, so every other
reference in this document still holds.

Create onboarding questions for:

* Name.
* Favorite cuisines.
* Disliked foods.
* Dietary preferences.
* Cooking preferences.
* Default budget.
* Maximum cooking time.

---

## Sprint 19 — *(folded into Sprint 18)*

Vacated by the change above. Left in place rather than renumbered.

---

## Sprint 20 — Profile

Implement:

* Profile information.
* Avatar.
* Display name.
* Food preferences.
* Budget.
* Cooking preferences.
* Dietary settings.
* Account settings.

---

# PHASE 5 — Meal System

## Sprint 21 — Initial Meal Database

Create the initial meal catalog.

Categories should include:

* Filipino.
* Japanese.
* Korean.
* Chinese.
* Italian.
* Mexican.
* American.
* Breakfast.
* Lunch.
* Dinner.
* Snacks.
* Desserts.

---

## Sprint 22 — Meal Discovery

Implement:

* Meal feed.
* Search.
* Categories.
* Cuisine filters.
* Sorting.
* Pagination.

---

## Sprint 23 — Meal Details

Implement meal detail screen displaying:

* Image.
* Description.
* Cuisine.
* Category.
* Ingredients.
* Estimated cost.
* Cooking time.
* Difficulty.
* Servings.
* Instructions.

---

## Sprint 24 — Favorites

Implement:

* Add favorite.
* Remove favorite.
* Favorites screen.
* Favorite synchronization.

---

## Sprint 25 — Disliked Meals

Implement:

* Dislike.
* Remove dislike.
* Disliked meals management.
* Recommendation exclusion.

---

## Sprint 26 — Custom Meals

Allow users to create their own meals.

Support:

* Name.
* Description.
* Ingredients.
* Instructions.
* Cost.
* Cooking time.
* Category.
* Image.

---

## Sprint 27 — Meal System Optimization

Improve:

* Search performance.
* Database indexes.
* Pagination.
* Caching.
* Image loading.
* Offline-friendly states.

---

# PHASE 6 — Roulette & Recommendation Engine

## Sprint 28 — Roulette UI

Build the signature **What's Cooking?** interaction.

Implement:

* Spin button.
* Animation.
* Meal cycling.
* Suspense effect.
* Result reveal.
* Try Again button.

---

## Sprint 29 — Basic Randomizer

Implement basic randomized meal selection.

Requirements:

* Random selection.
* Exclude disliked meals.
* Exclude unavailable meals.
* Support custom meals.

---

## Sprint 30 — Roulette Filters

Add:

* Budget.
* Cuisine.
* Category.
* Cooking time.
* Difficulty.
* Meal type.

---

## Sprint 31 — Meal History Integration

When a meal is accepted:

```text
Roulette
    ↓
Accepted Meal
    ↓
Meal History
    ↓
Recommendation Engine
```

Store:

* Meal.
* Date.
* Time.
* Meal type.
* Estimated/actual cost.
* Household.

---

## Sprint 32 — Repetition Prevention

Implement:

* Recently eaten detection.
* Repeat penalties.
* Variety rules.
* Recent cuisine penalties.
* Configurable repetition window.

---

## Sprint 33 — Weighted Recommendation Engine

Create the first intelligent scoring system.

Example:

```text
Preference Match        +30
Budget Match            +20
Ingredient Match        +20
Partner Compatibility   +25
Favorite Meal           +15
Cuisine Variety         +10
Cooking Time Match      +10
Recent Meal             -15
Disliked Meal           -100
```

The engine should still preserve randomness.

---

## Sprint 34 — Roulette Polish

Improve:

* Animation quality.
* Haptic feedback.
* Loading states.
* Error states.
* Result transitions.
* Meal acceptance flow.
* Analytics events.

The roulette should feel like the application's signature feature.

---

# PHASE 7 — Personalization

## Sprint 35 — Preference Engine

Implement:

* Favorite cuisines.
* Disliked ingredients.
* Dietary preferences.
* Cooking preferences.
* Budget preferences.
* Time preferences.

---

## Sprint 36 — Mood-Based Recommendations

Add:

* Comfort food.
* Craving.
* Healthy.
* Spicy.
* Junk food.
* Light meal.
* High protein.
* Cheap.
* Surprise me.

---

## Sprint 37 — Meal Preference Learning

Track:

* Accepted meals.
* Rejected meals.
* Favorites.
* Repeated selections.
* Cuisines.
* Categories.

Use this data to improve future recommendations.

---

## Sprint 38 — Budget Intelligence

Implement:

* Per-meal budget.
* Daily budget.
* Weekly budget.
* Budget history.
* Budget-aware recommendations.

---

## Sprint 39 — Variety Engine

Prevent users from receiving repetitive recommendations.

Prioritize:

* Different cuisines.
* Different proteins.
* Different meal types.
* Different cooking methods.

---

## Sprint 40 — Recommendation Testing

Test the recommendation engine against multiple scenarios:

* Low budget.
* Short cooking time.
* Multiple restrictions.
* Recent meal repetition.
* Strong preferences.
* Conflicting preferences.

Tune recommendation weights.

---

# PHASE 8 — Couple Mode

## Sprint 41 — Household Creation

Implement:

* Create household.
* Household name.
* Household owner.
* Household settings.

---

## Sprint 42 — Partner Invitations

Implement:

* Invite partner.
* Invitation code/link.
* Accept invitation.
* Decline invitation.
* Remove member.

---

## Sprint 43 — Shared Preferences

Support shared household information:

* Favorite meals.
* Meal history.
* Pantry.
* Grocery list.
* Meal plans.

---

## Sprint 44 — Individual Preferences

Maintain separate preferences for each household member.

Example:

```text
Partner A
Likes chicken.
Avoids fish.

Partner B
Likes pasta.
Avoids spicy food.
```

---

## Sprint 45 — Can't Agree Mode

Implement collaborative meal voting.

Flow:

```text
Generate Meals
      ↓
Partner A Votes
      ↓
Partner B Votes
      ↓
Compare
      ↓
Find Match
```

---

## Sprint 46 — Couple Recommendation Engine

Modify the recommendation engine to consider:

* Partner A preferences.
* Partner B preferences.
* Shared favorites.
* Conflicting dislikes.
* Household budget.
* Recent shared meals.

---

## Sprint 47 — Realtime Couple Features

Use Supabase Realtime for:

* Favorites.
* Voting.
* Grocery updates.
* Household changes.
* Meal planning.

---

# PHASE 9 — Pantry & Grocery

## Sprint 48 — Pantry

Implement:

* Add ingredient.
* Remove ingredient.
* Edit quantity.
* Units.
* Search.
* Categories.

---

## Sprint 49 — Pantry Expiration

Add:

* Expiration dates.
* Expiring-soon indicator.
* Expired ingredients.
* Expiration notifications.

---

## Sprint 50 — Ingredient Matching

Implement:

```text
Pantry Ingredients
       ↓
Compare Against Meals
       ↓
Calculate Match %
       ↓
Recommend Meals
```

Example:

> Chicken Adobo — 100% available

---

## Sprint 51 — Grocery Lists

Implement:

* Create list.
* Add item.
* Edit item.
* Delete item.
* Check item.
* Clear completed items.

---

## Sprint 52 — Automatic Grocery Generation

When a meal is selected:

```text
Selected Meal
      ↓
Required Ingredients
      ↓
Compare Pantry
      ↓
Find Missing Ingredients
      ↓
Add To Grocery List
```

---

## Sprint 53 — Realtime Grocery Sync

Synchronize grocery lists between household members.

Example:

Partner A checks:

> ☑ Chicken

Partner B immediately sees:

> ☑ Chicken

---

# PHASE 10 — Meal Planning

## Sprint 54 — Weekly Planner

Create weekly calendar.

Support:

* Breakfast.
* Lunch.
* Dinner.
* Snacks.

---

## Sprint 55 — Add Meals To Planner

Allow users to:

* Add meal.
* Replace meal.
* Remove meal.
* Move meal.
* View meal details.

---

## Sprint 56 — Automatic Meal Planning

Generate weekly plans based on:

* Budget.
* Preferences.
* History.
* Pantry.
* Variety.
* Cooking time.

---

## Sprint 57 — Ingredient Reuse

Optimize plans to reuse ingredients.

Example:

```text
Monday
Chicken Adobo

Tuesday
Chicken Fried Rice

Wednesday
Chicken Sandwich
```

---

## Sprint 58 — Planner → Grocery

Generate a grocery list from the entire weekly meal plan.

Combine duplicate ingredients.

Example:

```text
Chicken
Required: 1.5kg
```

instead of three separate grocery entries.

---

# PHASE 11 — AI Features

## Sprint 59 — AI Infrastructure

Create secure AI architecture.

```text
Flutter
   ↓
Supabase Edge Function
   ↓
AI Provider
```

Implement:

* AI request service.
* Authentication.
* Rate limiting.
* Error handling.
* Usage tracking.

Never expose AI API keys inside Flutter.

---

## Sprint 60 — AI Meal Assistant

Implement conversational requests such as:

> “What should we eat tonight?”

> “I only have chicken and eggs.”

> “We have ₱200.”

> “I don't want to cook for more than 20 minutes.”

The AI should use available user context.

---

## Sprint 61 — AI Recipe Generation

Allow users to request recipes from ingredients.

Example:

> “Create a recipe using chicken, eggs, and rice.”

AI generates:

* Recipe name.
* Ingredients.
* Quantities.
* Instructions.
* Estimated cooking time.

Generated recipes can optionally be saved.

---

## Sprint 62 — AI Fridge Scanner

Implement:

* Image upload.
* AI image analysis.
* Ingredient detection.
* User confirmation.
* Pantry insertion.

Users must be able to correct detected ingredients.

---

## Sprint 63 — AI Personalization

Combine:

* Meal history.
* Preferences.
* Budget.
* Pantry.
* Couple preferences.
* Planner.
* Previous AI interactions.

Use this context to generate increasingly relevant recommendations.

---

# PHASE 12 — Testing & Optimization

## Sprint 64 — Unit Testing

Test:

* Recommendation engine.
* Budget calculations.
* Ingredient matching.
* Meal history.
* Preference logic.
* Household permissions.
* Grocery calculations.

---

## Sprint 65 — Integration Testing

Test:

* Authentication.
* Supabase queries.
* Realtime synchronization.
* Household sharing.
* Roulette flow.
* Pantry flow.
* Grocery flow.
* Meal planner.

---

## Sprint 66 — UI, Performance & Security Testing

Test:

* Screen responsiveness.
* Animation performance.
* Memory usage.
* Image loading.
* Offline states.
* Slow networks.
* Error handling.
* RLS policies.
* Authentication security.

Optimize:

* Database queries.
* Image sizes.
* Flutter rebuilds.
* Network requests.
* Caching.

---

# PHASE 13 — Beta Release

## Sprint 67 — Internal Alpha

Release the application to the development team.

Test:

* Complete user registration.
* Complete onboarding.
* Roulette.
* Meal management.
* Couple mode.
* Pantry.
* Grocery.
* Planner.
* AI.

Create a bug backlog.

Classify issues:

```text
P0 — Critical
P1 — High
P2 — Medium
P3 — Low
```

Fix all P0 issues before continuing.

---

## Sprint 68 — Closed Beta

Release to a small group of real users.

Collect feedback on:

* Ease of use.
* Roulette experience.
* Recommendation quality.
* Couple mode.
* Performance.
* Bugs.
* Missing features.

Track:

* Daily active users.
* Weekly active users.
* Roulette spins.
* Accepted meals.
* User retention.
* Time to decision.

Prioritize real user feedback over adding unnecessary features.

---

# PHASE 14 — Production Deployment

## Sprint 69 — Production Preparation

### App

Finalize:

* App icon.
* Splash screen.
* App name.
* Screenshots.
* Store descriptions.
* Privacy policy.
* Terms of service.
* Support information.

### Backend

Prepare:

* Production Supabase project.
* Production database.
* Production RLS policies.
* Production storage.
* Edge Functions.
* AI API configuration.
* Monitoring.
* Backups.

### Flutter

Configure:

* Production environment.
* Release signing.
* Android package.
* iOS bundle identifier.
* Version number.
* Build number.

Run final release tests.

---

## Sprint 70 — Production Deployment

### Android

Build:

```text
flutter build appbundle --release
```

Prepare the Google Play release.

### iOS

Build and archive the production application.

Submit through App Store Connect.

### Backend

Deploy:

* Production database migrations.
* Edge Functions.
* Storage policies.
* RLS policies.
* Production configuration.

### Final Verification

Test the production environment:

* Registration.
* Login.
* Logout.
* Onboarding.
* Meal browsing.
* Roulette.
* Favorites.
* Meal history.
* Couple mode.
* Pantry.
* Grocery.
* Planner.
* AI.
* Notifications.
* Realtime synchronization.

### Launch

Release **What's Cooking?** to production.

Monitor:

* Crash reports.
* API errors.
* Supabase logs.
* AI usage.
* Database performance.
* User feedback.
* Authentication failures.

---

# 🚦 Definition of Done

A sprint is considered complete when:

* The feature is implemented.
* UI states are complete.
* Loading states exist.
* Empty states exist.
* Error states exist.
* Authentication rules are respected.
* Database queries are secured.
* RLS policies are tested where applicable.
* The feature works on supported devices.
* Relevant tests pass.
* No critical bugs remain.
* Code is committed to Git.
* Code review is completed.
* Documentation is updated where necessary.

---

# 🌿 Git Workflow

Recommended branch structure:

```text
main
│
├── develop
│
├── feature/auth
├── feature/roulette
├── feature/meals
├── feature/couple
├── feature/pantry
├── feature/grocery
├── feature/planner
└── feature/ai
```

### Commit format

Use conventional commits:

```text
feat: add meal roulette
fix: resolve meal history sync
refactor: simplify recommendation engine
docs: update setup instructions
test: add roulette unit tests
chore: update dependencies
```

---

# 📦 Release Strategy

## Development

Used for active development.

```text
Flutter
   ↓
Development Supabase
```

## Staging

Used for QA and beta testing.

```text
Flutter
   ↓
Staging Supabase
```

## Production

Used by real users.

```text
Flutter
   ↓
Production Supabase
```

Development data must never be mixed with production data.

---

# 🔐 Production Security Checklist

Before launch:

* [ ] Supabase RLS enabled.
* [ ] RLS policies tested.
* [ ] No service-role key inside Flutter.
* [ ] No AI API key inside Flutter.
* [ ] Environment variables secured.
* [ ] Storage policies configured.
* [ ] Authentication redirects verified.
* [ ] Household access verified.
* [ ] Database indexes reviewed.
* [ ] Production backups enabled.
* [ ] Edge Functions authenticated.
* [ ] Rate limiting implemented where required.
* [ ] Sensitive logs removed.
* [ ] Debug mode disabled in production.

---

# 📱 Production Quality Checklist

Before publishing:

* [ ] Android tested.
* [ ] iOS tested.
* [ ] Small screen tested.
* [ ] Large screen tested.
* [ ] Dark mode tested.
* [ ] Slow network tested.
* [ ] Offline behavior tested.
* [ ] Loading states tested.
* [ ] Empty states tested.
* [ ] Error states tested.
* [ ] Push notifications tested.
* [ ] Realtime tested.
* [ ] Authentication tested.
* [ ] Deep links tested.
* [ ] App performance checked.
* [ ] Crash reporting configured.

---

# 🎯 MVP Definition

The MVP is considered successful when users can:

1. Create an account.
2. Complete onboarding.
3. Browse meals.
4. Save favorite meals.
5. Exclude disliked meals.
6. Set a budget.
7. Spin the meal roulette.
8. Receive an intelligent recommendation.
9. Accept the recommendation.
10. View meal history.
11. Create a household.
12. Invite a partner.
13. Share meals with their partner.
14. Add pantry ingredients.
15. Find meals using pantry ingredients.
16. Create a grocery list.
17. Use the application reliably without critical bugs.

---

# 🚀 Launch Success Criteria

The initial production release should focus on validating one primary hypothesis:

> **Can What's Cooking? reliably help people decide what to eat faster than they normally would?**

The most important metric is:

## ⏱️ Time to Decision

### Target:

**Under 60 seconds.**

Secondary metrics:

* Roulette spins per user.
* Accepted recommendations.
* Daily active users.
* Weekly active users.
* Couple households created.
* Meals recorded.
* Pantry usage.
* Grocery lists created.
* Weekly retention.
* Recommendation acceptance rate.

---

# 🏁 Final Development Goal

After 70 sprints, What's Cooking? should be a production-ready mobile application capable of helping users answer one simple question:

# 🍽️ “What's cooking?”

The application should turn:

> “I don't know.”

> “You decide.”

> “Anything is fine.”

into:

> **🎰 What's Cooking? has decided.**

The final product should feel **fast, playful, intelligent, reliable, and genuinely useful**, while maintaining a simple core experience:

# **Spin. Decide. Eat.**