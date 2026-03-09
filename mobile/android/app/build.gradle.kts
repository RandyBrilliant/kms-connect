import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties (required for release signing)
val keyPropertiesFile = rootProject.file("key.properties")
if (!keyPropertiesFile.exists()) {
    error("key.properties not found at ${keyPropertiesFile.path}. Please create it as per ANDROID_BUILD_GUIDE.md.")
}
val keyProperties = Properties().apply {
    load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.example.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // Still using jvmTarget for compatibility; can migrate to
        // compilerOptions DSL later as per Gradle/Kotlin recommendations.
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "id.kmsconnect.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val alias = keyProperties["keyAlias"]?.toString()
                ?: error("Missing 'keyAlias' in key.properties")
            val keyPass = keyProperties["keyPassword"]?.toString()
                ?: error("Missing 'keyPassword' in key.properties")
            val storePass = keyProperties["storePassword"]?.toString()
                ?: error("Missing 'storePassword' in key.properties")
            val storePath = keyProperties["storeFile"]?.toString()
                ?: error("Missing 'storeFile' in key.properties")

            keyAlias = alias
            keyPassword = keyPass
            storeFile = file(storePath)
            storePassword = storePass
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
