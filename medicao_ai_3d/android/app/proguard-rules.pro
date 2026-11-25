# Optional ML Kit script packages not bundled (Latin script is used on-device)
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep OpenCV, ARCore, and native platform channel classes
-keep class org.opencv.** { *; }
-keep class com.google.ar.core.** { *; }
-keep class br.com.medicaoai3d.medicao_ai_3d.** { *; }
