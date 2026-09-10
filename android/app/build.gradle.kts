import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Phase 6 release signing: reads the real keystore's location/passwords
// from `android/key.properties`, a file deliberately NOT committed to
// this repo (see .gitignore and README.md's "Release signing" section
// for how to generate it). Falls back to debug signing whenever that
// file doesn't exist, so `flutter run --release`/`flutter test` keep
// working on a machine that hasn't set up a real keystore yet — the
// same graceful-fallback stance the rest of this app takes for optional
// platform features.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.kozmokramer.tabletennisscoreboard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Phase 6: real reverse-domain Application ID — Google Play
        // rejects the "com.example" prefix at publish time. This is a
        // draft pick (derived from the developer's own identity, not a
        // registered domain) — see PHASE6_PRELAUNCH_PREP.md for how to
        // change it before the first real Play Console upload if
        // preferred (it cannot be changed after publishing without
        // becoming a new, separate app listing).
        applicationId = "com.kozmokramer.tabletennisscoreboard"
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
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real release signing once `android/key.properties` exists
            // (see README.md's "Release signing" section); debug signing
            // until then, so this repo keeps building out of the box.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
