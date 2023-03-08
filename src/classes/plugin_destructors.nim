##
## This plugin adds support for the deinit() function.

{.used.}

import std/macros
import ./internal
import ./plugin_methods


## Generate the destructor proc
proc generateDestructor(classDef : ClassDescription) =

    # Stop if there's no deinit() anywhere in the chain
    let m = Method()
    m.definition = quote do:
        method deinit()
    if not m.existsIn(classDef):
        return

    # It exists, add destroy method
    let thisName = ident"this"
    let methodName = parseExpr("`=destroy`")
    let className = classDef.name
    classDef.outputBody.insert(0, quote do:
        proc `methodName`*(`thisName`: var typeof(`className`()[])) =
            `thisName`.deinit()
    )
    


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGenerateCode: generateDestructor(classDef)
    )

