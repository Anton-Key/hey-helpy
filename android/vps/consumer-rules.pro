# Шаг 28: VPS-сборка. NSDK приносит свои правила (proguard.txt в AAR).
# Filament / SceneView / ARCore зовут классы из нативного кода — не трогать.
-keep class com.google.android.filament.** { *; }
-keep class io.github.sceneview.** { *; }
-keep class com.google.ar.core.** { *; }
-dontwarn com.google.android.filament.**
-dontwarn io.github.sceneview.**
