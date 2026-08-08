plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.rakshapay.rakshapay"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.rakshapay.rakshapay"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    packaging {
        jniLibs {
            // Extract native libraries to the app's lib/ directory at install
            // time instead of loading them straight out of the APK.
            //
            // The ONNX Runtime binding opens libonnxruntime.so through Dart FFI
            // by soname. With the modern default (extractNativeLibs=false)
            // nothing is written to /data/data/<pkg>/lib/, so dlopen cannot
            // resolve it and the risk engine fails to start with
            // 'library "libonnxruntime.so" not found'. libflutter.so is
            // unaffected because the framework maps it separately, which is
            // what makes this look like an ONNX-specific fault.
            useLegacyPackaging = true
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
