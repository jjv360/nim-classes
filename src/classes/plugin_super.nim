##
## This plugin allows for calling functions on the superclass

{.used.}

import std/macros
import std/tables
import ./internal
import ./plugin_methods
import ./plugin_variables

# Replacement function for super. Returns true if a super call exists in the code.
proc replaceSuper*(item: var NimNode, superInsertedState : int = 0): bool =

    # Check if it's a match
    if item.kind == nnkCall and item[0].kind == nnkDotExpr and item[0][0].kind == nnkIdent and $item[0][0] == "super":

        # Found a match, modify the NimNode to use procCall
        item = newTree(nnkCommand,
            bindSym("procCall"),
            copyNimTree(item)
        )

        # If calling super.init(), discard the result
        if $item[1][0][1] == "init":

            # Discard the result
            item = newStmtList(
                newTree(nnkDiscardStmt, item)
            )

        # Done
        return true

    # Not found, try the children
    var didInsert = false
    for i, child in item:

        # Modify child
        var child2 = child
        if replaceSuper(child2, superInsertedState):
            didInsert = true
        item[i] = child2

    # Done
    return didInsert


## Replace all super calls
proc replaceSuperCalls(classDef : ClassDescription) =

    # Get or create method metadata
    if not classDef.metadata.contains("methods"): classDef.metadata["methods"] = Methods()
    let methods = (Methods) classDef.metadata["methods"]

    # Go through all methods
    for methodDef in methods.definitions:

        # Skip for static methods
        if methodDef.isStatic or methodDef.insertUnmodified:
            continue

        # Modify all super calls and add "procCall" to them
        var methodBody = methodDef.body
        let didInsert = replaceSuper(methodBody)
        methodDef.body = methodBody

        # If super was used, inject the 'super' variable, which is just this class cast to the base class type
        if didInsert:
            let hasInitialComment = methodDef.body[0].kind == nnkCommentStmt
            let sname = ident"super"
            let baseName = classDef.superClass.name
            methodDef.body.insert(if hasInitialComment: 1 else: 0, quote do: 
                let `sname` : `baseName` = cast[`baseName`](this)
            )


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerModifyDefinitions: replaceSuperCalls(classDef)
    )

