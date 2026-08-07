allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugins disagree about JVM target: another_telephony pins Kotlin to 1.8,
// mobile_scanner compiles Java at 17. Any mismatch between a module's Java and
// Kotlin tasks fails the build with "Inconsistent JVM-target compatibility".
// Pin every module to 17 — the JDK in use, and what :app already targets.
//
// The JVM toolchain is the fix Gradle itself recommends for this error: it
// pins a module's Java and Kotlin compilation to one version together, instead
// of us trying to override each side and having AGP win the race.
//
// This must stay ABOVE the evaluationDependsOn(":app") block below: that call
// forces subprojects to evaluate, after which afterEvaluate throws.
subprojects {
    afterEvaluate {
        // android.compileOptions is what actually drives the JavaCompile tasks —
        // setting the tasks directly loses to AGP. Reached reflectively because
        // AGP's extension types are not reliably resolvable from this script.
        extensions.findByName("android")?.let { android ->
            // The onnxruntime plugin pins compileSdk 33, but its transitive
            // androidx dependencies require 34+. Raise every module to 36 to
            // match :app rather than pinning old androidx versions.
            runCatching {
                android.javaClass.getMethod("setCompileSdk", Integer::class.java)
                    .invoke(android, 36)
            }.recoverCatching {
                android.javaClass.getMethod("compileSdkVersion", Int::class.java)
                    .invoke(android, 36)
            }

            runCatching {
                val compileOptions = android.javaClass
                    .getMethod("getCompileOptions")
                    .invoke(android)
                compileOptions.javaClass
                    .getMethod("setSourceCompatibility", Any::class.java)
                    .invoke(compileOptions, JavaVersion.VERSION_17)
                compileOptions.javaClass
                    .getMethod("setTargetCompatibility", Any::class.java)
                    .invoke(compileOptions, JavaVersion.VERSION_17)
            }
        }

        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
