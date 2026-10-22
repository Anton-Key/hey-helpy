// Шаг 31: «AR-метки» — V0 своей технологии позиционирования. В основной сборке.
// ARCore работает на телефоне: Cloud Anchors, Geospatial и другие сетевые
// режимы выключены; на сервер уходит только кадр — в нашу Edge Function
// photo-identify. См. docs/research/ar-own-positioning.md.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.hey_helpy.arlabel"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        consumerProguardFiles("consumer-rules.pro")
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation(project(":arcommon"))
    // Тот же ARCore, что у VPS-эксперимента (шаг 28). Без SceneView / Filament:
    // камеру рисуем сами (GLES 2), таблички — обычные View.
    implementation("com.google.ar:core:1.47.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.json:json:20240303")
}
