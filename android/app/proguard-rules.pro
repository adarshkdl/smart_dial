# Smart Dial R8 rules.
# Activities, services and receivers are referenced from the manifest and kept automatically.
# Keep the app package so crash stack traces stay readable (the app is small).
-keep class com.example.smart_dial.** { *; }

# Flutter references Play Core (deferred components) optionally; we don't use it.
-dontwarn com.google.android.play.core.**
