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
    var sharedInstanceVarName = ident("__sharedInstance_" & $classDef.name)
    var methodDef = Method()
    let className = classDef.name
    methodDef.definition = quote do: 
        method shared*() : `className`
    methodDef.body = quote do: 
        if `sharedInstanceVarName` == nil: `sharedInstanceVarName` = `className`.init()
        return `sharedInstanceVarName`
    methodDef.isStatic = true
    classDef.methods.definitions.add(methodDef)

## Inject the shared variable into the class body
proc injectSharedVar(classDef : ClassDescription) =

    # Stop if not a singleton
    if classDef.macroName != "singleton":
        return

    # Add the code before the method bodies
    var sharedInstanceVarName = ident("__sharedInstance_" & $classDef.name)
    var className = classDef.name
    classDef.outputForwardDeclarations.add(quote do:
        var `sharedInstanceVarName` : `className` = nil
    )


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGatherDefinitions: injectSharedAccessor(classDef)
        if stage == ClassCompilerGenerateCode: injectSharedVar(classDef)
    )

