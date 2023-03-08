##
## This plugin adds support for singleton classes

{.used.}

import std/macros
import std/tables
import ./internal
import ./plugin_methods
import ./plugin_variables

## Inject a shared accessor
proc injectSharedAccessor(classDef : ClassDescription) =

    # Stop if not a singleton
    if classDef.macroName != "singleton":
        return

    # Create a function called shared() which returns a single instance of this class
    var methodDef = Method()
    let className = classDef.name
    methodDef.definition = quote do: 
        method shared*() : `className`
    methodDef.body = quote do: 
        var singletonInstance {.global.} : `className` = nil
        if singletonInstance == nil: singletonInstance = `className`.init()
        return singletonInstance
    methodDef.isStatic = true
    classDef.methods.definitions.add(methodDef)


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGatherDefinitions: injectSharedAccessor(classDef)
    )

