# Шаг 31: ARCore зовёт свои классы из нативного кода — не трогать.
-keep class com.google.ar.core.** { *; }
-dontwarn com.google.ar.core.**
