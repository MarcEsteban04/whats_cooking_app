# Onto The Phone

Sprint 52. **Not a launch — an install.** No store listing, no screenshots, no
privacy policy, no review process. Two people, two phones, one APK.

What that changes is which steps matter. Most of a release checklist exists to
satisfy a reviewer or a stranger; what is left here is the handful of things that
are *permanent per install* or that silently break if they are wrong.

---

## What is already done in the repository

| Thing | State |
| ----- | ----- |
| Application id | `com.acoretechnology.whatscooking` — Android `applicationId` and `namespace`, iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER`, and the Kotlin package |
| Launcher label | `What's Cooking?` (Android), `What's Cooking` (iOS — it ellipsises past ~12 characters) |
| Deep link scheme | `whatscooking://` registered in `AndroidManifest.xml` and `Info.plist` |
| Release signing | Reads `android/key.properties` if present, falls back to debug signing if not |
| Camera permission strings | `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`, both naming what happens to the photo |

**The application id is a one-way door once the app is installed.** Android treats
a changed id as a different app: a rename afterwards means uninstall, reinstall,
and losing whatever lived only on the device. It is set now, before either phone
has anything worth keeping. If it should be something else, change it *before* the
first install — `android/app/build.gradle.kts` and the two `project.pbxproj`
files, plus the Kotlin package directory.

---

## 1. The signing key

Once, and then back it up.

```bash
keytool -genkey -v -keystore ~/whats-cooking-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias whatscooking
```

Then copy `android/key.properties.example` to `android/key.properties` and fill
in the four values. Both the keystore and that file are git-ignored.

**Losing the keystore is unrecoverable.** Android refuses to install an APK whose
signature differs from the installed one, so a lost key means uninstall and
reinstall on every phone that has the app. Put the `.jks` and its passwords
somewhere that is not this machine.

Related, and the reason to do this *before* the first install: an APK signed with
the debug key **cannot be upgraded** by one signed with the release key. Sign
properly the first time and every later build installs over the top.

---

## 2. The deep link — the step that fails silently

The app sends `whatscooking://reset-password` as the `redirectTo` on every
password-reset email (`AppConstants.passwordResetRedirect`). Two things have to
agree with that string, and neither of them reports a mismatch usefully:

**In the app** — done. The scheme is claimed by an intent filter on Android and by
`CFBundleURLTypes` on iOS. Until Sprint 52 neither existed, so the link in the
email opened nothing at all: no error, no log, just a tap that did nothing, which
reads as a broken email rather than as a missing intent filter.

**In the Supabase dashboard** — yours to do. *Authentication → URL Configuration*:

* **Site URL**: `whatscooking://reset-password`
* **Redirect URLs** — add both, because Supabase matches the allow-list exactly:
  * `whatscooking://reset-password`
  * `whatscooking://*`

A `redirectTo` that is not on the allow-list is not an error you see in the app.
Supabase sends the email with its *default* redirect instead, which is a hosted
page that has nothing to do with this app — so the reset appears to work right up
until the link lands somewhere useless.

**Test it end to end**, because every layer of this is silent when wrong: ask for
a reset on the phone, close the app completely, open the email, tap the link. The
app should come up on the reset form with a live recovery session —
`AuthChangeEvent.passwordRecovery` is handled ahead of the signed-in cases
precisely so it cannot land on Home instead.

---

## 3. The production Supabase project

A second project, not the development one with the data cleared. The development
project has migrations applied in whatever order they were tried, function
secrets from experiments, and rows from a month of poking at it.

```bash
supabase link --project-ref <production-ref>
supabase db push
```

Then, in the dashboard:

* **Database → Backups.** Turn them on. This is the whole reason to have a
  production project rather than to keep using the development one: the data is
  a household's own food, and it is not reproducible.
* **Authentication → Providers.** Email only. Nothing here uses Google or Apple —
  see `docs/design_ui.md` on the auth screens.
* **Authentication → URL Configuration.** As in §2.
* Confirm **RLS** with `supabase/tests/rls_check.sql`, pasted into the SQL editor.
  A fresh project is exactly where a forgotten `enable row level security` hides.

Point the app at it by editing `config/development.json` — or better, add a
`config/production.json` beside it and pass `--dart-define-from-file=config/production.json`,
so switching back to development is a flag rather than an edit. Both are
git-ignored; only `config/development.example.json` is tracked.

---

## 4. Edge Function secrets

The AI keys live on the function and nowhere else. `AppEnv.assertNoProviderKey`
fails the first frame if one ever reaches the client, so this is the only place
they can go.

```bash
supabase secrets set \
  GROQ_AI_API_KEY=... \
  GEMINI_AI_API_KEY=... \
  OPENAI_API_KEY=...

supabase functions deploy ai-assistant
```

