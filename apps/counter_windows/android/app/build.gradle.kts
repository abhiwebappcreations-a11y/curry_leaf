plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.hinopt.counter_windows"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.hinopt.counter_windows"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            ndk {
                debugSymbolLevel = "none"
            }
            signingConfig = signingConfigs.getByName("debug")
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

tasks.matching { 
    it.name.contains("FlutterBuild") || 
    it.name.contains("mergeReleaseNativeLibs")
}.configureEach {
    doNotTrackState("Avoid OneDrive file conflict")
}

tasks.matching { 
    it.name.contains("NativeDebugMetadata") ||
    it.name.contains("NativeSymbol")
}.configureEach {
    enabled = false
}
