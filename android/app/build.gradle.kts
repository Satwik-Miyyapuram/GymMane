import java.util.Properties
import java.io.FileInputStream
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.gymmane.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.gymmane.app"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    if (keystorePropertiesFile.exists()) {
        // key.properties exists -> we are in a release build that should be signed.
        // Validate all required fields and fail fast with a clear message if
        // anything is missing, instead of falling back to debug signing.
        val storeFileProp = (keystoreProperties["storeFile"] as String?)?.trim()
        val storePasswordProp = (keystoreProperties["storePassword"] as String?)?.trim()
        val keyAliasProp = (keystoreProperties["keyAlias"] as String?)?.trim()
        val keyPasswordProp = (keystoreProperties["keyPassword"] as String?)?.trim()
        val missing = mutableListOf<String>()
        if (storeFileProp.isNullOrEmpty()) missing += "storeFile"
        if (storePasswordProp.isNullOrEmpty()) missing += "storePassword"
        if (keyAliasProp.isNullOrEmpty()) missing += "keyAlias"
        if (keyPasswordProp.isNullOrEmpty()) missing += "keyPassword"
        if (missing.isNotEmpty()) {
            throw GradleException("key.properties is missing required properties: ${missing.joinToString(", ")}. Check Set up signing step and ensure secrets KEYSTORE_PASSWORD, KEY_PASSWORD, KEY_ALIAS are set.")
        }
        // storeFile in key.properties is "gymmane-release.jks" and the actual
        // file is at android/app/gymmane-release.jks. rootProject is android,
        // so rootProject.file("app/<name>") locates it correctly.
        // Using file(...) alone in Kotlin DSL can resolve relative to the wrong
        // project (SigningConfig receiver ambiguity), so we try both.
        val storeFileResolved = run {
            val f1 = rootProject.file("app/$storeFileProp")
            if (f1.exists()) f1 else file(storeFileProp!!)
        }
        if (!storeFileResolved.exists()) {
            throw GradleException("Keystore file not found: $storeFileResolved (resolved from storeFile=$storeFileProp). Expected at android/app/$storeFileProp. Check that Set up signing correctly decoded KEYSTORE_BASE64.")
        }
        signingConfigs {
            create("release") {
                keyAlias = keyAliasProp!!
                keyPassword = keyPasswordProp!!
                storeFile = storeFileResolved
                storePassword = storePasswordProp!!
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                // If key.properties exists but signingConfigs.release was not created
                // due to validation above, this will throw and fail fast with the
                // message from above, rather than silently using debug.
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode = abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride = variant.versionCode * 10 + abiVersionCode
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
