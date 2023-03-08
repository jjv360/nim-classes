##
## This plugin manages class constructors

{.used.}

import std/macros
import std/tables
import ./internal
import ./plugin_methods
import ./plugin_variables
import ./utils


## Insert autogenerated init functions
proc insertAutogeneratedInits(classDef : ClassDescription) =

    # Check if this class already has an init()
    var hasInit = false
    for methodDef in classDef.methods.definitions:
        if $methodDef.definition.name == "init":
            hasInit = true
            break

    # Insert new autogenerated init() if no init method exists
    if not hasInit:

        # Create blank init method
        var methodDef = Method()
        methodDef.definition = quote do:
            method init()
        methodDef.body = newStmtList()

        # If the superclass has a generic init, make sure to call it
        var parentHasDefaultInit = false
        for m in classDef.superClass.methods.definitions:
            if $m.definition.name == "init" and m.definition.params.len == 1:   # <-- First hidden param is the return type
                parentHasDefaultInit = true
                break

        # If parent has default init, call it in our init body
        if parentHasDefaultInit:
            methodDef.body = newStmtList(quote do:
                super.init()
            )

        # Add it
        classDef.methods.definitions.add(methodDef)



## Automatically insert code to set var values in all init() methods
proc setupVarsInInit(classDef : ClassDescription) =

    # Create code to set up vars
    var initCode = newStmtList()
    for varDef in classDef.vars.definitions:

        # Skip if var has no value
        let valueNode = varDef.definition[2]
        if valueNode.kind == nnkEmpty:
            continue

        # Get name
        var nameDef = varDef.definition.variableName

        # Add the code
        initCode.add(quote do:
            this.`nameDef` = `valueNode`
        )

    # Go through each function
    for methodDef in classDef.methods.definitions:

        # Stop if not an init function
        if $methodDef.definition.name != "init":
            continue

        # Stop if we shouldn't modify this one
        if methodDef.isStatic or methodDef.insertUnmodified:
            continue

        # Set the return type to our class
        methodDef.definition.params[0] = classDef.name

        # Return 'this' at the end
        methodDef.body.add(quote do:
            return this    
        )

        # Stop if no superclass init code
        if initCode.len == 0:
            continue

        # Find the index of the super call within the method body
        var superIdx = -1
        for i, node in methodDef.body:
            if node.kind == nnkCall and node[0].kind == nnkDotExpr and node[0][0].kind == nnkIdent and $node[0][0] == "super" and node[0][1].kind == nnkIdent and $node[0][1] == "init":
                superIdx = i+1
                break

        # Enforce the use of super.init() within the initializer
        # TODO: This needs work, for now just insert it at the top if not found
        if superIdx == -1:
            superIdx = 0#error("You must call super.init() from within your initializer.", methodDef.definition)

        # Inject the init code after the super call
        methodDef.body.insert(superIdx, initCode)


## Generate the extra init methods
proc generateExtraInits(classDef : ClassDescription) =

    # Go through each function
    var newItems : seq[Method] = @[]
    for methodDef in classDef.methods.definitions:

        # Stop if not an init function
        if $methodDef.definition.name != "init":
            continue

        # Generate a static init function which just forwards to this one .. format is `ClassName.init()`
        let underscore = ident"_"
        let className = classDef.name
        let init1name = ident"init"
        let init1 = Method()
        init1.insertUnmodified = true
        init1.definition = quote do:
            proc `init1name`*(`underscore` : typedesc[`className`]): `className`
        init1.body = quote do:
            let o = `className`()
            discard o.init()
            return o

        # Add params from the initializer to this wrapper function and to the function it calls
        traverseParams(methodDef.definition, proc(idx : int, nameNode : NimNode, typeNode : NimNode, identDef : NimNode, identDefIdx : int) =
            init1.definition.params.add(newIdentDefs(nameNode, typeNode, newEmptyNode()))
            init1.body[1][0].add(nameNode)
        )

        # Store it
        newItems.add(init1)


        # Generate a static init function which just forwards to this one .. format is `newClassName()`
        let init2name = ident("new" & $classDef.name)
        let init2 = Method()
        init2.insertUnmodified = true
        init2.definition = quote do:
            proc `init2name`*(): `className`
        init2.body = quote do:
            let o = `className`()
            discard o.init()
            return o

        # Add params from the initializer to this wrapper function and to the function it calls
        traverseParams(methodDef.definition, proc(idx : int, nameNode : NimNode, typeNode : NimNode, identDef : NimNode, identDefIdx : int) =
            init2.definition.params.add(newIdentDefs(nameNode, typeNode, newEmptyNode()))
            init2.body[1][0].add(nameNode)
        )

        # Store it
        newItems.add(init2)



        # Generate a static init function which just forwards to this one .. format is `ClassName.new()`
        let init3name = ident("new")
        let init3 = Method()
        init3.insertUnmodified = true
        init3.definition = quote do:
            proc `init3name`*(`underscore` : typedesc[`className`]): `className`
        init3.body = quote do:
            let o = `className`()
            discard o.init()
            return o

        # Add params from the initializer to this wrapper function and to the function it calls
        traverseParams(methodDef.definition, proc(idx : int, nameNode : NimNode, typeNode : NimNode, identDef : NimNode, identDefIdx : int) =
            init3.definition.params.add(newIdentDefs(nameNode, typeNode, newEmptyNode()))
            init3.body[1][0].add(nameNode)
        )

        # Output it
        newItems.add(init3)

    # Add new methods
    for m in newItems:
        classDef.methods.definitions.add(m)


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerAddExtraDefinitions: insertAutogeneratedInits(classDef)
        if stage == ClassCompilerAddExtraDefinitions: generateExtraInits(classDef)
        if stage == ClassCompilerModifyDefinitions: setupVarsInInit(classDef)
    )

