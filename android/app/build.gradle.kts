plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePath = System.getenv("SWIFTMART_KEYSTORE")
val passwordFile = System.getenv("SWIFTMART_KEY_PASSWORD_FILE")
val releaseKeyAlias = System.getenv("SWIFTMART_KEY_ALIAS") ?: "swiftmart"
val isRelease = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (isRelease) {
    require(!keystorePath.isNullOrBlank() && !passwordFile.isNullOrBlank()) {
        "Set SWIFTMART_KEYSTORE and SWIFTMART_KEY_PASSWORD_FILE for release signing."
    }
}

android {
    namespace = "com.swiftmart.swiftmart_frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.swiftmart.swiftmart_frontend"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!keystorePath.isNullOrBlank() && !passwordFile.isNullOrBlank()) {
            create("swiftmartRelease") {
                storeFile = file(keystorePath)
                storePassword = file(passwordFile).readText().trim()
                keyAlias = releaseKeyAlias
                keyPassword = storePassword
            }
        }
    }

    buildTypes {
        release {
            if (isRelease) signingConfig = signingConfigs.getByName("swiftmartRelease")
        }
    }
}

flutter {
    source = "../.."
}
