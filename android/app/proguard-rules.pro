# Room 2.2.5 creates WorkDatabase_Impl by reflection; full-mode R8 removes
# its constructor even though the library keeps the class name.
-keepclassmembers class * extends androidx.room.RoomDatabase {
    public <init>();
}
