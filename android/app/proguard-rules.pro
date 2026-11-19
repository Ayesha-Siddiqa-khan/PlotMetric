# ML Kit discovers and constructs its registrars by name at startup.
-keep class com.google.mlkit.** implements com.google.firebase.components.ComponentRegistrar {
    <init>();
}
