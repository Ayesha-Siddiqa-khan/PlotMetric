plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.plotmetric.plotmetric"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.plotmetric.plotmetric"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variantName = name
        outputs.all { output ->
            val outputImpl = output as? com.android.build.gradle.internal.api.BaseVariantOutputImpl
            outputImpl?.outputFileName = if (variantName.contains("release", ignoreCase = true)) {
                "PlotMetric.apk"
            } else {
                "PlotMetric-$variantName.apk"
            }
        }
    }
}

project.afterEvaluate {
    tasks.matching { it.name.contains("assembleRelease", ignoreCase = true) }.configureEach {
        doLast {
            val flutterApkDir = File(project.rootDir.parentFile, "build/app/outputs/flutter-apk")
            if (flutterApkDir.exists()) {
                val appRelease = File(flutterApkDir, "app-release.apk")
                val target = File(flutterApkDir, "PlotMetric.apk")
                if (appRelease.exists()) {
                    appRelease.copyTo(target, overwrite = true)
                }
            }
            val apkReleaseDir = File(project.rootDir.parentFile, "build/app/outputs/apk/release")
            if (apkReleaseDir.exists()) {
                val appRelease = File(apkReleaseDir, "app-release.apk")
                val target = File(apkReleaseDir, "PlotMetric.apk")
                if (appRelease.exists()) {
                    appRelease.copyTo(target, overwrite = true)
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
