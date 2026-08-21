import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release keystore, or nothing (Sprint 52).
//
// `android/key.properties` is git-ignored and holds the passwords, so nothing
// here has a credential in it — the file is read if it exists and the build falls
// back to debug signing if it does not. That fallback is deliberate: a fresh
// clone must still be able to run `--release` to check that the app *builds* in
// release mode, which is a different question from whether it is signed for
// distribution. See android/key.properties.example.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}

val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.acoretechnology.whatscooking"

    // Ahead of Flutter's default of 36, because flutter_secure_storage 11
    // compiles against 37 and an AAR cannot be consumed by a project built
    // against an older SDK.
    //
    // compileSdk only decides which APIs are available at compile time. minSdk
    // (which devices can install) and targetSdk (which runtime behaviours the
    // app opts into) are untouched below, so this changes nothing about how the
    // app behaves — it is backward compatible by design.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The real one (Sprint 52).
        //
        // **Permanent per install.** Android treats a change of application id as
        // a different app — a rename after the phone has data means uninstall,
        // reinstall, and whatever was only on the device is gone. So it is set
        // once, here, before either phone has anything worth keeping.
        //
        // Reverse DNS on a domain the household actually controls, and no
        // underscore: `com.example.whats_cooking` was the template's, and the
        // underscore is legal but reads as generated. The deep link scheme
        // registered below is a separate identifier and is deliberately not
        // derived from this one.
        applicationId = "com.acoretechnology.whatscooking"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The real keys when they are present, the debug keys when they are
            // not (Sprint 52).
            //
            // **Not an error when the keystore is missing**, on purpose. Two
            // different questions get asked of a release build: "does this app
            // compile and run with the tree shaker and the obfuscator on", which
            // anyone with a clone needs to be able to check, and "is this the
            // artifact that goes on the phone", which needs the keystore. Failing
            // the first because of the second would make the useful check
            // unavailable to whoever does not hold the key.
            //
            // The consequence to know: an APK signed with the debug key **cannot
            // be upgraded** by one signed with the release key. Android refuses an
            // install whose signature differs, so the phone that matters gets the
            // properly signed build the first time — see supabase/README.md's
            // release notes.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Shrinking left off deliberately.
            //
            // R8 with Flutter needs keep rules for anything reached by reflection,
            // and the plugins here — secure storage, shared preferences, the image
            // picker — are exactly the shape that breaks silently: the build
            // succeeds and a feature stops working on the device only. Two people
            // installing one APK do not need the two megabytes, and a smaller
            // download is not worth a failure mode that only appears in release.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
