plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.chaquo.python")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.oddtunes.oddtunes_app"
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
        applicationId = "com.oddtunes.oddtunes_app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.add("arm64-v8a")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            excludes += "**.proto"
        }
        jniLibs {
            useLegacyPackaging = false
            excludes += "lib/armeabi-v7a/**"
            excludes += "lib/x86/**"
            excludes += "lib/x86_64/**"
        }
    }
}

chaquopy {
    defaultConfig {
        // Python 3.14 — matches the build machine's installed version
        version = "3.14"

        pip {
            // Pin yt-dlp version for build reproducibility
            install("yt-dlp==2026.3.17")
        }

        // Extract yt-dlp packages to filesystem so all imports work
        extractPackages("yt_dlp")
    }
}

flutter {
    source = "../.."
}
