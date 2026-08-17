# Keep WorkManager classes to prevent issues with reflection
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**

# Keep Room database and its implementations (used by WorkManager)
-keep class * extends androidx.room.RoomDatabase
-keep class androidx.room.** { *; }
-dontwarn androidx.room.**
