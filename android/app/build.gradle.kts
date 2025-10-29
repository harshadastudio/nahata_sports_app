//plugins {
//    id("com.android.application")
//    id("kotlin-android")
//    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
//    id("dev.flutter.flutter-gradle-plugin")
////     id("com.google.gms.google-services")
//}
//
//android {
////     namespace = "com.example.nahata_app"
////    namespace = "com.example.nahata_app"
//    namespace = "com.nahata_sports_app"
//    compileSdk = flutter.compileSdkVersion
//    ndkVersion = flutter.ndkVersion
//
//
//    compileOptions {
//        sourceCompatibility = JavaVersion.VERSION_11
//        targetCompatibility = JavaVersion.VERSION_11
//    }
//
//    kotlinOptions {
//        jvmTarget = JavaVersion.VERSION_11.toString()
//    }
//
////    defaultConfig {
////        applicationId= "com.nahata_sports_app"
//////        applicationId = "com.example.nahata_app"
////        minSdk = flutter.minSdkVersion
////        targetSdk = flutter.targetSdkVersion
////        versionCode = 15   // increment this number every release (1, 2, 3...)
////        versionName = "1.0.15"
////    }
//
//    defaultConfig {
//        applicationId = "com.nahata_sports_app"
//        minSdk = flutter.minSdkVersion
//        targetSdk = flutter.targetSdkVersion
//        versionCode = 15   // increment this number every release (1, 2, 3...)
//        versionName = "1.0.15"
//    }
//
//
//
//    signingConfigs {
//        create("release") {
//            keyAlias = project.findProperty("MY_KEY_ALIAS") as String
//            keyPassword = project.findProperty("MY_KEY_PASSWORD") as String
//            storeFile = file("my-key.jks")
//            storePassword = project.findProperty("MY_KEYSTORE_PASSWORD") as String
//        }
//    }
//
//    buildTypes {
//        getByName("release") {
//            isMinifyEnabled = true
//            isShrinkResources = true
//            proguardFiles(
//                getDefaultProguardFile("proguard-android-optimize.txt"),
//                "proguard-rules.pro"
//            )
//            signingConfig = signingConfigs.getByName("release")
//        }
//
//        getByName("debug") {
//
//            signingConfig = signingConfigs.getByName("release")
//        }
//    }
//}
//
//dependencies {
//    implementation("com.razorpay:checkout:1.6.33")
//    implementation("com.google.android.gms:play-services-wallet:19.2.0")
////    implementation("com.google.android.gms:play-services-auth:20.7.0")
////    implementation(platform("com.google.firebase:firebase-bom:34.2.0"))
////    implementation("com.google.firebase:firebase-analytics")
//}
//
//flutter {
//    source = "../.."
//}
//
//
//
//
//
//
//
//
//
//
////    buildTypes {
////        release {
////            // TODO: Add your own signing config for the release build.
////            // Signing with the debug keys for now, so `flutter run --release` works.
////        signingConfig = signingConfigs.getByName("debug")
//////            signingConfig signingConfigs.release
//////                    minifyEnabled true
//////            shrinkResources false
//////            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
////        }
////    }
////    buildTypes {
////        getByName("release") {
////            isMinifyEnabled = true
////            isShrinkResources = true
////            proguardFiles(
////                getDefaultProguardFile("proguard-android-optimize.txt"),
////                "proguard-rules.pro"
////            )
////        }
////    }
//
//




//Harshada
 plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle plugin must be applied after Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
     id("com.google.gms.google-services")
    // id("com.google.gms.google-services") // Uncomment if using Firebase services
}

android {
    namespace = "com.nahata_sports_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true

    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.nahata_sports_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 16
        versionName = "1.0.16"
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
            // Optional: Use debug signing config (default debug key)
            // Remove this block or set signingConfig to debug if needed
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

//dependencies {
//    implementation("com.razorpay:checkout:1.6.33")
//    implementation("com.google.android.gms:play-services-wallet:19.2.0")
//    // implementation("com.google.android.gms:play-services-auth:20.7.0")
//    // implementation(platform("com.google.firebase:firebase-bom:34.2.0"))
//    // implementation("com.google.firebase:firebase-analytics")
//    implementation "androidx.core:core-ktx:1.12.0"
//    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.3'
//}
dependencies {
    implementation("com.razorpay:checkout:1.6.33")
    implementation("com.google.android.gms:play-services-wallet:19.2.0")
    implementation("androidx.core:core-ktx:1.12.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
flutter {
    source = "../.."
}