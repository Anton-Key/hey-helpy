// Шаг 28: VPS-эксперимент Niantic Spatial NSDK 4 (VPS2). Подключается только
// в сборке с -PwithVps=true (android/settings.gradle.kts). См. docs/research/vps-niantic.md.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

// Developer token Niantic — ТОЛЬКО из секрета GitHub NIANTIC_DEV_TOKEN (переменная
// окружения при сборке). В репозиторий и в логи не попадает; пустой — экран скажет
// «Токен VPS не задан». ⚠️ Токен внутри APK можно извлечь — для демо допустимо
// (до 90 дней, отзывается в портале), для продакшна — выдача токенов сервером.
val nianticToken: String = (System.getenv("NIANTIC_DEV_TOKEN") ?: "")
    .trim()
    .filter { it.isLetterOrDigit() || it in "-_.=" }

android {
    namespace = "com.example.hey_helpy.vps"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
        buildConfigField("String", "NIANTIC_TOKEN", "\"$nianticToken\"")
        buildConfigField("String", "NSDK_VERSION", "\"4.1.0-26051913\"")
        consumerProguardFiles("consumer-rules.pro")
    }

    buildFeatures {
        buildConfig = true
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
    // NSDK — официальный AAR с github.com/nianticspatial/nsdk-library-aar
    // (Maven-раскладка, репозиторий подключён в android/build.gradle.kts).
    // У AAR нет списка зависимостей в POM — их перечисляем сами (как в kotlin-samples).
    implementation("com.nianticspatial:nsdk:4.1.0-26051913")
    implementation("com.google.ar:core:1.47.0")
    implementation("io.github.sceneview:arsceneview:2.3.1")
    implementation("com.google.android.gms:play-services-location:21.3.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.9.0")
    implementation("androidx.activity:activity-ktx:1.10.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.9.4")

    testImplementation("junit:junit:4.13.2")
}
