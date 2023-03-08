##
## This plugin manages class constructors

{.used.}

import std/macros
import ./internal
import ./plugin_methods
import ./plugin_variables


## Export all methods and variables
proc exportAll(classDef : ClassDescription) =

    # Go through all vars
    for varDef in classDef.vars.definitions:

        # Stop if already exported
        if varDef.definition[0].kind == nnkPostfix:
            continue

        # Export this var
        let nameNode = varDef.definition[0]
        varDef.definition[0] = newNimNode(nnkPostfix, nameNode)
        varDef.definition[0].add(ident"*")
        varDef.definition[0].add(nameNode)


    # Go through all methods
    for methodDef in classDef.methods.definitions:

        # Stop if already exported
        if methodDef.definition[0].kind == nnkPostfix:
            continue

        # Export this method
        let nameNode = methodDef.definition[0]
        methodDef.definition[0] = newNimNode(nnkPostfix, nameNode)
        methodDef.definition[0].add(ident"*")
        methodDef.definition[0].add(nameNode)


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerModifyDefinition4: exportAll(classDef)
    )

