##---------------Begin: proguard configuration for Gson & flutter_local_notifications  ----------
# Gson uses generic type information stored in a class file when working with fields.
# ProGuard/R8 removes such information by default, so configure it to keep all of it.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Prevent R8 from stripping/obfuscating TypeToken generic type arguments
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken { *; }

# Keep Gson runtime & adapters intact
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-dontwarn sun.misc.**

# Keep all flutter_local_notifications models, receivers, and RuntimeTypeAdapterFactory subtypes
# (NotificationDetails, StyleInformation subtypes, ScheduleMode, etc.)
-keep class com.dexterous.** { *; }
##---------------End: proguard configuration for Gson & flutter_local_notifications  ------------
