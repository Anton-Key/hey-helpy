pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")

// Шаг 31: «AR-метки» (ARCore на телефоне, без чужих серверов) — в основной
// сборке; arcommon — общее с VPS-экспериментом (PoseMath, REST, таблички).
include(":arcommon")
include(":arlabel")

// Шаг 28: VPS-эксперимент (Niantic Spatial NSDK) — отдельный модуль, только
// в сборке с -PwithVps=true. Основной APK его не содержит и собирается как раньше.
if (providers.gradleProperty("withVps").orNull == "true") {
    include(":vps")
}
