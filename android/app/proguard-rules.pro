# Fixes a release-build-only crash found while preparing Play Store
# screenshots: R8 was stripping/renaming pieces of WorkManager's
# Room-generated database (pulled in transitively by a plugin, not used
# directly by this app's own code), causing every release APK to crash
# on launch with:
#   java.lang.RuntimeException: Failed to create an instance of
#   androidx.work.impl.WorkDatabase
# Debug and profile builds never showed this — R8 only runs for release.
-keep class androidx.work.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-dontwarn androidx.work.**
