##
## This plugin adds metaprogramming features to classes, such as the className() property.

{.used.}

import std/macros
import ./internal
import ./plugin_methods
import ./plugin_variables

## Add extra functions to classes
proc addExtras(classDef : ClassDescription) =

    # Create a function called className() which returns the name of the class
    var methodDef = Method()
    let funcName = ident"className"
    let output = $classDef.name
    methodDef.definition = quote do: 
        method `funcName`(): string
    methodDef.body = quote do: 
        return `output`
    classDef.methods.definitions.add(methodDef)


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGatherDefinitions: addExtras(classDef)
    )

