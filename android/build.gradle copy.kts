// ─── 1) Top of file: correct Kotlin plugin version ────────────────────────
buildscript {
  // Kotlin plugin must be 1.x, NOT 2.x!
  val kotlinVersion by extra("1.8.21")
  repositories {
    google()
    mavenCentral()
  }
  dependencies {
    classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
  }
}

// ─── 2) Imports (must come after buildscript) ────────────────────────────
import com.android.build.gradle.BaseExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.gradle.jvm.toolchain.JavaLanguageVersion

// ─── 3) Usual allprojects, newBuildDir, clean, etc. ──────────────────────
allprojects {
  repositories {
    google()
    mavenCentral()
  }
}

val newBuildDir: Directory =
  rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

tasks.register<Delete>("clean") {
  delete(rootProject.layout.buildDirectory)
}

subprojects {
  // If this project has an Android extension, bump it to 1.8
  extensions.findByType(BaseExtension::class.java)?.apply {
    compileOptions {
      sourceCompatibility = JavaVersion.VERSION_1_8
      targetCompatibility = JavaVersion.VERSION_1_8
    }
  }

  // Force all JavaCompile tasks to 1.8
  tasks.withType(JavaCompile::class.java).configureEach {
    sourceCompatibility = JavaVersion.VERSION_1_8.toString()
    targetCompatibility = JavaVersion.VERSION_1_8.toString()
  }

  // Force all KotlinCompile tasks to jvmTarget=1.8
  tasks.withType(KotlinCompile::class.java).configureEach {
    kotlinOptions {
      jvmTarget = "1.8"
    }
  }
}