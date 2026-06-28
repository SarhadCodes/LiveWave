buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Fix for plugins missing namespaces or having old manifest package attributes
subprojects {
    if (project.name == "better_player" || project.name == "ota_update") {
        project.afterEvaluate {
            try {
                val android = project.extensions.findByName("android")
                if (android != null) {
                    val setNamespace = android.javaClass.getMethod("setNamespace", String::class.java)
                    // Note: ota_update uses 'otaupdate' without the dot in its internal manifest
                    val namespace = if (project.name == "better_player") "com.jhomlala.better_player" else "sk.fourq.otaupdate"
                    setNamespace.invoke(android, namespace)
                }
            } catch (e: Exception) {
                println("Failed to set namespace for ${project.name}: $e")
            }
        }
    }
}

// Special task to strip the "package" attribute from library manifests (Required for Gradle 8+)
subprojects {
    afterEvaluate {
        val pluginName = name
        if (pluginName == "ota_update") {
            tasks.matching { it.name.contains("process") && it.name.contains("Manifest") }.configureEach {
                doFirst {
                    val manifestFile = file("src/main/AndroidManifest.xml")
                    if (manifestFile.exists()) {
                        val content = manifestFile.readText()
                        if (content.contains("package=")) {
                            println("Cleaning up manifest for $pluginName...")
                            val newContent = content.replace(Regex("package=\"[^\"]*\""), "")
                            manifestFile.writeText(newContent)
                        }
                    }
                }
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
