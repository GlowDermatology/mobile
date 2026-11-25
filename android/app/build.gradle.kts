import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // No com.google.gms.google-services plugin: Firebase is initialised from Dart
    // (lib/firebase_options.dart), so google-services.json is never needed.
}

// Release signing: android/key.properties (never committed, see docs/release.md).
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// Social sign-in ids (public identifiers, docs/env.md). Each comes from the dart-define of the
// same name (tool/defines/<preset>.json, passed by Flutter as -Pdart-defines), else a Gradle
// property (-PFACEBOOK_APP_ID=… or ~/.gradle/gradle.properties), else an environment variable,
// else empty: the Facebook SDK then stays uninitialised and the app hides its button.
val dartDefines: Map<String, String> =
    (findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            val decoded = runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            }.getOrNull() ?: return@mapNotNull null
            val equals = decoded.indexOf('=')
            if (equals > 0) decoded.substring(0, equals) to decoded.substring(equals + 1) else null
        }
        ?.toMap()
        ?: emptyMap()

fun publicId(name: String): String =
    listOf(dartDefines[name], findProperty(name) as String?, System.getenv(name))
        .firstOrNull { !it.isNullOrBlank() }
        ?.trim()
        ?: ""

val facebookAppId = publicId("FACEBOOK_APP_ID")
val facebookClientToken = publicId("FACEBOOK_CLIENT_TOKEN")

android {
    namespace = "uz.glowderma.app"
    // 37: required by flutter_local_notifications 23 and current AndroidX (targetSdk stays
    // the Flutter default).
    compileSdk = maxOf(37, flutter.compileSdkVersion)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "uz.glowderma.app"
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders += mapOf(
            "facebookAppId" to facebookAppId,
            "facebookClientToken" to facebookClientToken,
            // The browser fallback of Facebook Login returns to fb<app id>://. Without an app id
            // a scheme nobody uses, so the app never claims the Facebook app's own fb://.
            "facebookLoginScheme" to
                if (facebookAppId.isEmpty()) "uz.glowderma.app.nofacebook" else "fb$facebookAppId",
        )
    }

    signingConfigs {
        // The fixed key of CI's staging APK (docs/setup.md §7): every build gets the same SHA-1,
        // which Google sign-in's Android OAuth client is registered with. Only CI sets these.
        val stagingKeystore = System.getenv("ANDROID_STAGING_KEYSTORE_FILE").orEmpty()
        if (stagingKeystore.isNotBlank()) {
            create("staging") {
                storeFile = file(stagingKeystore)
                storePassword = System.getenv("ANDROID_STAGING_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ANDROID_STAGING_KEY_ALIAS")
                keyPassword = System.getenv("ANDROID_STAGING_KEYSTORE_PASSWORD")
            }
        }
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            signingConfigs.findByName("staging")?.let { signingConfig = it }
        }
        release {
            // Without android/key.properties the release build is signed with the
            // debug key, so CI and local builds work without secrets.
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
