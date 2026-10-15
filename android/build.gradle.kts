// Шаг 28: репозиторий NSDK (официальный, на GitHub) — только для VPS-сборки.
val withVps = providers.gradleProperty("withVps").orNull == "true"

allprojects {
    repositories {
        google()
        mavenCentral()
        if (withVps) {
            maven {
                url = uri("https://raw.githubusercontent.com/nianticspatial/nsdk-library-aar/main")
                content { includeGroup("com.nianticspatial") }
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
