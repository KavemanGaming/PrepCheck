
# Keep Play Core / SplitCompat when minifyEnabled is true
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

# Keep Flutter deferred components manager references
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**
