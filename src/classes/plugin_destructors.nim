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

    # It exists, add destroy proc.
    # Note: The way this works is that we receive a reference to the actual underlying object, unwrapped from
    # any refs. So we need to wrap it again for the final deinit call.
    let methodName = parseExpr("`=destroy`")
    let className = classDef.name
    classDef.outputBody.insert(0, quote do:
        proc `methodName`*(thisRaw: var typeof(`className`()[])) =
            var this : `className` = cast[`className`](thisRaw.addr)
            this.deinit()
    )
    


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGenerateCode: generateDestructor(classDef)
    )

