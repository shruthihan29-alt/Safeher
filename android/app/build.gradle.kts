plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")

    // 🔥 Required for Firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.safeher"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.safeher"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    // Kotlin stdlib
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")

    // 🔥 Firebase BOM (manages all Firebase versions automatically)
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))

    // Firestore (for unsafe areas, etc.)
    implementation("com.google.firebase:firebase-firestore")

    // Analytics (optional, but useful)
    implementation("com.google.firebase:firebase-analytics")
}
