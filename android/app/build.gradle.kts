// build.gradle.kts (android/app/build.gradle.kts)

import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Function to read properties from local.properties file
fun getLocalProperty(key: String, project: org.gradle.api.Project): String {
    val properties = Properties()
    val localPropertiesFile = project.rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        properties.load(FileInputStream(localPropertiesFile))
        // CHANGED: Added '?: ""' to handle cases where the property is null.
        // This prevents the "must not be null" crash.
        return properties.getProperty(key) ?: ""
    }
    return ""
}

android {
    namespace = "com.example.hilmi"
    compileSdk = 36

    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

      externalNativeBuild {
        cmake {
            // Arahkan ke file CMakeLists.txt Anda
            path = file("src/main/cpp/CMakeLists.txt")
            version = "4.0.3"
        }
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.hear_me"
        minSdk = 24
        // These lines will now fail gracefully if a property is missing
        targetSdk = getLocalProperty("flutter.targetSdkVersion", project).toIntOrNull() ?: 35
        versionCode = getLocalProperty("flutter.versionCode", project).toIntOrNull() ?: 1
        versionName = getLocalProperty("flutter.versionName", project).takeIf { it.isNotEmpty() } ?: "1.0"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    // MediaPipe Vision
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
    implementation("com.microsoft.cognitiveservices.speech:client-sdk:1.38.0")
}
