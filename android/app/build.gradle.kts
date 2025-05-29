plugins {
    id 'com.android.application'
    id 'kotlin-android'
    id 'dev.flutter.flutter-gradle-plugin'
    
    // Add the Google services Gradle plugin
    id 'com.google.gms.google-services'
}

// Remove Kotlin version override
// ext.kotlin_version = '2.0.0' 

android {
    namespace "com.zediasolutions.zediatask"
    compileSdkVersion flutter.compileSdkVersion
    ndkVersion "27.0.12077973"

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_11
        targetCompatibility JavaVersion.VERSION_11
        // Enable core library desugaring
        coreLibraryDesugaringEnabled true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Add signing config
    signingConfigs {
        release {
            keyAlias 'zediatask'
            keyPassword System.getenv('KEY_PASSWORD') ?: 'android'
            storeFile file('../zediatask.keystore')
            storePassword System.getenv('STORE_PASSWORD') ?: 'android'
        }
    }

    defaultConfig {
        applicationId "com.zediasolutions.zediatask"
        minSdkVersion 23
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutter.versionCode
        versionName flutter.versionName
        
        // Add this to disable native code builds
        externalNativeBuild {
            cmake {
                arguments "-DANDROID_STL=c++_shared"
            }
        }
    }

    // Disable C++ builds
    packagingOptions {
        doNotStrip '**/*.so'
        // Exclude the META-INF files from conflicting libraries
        exclude 'META-INF/DEPENDENCIES'
        exclude 'META-INF/LICENSE'
        exclude 'META-INF/LICENSE.txt'
        exclude 'META-INF/license.txt'
        exclude 'META-INF/NOTICE'
        exclude 'META-INF/NOTICE.txt'
        exclude 'META-INF/notice.txt'
        exclude 'META-INF/ASL2.0'
    }

    buildTypes {
        release {
            // Update to use the release signing config
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}

// Make sure the repositories include Google's maven repository
repositories {
    google()
    mavenCentral()
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'
    
    // Use a fixed version of Firebase dependencies compatible with Kotlin 1.8
    implementation 'com.google.firebase:firebase-core:21.1.1'
    implementation 'com.google.firebase:firebase-analytics:21.5.0'
    implementation 'com.google.firebase:firebase-messaging:23.4.1'
    
    // Use newer Play libraries that are compatible with Android 14
    implementation 'com.google.android.play:app-update:2.1.0'
    implementation 'com.google.android.play:feature-delivery:2.1.0'
}

flutter {
    source '../..'
} 

