##
## This plugin adds support for the deinit() function.

{.used.}

import std/macros
import std/tables
import ./internal
import ./plugin_methods

## Add default deinit() if not defined
proc addDeinit(classDef : ClassDescription) =

    # Stop if a deinit() already exists in this class
    let m = Method()
    m.definition = quote do:
        method deinit()
    if m.existsIn(classDef):
        return

    # Create a function called deinit() which just calls the super definition of deinit() if it exists.
    # This ensures that all classes have a deinit() method, even if it's just a placeholder.
    var methodDef = Method()
    let funcName = ident"deinit"
    let output = $classDef.name
    methodDef.definition = quote do: 
        method `funcName`()
    if classDef.isRootClass():
        methodDef.body = quote do:
            discard
    else:
        methodDef.body = quote do: 
            super.deinit()
    classDef.methods.definitions.add(methodDef)


## Generate the destructor proc
proc generateDestructor(classDef : ClassDescription) =

    # How we handle destructors: We generate *only one* `proc =destroy(this: var ClassType)`
    # for the root class. This proc will call `this.deinit()`, which will dispatch
    # to the correct deinit method for the actual class of the object. This way, 
    # we can support destructors in subclasses without needing to generate a 
    # new `=destroy` proc for each class.

    # Add the overall `=destroy` proc to the root class
    if classDef.isRootClass():
        let methodName = parseExpr("`=destroy`")
        let className = classDef.name
        classDef.outputBody.insert(0, quote do:
            proc `methodName`*(thisRaw: typeof(`className`()[])) =
                var this : `className` = cast[`className`](thisRaw.addr)
                this.deinit()
        )
    


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerAddExtraDefinitions: addDeinit(classDef)
        if stage == ClassCompilerGenerateCode: generateDestructor(classDef)
    )
