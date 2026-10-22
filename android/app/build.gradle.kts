plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Шаг 28: VPS-эксперимент — только с -PwithVps=true (см. docs/research/vps-niantic.md).
// Без флага подключается пустая заглушка VpsHook, модуль :vps не собирается.
val withVps = providers.gradleProperty("withVps").orNull == "true"

android {
    namespace = "com.example.hey_helpy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.hey_helpy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        if (withVps) {
            // Ставится рядом с основным приложением.
            applicationIdSuffix = ".vps"
        }
    }

    sourceSets.getByName("main").java.srcDir(if (withVps) "src/vps/kotlin" else "src/novps/kotlin")

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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

dependencies {
    // Шаг 31: «AR-метки» — экран ArLabelActivity и канал hey_helpy/arlabel.
    implementation(project(":arlabel"))
    if (withVps) {
        implementation(project(":vps"))
    }
}
