// Шаг 31: общее для AR-экранов — «AR-метки» (android/arlabel, основной APK) и
// VPS-эксперимент (android/vps, только -PwithVps=true): математика поз и
// проекции, REST Supabase с JWT пользователя, тексты и таблички поверх камеры.
// Без ARCore и сторонних библиотек — только Android SDK.
plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.example.hey_helpy.arcommon"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
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
    testImplementation("junit:junit:4.13.2")
    // org.json в Android есть, а в JVM-тестах — только заглушка.
    testImplementation("org.json:json:20240303")
}
