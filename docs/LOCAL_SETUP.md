# Local Setup & Troubleshooting

Environment notes for building **What's Cooking?** on Windows, including workarounds for
problems that cost real time to diagnose.

---

## 1. Verified working environment

| Component | Version | Location |
| --------- | ------- | -------- |
| Flutter | 3.47.0 stable | `C:\src\flutter` |
| Dart | 3.13.0 | bundled with Flutter |
| JDK | OpenJDK 25 (JetBrains Runtime) | bundled with Android Studio |
| Android SDK | Build-Tools 36.0.0, Platform 37.0 | `%LOCALAPPDATA%\Android\Sdk` |
| Android cmdline-tools | 23.0 | `…\Sdk\cmdline-tools\latest` |
| Android NDK | 28.2.13676358 | `…\Sdk\ndk\28.2.13676358` |
| Gradle | 9.3.1 (via wrapper) | auto-downloaded |

Confirmed working: `flutter analyze`, `flutter test`, and `flutter build apk --debug`.

---

## 2. Standard setup

```bash
cp config/development.example.json config/development.json
flutter pub get
dart run build_runner build
```

Then verify — these three commands are the gate before every commit, since CI is
unavailable (see [GIT_WORKFLOW.md](GIT_WORKFLOW.md)):

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

---

## 3. Antivirus TLS interception — resolved, kept for the record

**This no longer applies.** Norton was uninstalled, and every workaround below has been
removed from this machine: the custom truststore, both environment variables, and the
`org.gradle.jvmargs` truststore flags. Builds pass without them. The section stays because
the failure is obscure enough to be worth recognising if it ever returns.

**Symptom.** Any Gradle operation fails with:

```text
PKIX path building failed:
unable to find valid certification path to requested target
```

**Cause.** Norton Antivirus's *Web/Mail Shield* intercepted HTTPS and re-signed every
connection with a per-machine root CA. Windows trusted that CA, so browsers were fine and
made this confusing. **Java maintains its own truststore** and did not, so every JVM-based
tool — Gradle, the SDK manager, Kotlin — failed while Chrome loaded the same URL happily.

**What it took to work around it**, if you ever need this again: export the interceptor's
root CA from the Windows store, copy the JDK truststore somewhere writable, import the CA
into the copy with `keytool`, then point every JVM at it via `JAVA_TOOL_OPTIONS` **and**
`GRADLE_OPTS` — both, because Gradle spawns other JVMs that do not inherit `GRADLE_OPTS`.
The copy goes stale whenever Android Studio updates its bundled runtime, so it has to be
regenerated after every JDK upgrade.

**The better answer is the one that was eventually taken:** uninstall the interceptor, or
disable its HTTPS scanning. Maintaining a parallel truststore is a permanent tax on every
JVM on the machine, and it silently weakens TLS verification for everything else.

**Verify the interception is really gone:**

```powershell
# Should report a real CA - e.g. CN=WE1, O=Google Trust Services - not a security product
(Invoke-WebRequest -Uri 'https://dl.google.com' -UseBasicParsing).BaseResponse
```

---

## 4. Kotlin incremental cache failures — still active

**Symptom.**

```text
Execution failed for task ':shared_preferences_android:compileDebugKotlin'.
> Could not close incremental caches in …\caches-jvm\jvm\kotlin:
  class-fq-name-to-source.tab, source-to-classes.tab, internal-name-to-source.tab
```

**Cause — corrected.** This was originally attributed to Norton's real-time scanner
holding locks on Kotlin's `.tab` files. **That was wrong.** Norton has since been
uninstalled and the failure reproduces exactly: clean build, Gradle and Kotlin daemons
killed first, two plugin modules failing the same way. Something else on this machine
still holds those handles — most likely Windows Defender real-time protection scanning
the `E:` build tree.

The lesson worth keeping: *"antivirus was involved once"* is not evidence that antivirus
is involved now. The fix was retained on a diagnosis that had stopped being true.

**Fix.** In `%USERPROFILE%\.gradle\gradle.properties`:

```properties
kotlin.incremental=false
```

Trades rebuild speed for a build that completes at all. The proper fix is a real-time
scanning exclusion for the build tree and `%USERPROFILE%\.gradle` — worth doing, and not
yet done.

---

## 5. Android SDK command-line tools

Android Studio does **not** install `cmdline-tools` by default, and Gradle needs it to
resolve SDK components. Install it from the SDK Manager GUI, or:

```powershell
curl.exe -L -o cmdline-tools.zip https://dl.google.com/android/repository/commandlinetools-win-16111833_latest.zip
# extract so that sdkmanager.bat lands at %LOCALAPPDATA%\Android\Sdk\cmdline-tools\latest\bin\
```

### `sdkmanager` is deprecated and crashes

In cmdline-tools 23.0, `sdkmanager.bat` is a shim over a new `android` CLI and can die with
`0xC0000409` when Gradle invokes it to auto-install the NDK. Install packages manually with
the new CLI instead — note the **slash** in the package path and that `sdk list` shows only
installed packages unless you pass `--all`:

```powershell
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
& "$sdk\cmdline-tools\latest\bin\android.exe" sdk list --all --all-versions "ndk/*"
& "$sdk\cmdline-tools\latest\bin\android.exe" sdk install "ndk/28.2.13676358"
```

The NDK is required because `flutter create` writes `ndkVersion = flutter.ndkVersion` into
`android/app/build.gradle.kts`.

The installer exits with code **9** even on success — that is the analytics upload failing
(also blocked by the TLS interception), not the install. Check for the package directory
rather than trusting the exit code.

---

## 6. `flutter doctor` license warning

```text
[!] Android toolchain
    X Android license status unknown.
```

Cosmetic on this setup. `flutter doctor --android-licenses` reports
*"Warning: The --licenses option is no longer needed"* — the new Android CLI changed how
licenses are handled and Flutter's check has not caught up. **Builds succeed regardless**,
which is the real test.

`[X] Visual Studio` is also expected and irrelevant: it is only needed to build Windows
desktop apps, and this project is mobile-only ([PRD.md](PRD.md) non-goal 8).

---

## 7. Running on a physical device

1. On the phone: **Settings → About phone → tap Build number seven times** to unlock
   Developer Options.
2. **Settings → Developer options → enable USB debugging.**
3. Connect via USB and accept the *Allow USB debugging?* prompt on the phone.
4. Confirm the device is visible, then run:

```bash
flutter devices
flutter run --dart-define-from-file=config/development.json
```

Wireless debugging (Android 11+) also works: enable it in Developer options, then
`adb pair <ip>:<port>` followed by `adb connect <ip>:<port>`.

**iOS cannot be built or tested on Windows.** It requires macOS with Xcode, so the iOS
target stays unverified until a Mac is available.

---

## 8. Machine-local files

None of these are in the repository — they are specific to this workstation:

| Path | Purpose |
| ---- | ------- |
| `%USERPROFILE%\.gradle\gradle.properties` | JVM args, `kotlin.incremental=false` (see section 4) |
| `config\development.json` | Supabase credentials — git-ignored |

Deliberately kept out of the project: machine-specific antivirus and truststore paths
would break the build on any other machine, and on macOS or Linux outright.
