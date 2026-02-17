# 1. Flutter 엔진 및 플러그인 핵심 보호
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# 2. Image Picker 및 Pigeon 통신로 절대 보호 (이게 핵심!)
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class * extends dev.flutter.pigeon.** { *; }

# 3. AndroidX 및 사진 선택기 관련 API 보호
-keep class androidx.activity.result.** { *; }
-keep class androidx.core.app.** { *; }
-keep class androidx.fragment.app.** { *; }

# 4. 리플렉션 및 통신 관련 속성 유지
-keepattributes Signature,Exceptions,InnerClasses,EnclosingMethod,AnnotationDefault,*Annotation*

# 5. 구글 플레이 코어 경고 무시
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.plugins.imagepicker.**