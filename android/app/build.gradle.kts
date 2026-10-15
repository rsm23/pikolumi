import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val isolatedQa = providers.gradleProperty("pikolumiQa").orNull == "true"
val uploadProperties = Properties()
val uploadFile = rootProject.file("key.properties")
if (uploadFile.exists()) uploadProperties.load(FileInputStream(uploadFile))
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase=true) } && !uploadFile.exists()) {
    throw GradleException("Pikolumi release signing is missing. Run scripts/create_android_signing.py and securely back up the key.")
}

android {
    namespace = "com.seifelmoulouk.pikolumi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.seifelmoulouk.pikolumi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (uploadFile.exists()) {
                storeFile = file(uploadProperties.getProperty("storeFile"))
                storePassword = uploadProperties.getProperty("storePassword")
                keyAlias = uploadProperties.getProperty("keyAlias")
                keyPassword = uploadProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        debug {
            if (isolatedQa) {
                applicationIdSuffix = ".qa"
                versionNameSuffix = "-qa"
            }
        }
        release {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles("proguard-rules.pro")
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

dependencies {
    // Keep the packaged SDK aligned with the reviewed Google data disclosure.
    implementation("com.google.android.gms:play-services-ads:25.5.0")
}
