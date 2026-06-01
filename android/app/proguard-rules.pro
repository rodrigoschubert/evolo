# ============================================================
# DISABLE BYTECODE OPTIMIZATIONS
# proguard-android-optimize.txt é obrigatório no AGP moderno,
# mas suas otimizações de bytecode quebram o registro de plugins
# Flutter via reflection. Esta flag desativa APENAS as
# otimizações, mantendo minificação e shrinking ativos.
# ============================================================
-dontoptimize

# ============================================================
# FLUTTER ENGINE — Base obrigatória
# ============================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Plugin registrant gerado automaticamente — NUNCA remover
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

# Mantém TODOS os plugins Flutter (qualquer FlutterPlugin subclass)
-keep class * extends io.flutter.embedding.engine.plugins.FlutterPlugin { *; }
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class * implements io.flutter.plugin.common.EventChannel$StreamHandler { *; }

# ============================================================
# PIGEON — Framework de geração de API nativa do Flutter
# Cobre TODAS as versões de plugins que usam Pigeon
# ============================================================
-keep class dev.flutter.pigeon.** { *; }
-keepclassmembers class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }

# ============================================================
# SHARED PREFERENCES (v2+ usa Pigeon internamente)
# ============================================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keepclassmembers class io.flutter.plugins.sharedpreferences.** { *; }
-dontwarn io.flutter.plugins.sharedpreferences.**

# ============================================================
# POSTHOG — Usa Class.forName() (reflection), manter tudo
# ============================================================
-keep class com.posthog.** { *; }
-keepclassmembers class com.posthog.** {
    public *;
    protected *;
    <init>(...);
}
-keep interface com.posthog.** { *; }
-dontwarn com.posthog.**

# ============================================================
# FFMPEG KIT
# ============================================================
-keep class com.arthenica.ffmpegkit.** { *; }
-keepclassmembers class com.arthenica.ffmpegkit.** { *; }
-dontwarn com.arthenica.ffmpegkit.**
-keep class com.antonkarpenko.ffmpegkit.** { *; }
-keepclassmembers class com.antonkarpenko.ffmpegkit.** { *; }
-dontwarn com.antonkarpenko.ffmpegkit.**

# ============================================================
# IN-APP PURCHASE (Google Play Billing)
# ============================================================
-keep class com.android.billingclient.** { *; }
-keepclassmembers class com.android.billingclient.** { *; }
-dontwarn com.android.billingclient.**
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# ============================================================
# SENTRY
# ============================================================
-keep class io.sentry.** { *; }
-keepclassmembers class io.sentry.** { *; }
-dontwarn io.sentry.**

# ============================================================
# SUPABASE / KTOR (usa reflection para serialização)
# ============================================================
-keep class io.github.jan.supabase.** { *; }
-dontwarn io.github.jan.supabase.**
-keep class io.ktor.** { *; }
-keepclassmembers class io.ktor.** { *; }
-dontwarn io.ktor.**
# Kotlinx Serialization — essencial para Supabase
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keep,includedescriptorclasses class com.rsfsoftware.evolo.**$$serializer { *; }
-keepclassmembers class com.rsfsoftware.evolo.** {
    *** Companion;
}
-keepclasseswithmembers class com.rsfsoftware.evolo.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# ============================================================
# CAMERA PLUGIN
# ============================================================
-keep class io.flutter.plugins.camera.** { *; }
-keepclassmembers class io.flutter.plugins.camera.** { *; }

# ============================================================
# PERMISSION HANDLER
# ============================================================
-keep class com.baseflow.permissionhandler.** { *; }
-keepclassmembers class com.baseflow.permissionhandler.** { *; }

# ============================================================
# PATH PROVIDER
# ============================================================
-keep class io.flutter.plugins.pathprovider.** { *; }

# ============================================================
# SHARE PLUS
# ============================================================
-keep class dev.fluttercommunity.plus.share.** { *; }

# ============================================================
# SQFLITE
# ============================================================
-keep class com.tekartik.sqflite.** { *; }

# ============================================================
# REFLECTION — Manter atributos essenciais para libs com reflection
# ============================================================
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ============================================================
# KOTLIN COROUTINES (usadas por Supabase, Sentry, PostHog)
# ============================================================
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# ============================================================
# ANDROID STANDARD
# ============================================================
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
