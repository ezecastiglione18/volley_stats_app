allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (e.g. file_picker) still hardcode an older compileSdk in their
// own android/build.gradle, which fails AGP's AAR metadata check against
// newer dependencies (e.g. flutter_plugin_android_lifecycle) that require
// compileSdk 36+. Force a consistent, sufficiently high compileSdk on every
// Android library subproject to avoid depending on each plugin author
// updating their build file.
subprojects {
    afterEvaluate {
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = 36
            }
        }
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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