One key is enough — providers with no key are skipped silently rather than
counted as failures. See `supabase/README.md` for the model overrides, including
the separate vision models that the fridge scanner needs.

**Deploy the function even if the keys have not changed.** Sprint 49 added the
vision path to `providers.ts`, and until `ai-assistant` is redeployed the fridge
scanner will fail against a function that cannot read an image.

---

## 5. The build

```bash
flutter build apk --release --dart-define-from-file=config/production.json
```

That produces a **universal** APK — every ABI in one file — which measured 64.6 MB
on the first Sprint 52 build. Two thirds of that is native code for architectures
neither phone has.

For a sideload to a known device, name the architecture instead:

```bash
flutter build apk --release --target-platform android-arm64 \
  --dart-define-from-file=config/production.json
```

Every Android phone worth installing this on is `arm64` — 32-bit ARM has been
gone from new devices for years and `x86_64` is emulators. That is roughly a third
of the size for the same app (27.6 MB against 64.6 MB). Use the universal build
only when you do not know what you are installing onto.

### Check the APK before transferring it

The first install on a real phone crashed on launch with

```
MissingLibraryException: Could not find 'libflutter.so'.
Looked for: [arm64-v8a], but only found: [x86_64].
```

Two things make that possible, and both are silent until the app dies:

* **`flutter run` builds for the attached device only.** A debug APK left in
  `build/app/outputs/flutter-apk/` after running on an emulator contains x86_64
  and nothing else. It is the same directory the release build writes to, and the
  file that is *newest* there is usually the debug one.
* **`--target-platform` does not filter plugin libraries.** Flutter compiles its
  engine for the platform asked for, but plugin AARs ship every ABI — so an
  arm64-targeted APK still grew `lib/x86_64/` and `lib/armeabi-v7a/` directories
  containing a plugin library and *no engine*. Android picks the app's ABI as the
  first entry of `Build.SUPPORTED_ABIS` present in the APK, so a directory that
  exists without an engine in it is a directory the installer can choose. Fixed
  with `abiFilters` in `android/app/build.gradle.kts`, which is the only place
  that reaches the plugin libraries too.

So look inside the file rather than trusting its name:

```bash
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep '\.so$'
```

Every `lib/<abi>/` directory that appears must contain `libflutter.so`. For an
arm64 build the whole listing should be four lines, all under `lib/arm64-v8a/`.

### And check the permissions

The second thing the first real install got wrong, and it is invisible in every
build except the one that matters. The Flutter template declares `INTERNET` in
`android/app/src/debug/` and `android/app/src/profile/` **only** — those exist so
the tooling can attach for hot reload — and leaves the main manifest without it.
Debug and profile builds therefore have network access and the release build does
not. Android does not refuse the connection either; it fails the DNS lookup:

```
SocketException: Failed host lookup: '<project>.supabase.co'
(OS Error: No address associated with hostname)
```

which reads as a broken phone. Declared in the main manifest now, so it applies to
every build type. Verify it survived:

```bash
"$ANDROID_HOME/build-tools/<version>/aapt2" dump permissions \
  build/app/outputs/flutter-apk/app-release.apk
```

`android.permission.INTERNET` must be in the list.

Install with `adb install -r build/app/outputs/flutter-apk/app-release.apk`, or
copy the file to the phone and open it. On Android 8 and later the file manager
asks for permission to install unknown apps — that is the one prompt to expect,
and it is per-app rather than a system-wide setting.

**Shrinking is deliberately off** (`isMinifyEnabled = false`). R8 needs keep rules
for anything reached by reflection, and the plugins here — secure storage, shared
preferences, the image picker — are exactly the shape that breaks *silently*: the
build succeeds and a feature stops working on the device only. Two megabytes is
not worth a failure mode that appears in release and nowhere else.

---

## 6. Before handing over a phone

The checks that are worth doing once on the real device, because none of them can
be done on an emulator:

* **Sign up, confirm, sign in.** Including the email link, per §2.
* **Password reset**, end to end, with the app fully closed.
* **The camera**, both the fridge scanner and the permission prompt — decline it
  once on purpose, and check the app says something useful rather than nothing.
* **A spin on a bad connection.** Turn mobile data down to 2G or walk into a lift.
  Every backend call now has a 15-second deadline (`RemoteCall.defaultTimeout`),
  so the worst honest wait is about fifty seconds before an error you can act on —
  the thing to confirm is that an error *arrives*, because before Sprint 51 it
  never did.
* **Animation and memory.** The reel is the only sustained animation in the app;
  `flutter run --profile` and the DevTools timeline on the real device are the
  only honest way to look at it.

---

## iOS

Only if it ever moves platforms. A development profile, a paid Apple developer
account for anything past seven days, and `flutter build ipa`. The bundle
identifier and the permission strings are already in place; nothing else here has
been exercised on an Apple device.
