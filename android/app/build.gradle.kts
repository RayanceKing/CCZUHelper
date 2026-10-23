plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// supabase-kt 的 auth-kt-android:3.8.0 硬依赖 androidx.browser:browser:1.10.0，
// 而 1.10.0 要求 compileSdk >= 36；本项目停留在 compileSdk 35（本机仅安装了 android-35），
// 故强制降级到 35 兼容的 1.8.0。该库仅用于 OAuth Custom Tabs，本项目只用邮箱/密码登录，无运行时影响。
configurations.all {
    resolutionStrategy {
        force("androidx.browser:browser:1.8.0")
    }
}

android {
    namespace = "com.cczu.helper"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.cczu.helper"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// AGP 9 + Kotlin 2.4：kotlinOptions DSL 已移除，改用 compilerOptions DSL 配置 JVM 目标与编译器参数
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        freeCompilerArgs.add("-Xjvm-default=all")
    }
}

dependencies {
    implementation(project(":cczukit"))

    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.7")

    val composeBom = platform("androidx.compose:compose-bom:2025.05.01")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.navigation:navigation-compose:2.8.5")
    implementation("androidx.datastore:datastore-preferences:1.1.1")

    // 茶馆（Supabase）官方 Kotlin 客户端 supabase-kt
    implementation(platform("io.github.jan-tennert.supabase:bom:3.8.0"))
    implementation("io.github.jan-tennert.supabase:auth-kt")
    implementation("io.github.jan-tennert.supabase:postgrest-kt")
    // Ktor 引擎（Android），版本需与 supabase-kt 3.8.x 匹配
    implementation("io.ktor:ktor-client-android:3.4.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")

    // 仅第三方图床（img.scdn.io）上传仍使用 OkHttp
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // CourseStore 等模块仍在使用 Gson
    implementation("com.google.code.gson:gson:2.11.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
    implementation("io.coil-kt:coil-compose:2.7.0")
}
