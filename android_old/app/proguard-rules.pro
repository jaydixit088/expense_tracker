# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.api.** { *; }

# Firestore
-keep class com.google.cloud.firestore.** { *; }
-keep class com.google.cloud.datastore.** { *; }
-keep class io.grpc.** { *; }

# Auth
-keep class com.google.firebase.auth.** { *; }

# Misc
-dontwarn io.grpc.**
-dontwarn com.google.api.**
-dontwarn com.google.cloud.**
-dontwarn com.google.firebase.**
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**
