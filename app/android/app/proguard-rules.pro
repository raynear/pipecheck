-keepclassmembers class * {
    @androidx.annotation.Keep <methods>;
}
-dontwarn j$.util.concurrent.**
-dontwarn j$.util.**
-dontwarn javax.annotation.**
-dontwarn kotlin.**
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry
-dontwarn org.xml.sax.helpers.XMLReaderFactory
-dontwarn org.w3c.dom.**
-dontwarn android.window.**
-dontwarn androidx.window.**
# Guava(전이 의존)가 참조하는 컴파일타임 전용 j2objc 애노테이션 — 런타임에 없어
# release R8 minify가 "Missing class"로 실패한다. AGP 생성 규칙 그대로 억제.
-dontwarn com.google.j2objc.annotations.**
-keep class javax.** { *; }
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-keep class org.w3c.dom.bootstrap.DOMImplementationRegistry { *; }
-keep class org.xml.sax.helpers.XMLReaderFactory { *; }
-keep class org.w3c.dom.** { *; }
-keep class android.window.** { *; }
-keep class androidx.window.** { *; }
