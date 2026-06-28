# Keep Supabase and related classes from being stripped/obfuscated
-keep class com.supabase.** { *; }
-keep class io.github.jan.supabase.** { *; }
-keep class io.supabase.** { *; }
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class retrofit2.** { *; }
-keep interface retrofit2.** { *; }

# Flutter Secure Storage and other potentially problematic plugins
-keep class com.it_nomads.flutter_secure_storage.** { *; }

# Maintain attribute names for JSON parsing (used by Supabase)
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses
