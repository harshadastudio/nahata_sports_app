plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.nahata_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.nahata_sports_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 4   // increment this number every release (1, 2, 3...)
        versionName = "1.0.4"
    }

    signingConfigs {
        create("release") {
            keyAlias = project.findProperty("MY_KEY_ALIAS") as String
            keyPassword = project.findProperty("MY_KEY_PASSWORD") as String
            storeFile = file("my-key.jks")
            storePassword = project.findProperty("MY_KEYSTORE_PASSWORD") as String
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }

        getByName("debug") {
            // Optional: You can sign debug builds with the same key, or let it use default debug key
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    implementation("com.razorpay:checkout:1.6.33")
    implementation("com.google.android.gms:play-services-wallet:19.2.0")
}

flutter {
    source = "../.."
}








//    buildTypes {
//        release {
//            // TODO: Add your own signing config for the release build.
//            // Signing with the debug keys for now, so `flutter run --release` works.
//        signingConfig = signingConfigs.getByName("debug")
////            signingConfig signingConfigs.release
////                    minifyEnabled true
////            shrinkResources false
////            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
//        }
//    }
//    buildTypes {
//        getByName("release") {
//            isMinifyEnabled = true
//            isShrinkResources = true
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
//        }
//    }


