##
## This plugin gathers method definitions from the class body

{.used.}

import std/macros
import std/tables
import ./internal
import ./utils


## Compile time method info
type Method* = ref object of RootRef

    ## Method definition (nnkMethodDef)
    definition* : NimNode

    ## Comment (nnkCommentStmt)
    comment* : NimNode

    ## Body (nnkStmtList)
    body* : NimNode

    ## True if it's a static method
    isStatic* : bool

    ## True if the method has already been modified
    hasModified : bool


## Clone a method definition
proc clone*(this : Method) : Method =

    # Copy everything
    let methodCopy = Method()
    methodCopy.definition = copyNimTree(this.definition)
    methodCopy.body = copyNimTree(this.body)
    methodCopy.comment = copyNimTree(this.comment)
    methodCopy.hasModified = this.hasModified
    methodCopy.isStatic = this.isStatic

    # Unbind all symbols
    # echo "=== before"
    # echo methodCopy.body.treeRepr
    # unbindAllSym(methodCopy.definition)
    # unbindAllSym(methodCopy.body)
    # echo "=== after"
    # echo methodCopy.body.treeRepr

    # Convert nnkSym back to an unbound nnkIdent
    # methodCopy.definition.name = ident($methodCopy.definition.name)

    # Convert all param names back to unbound nnkIdents
    # traverseParams(methodCopy.definition, proc(idx : int, nameNode : NimNode, typeNode : NimNode, identDef : NimNode, identDefIdx : int) =
    #     echo nameNode.treeRepr
    #     if nameNode.kind == nnkSym:
    #         identDef[identDefIdx] = ident($nameNode)
    # )
    
    # Done
    return methodCopy




## Compile time method info
type Methods* = ref object of RootRef

    ## Variables
    definitions* : seq[Method]


## Get methods for a class
proc methods*(this : ClassDescription) : Methods =
    
    # Get or create them
    if not this.metadata.contains("methods"): this.metadata["methods"] = Methods()
    return (Methods) this.metadata["methods"]


## Get a method hash which can be used to compare this method in superclasses
proc hash*(this : Method) : string =

    # Add method name and all params
    var hash = $this.definition.name & "("
    var firstParamDone = false
    for i, param in this.definition.params:
        if i == 0: continue     # <-- Skip return type
        if i == 1 and ($param.variableName == "this" or $param.variableName == "_"): continue     # <-- Skip 'this'
        if firstParamDone: hash &= ","
        firstParamDone = true
        hash &= param[1].repr
    hash &= ")"

    # Add return type
    if this.definition.params[0].kind != nnkEmpty:
        hash &= ":" & this.definition.params[0].repr
    
    # Done
    return hash


## Return true if the class definition contains a matching method
proc existsIn*(this : Method, classDef : ClassDescription) : bool =

    # Compare and find hashes
    let hash = this.hash()
    for methodDef in classDef.methods.definitions:
        if hash == methodDef.hash():
            return true

    # Continue recursively
    if classDef.superClass != nil:
        return this.existsIn(classDef.superClass)

    # Not found
    return false



## Gather methods from the class body
proc gatherDefinitions(classDef : ClassDescription) =

    # Gather method definitions
    var previousComment : NimNode = nil
    traverseClassStatementList classDef.originalBody, proc(idx: int, parent: NimNode, node: NimNode) =

        # Check node type
        if node.kind == nnkMethodDef:

            # Store a copy of the definition without the body
            var methodDef = Method()
            methodDef.definition = copyNimTree(node)
            methodDef.definition.body = newEmptyNode()
            methodDef.comment = previousComment
            previousComment = nil

            # Store the body
            methodDef.body = copyNimTree(node.body)

            # Store it
            classDef.methods.definitions.add(methodDef)

            # Check if it's static ... would have been nice to use hasCustomPragma() here?
            methodDef.isStatic = false
            for i, p in methodDef.definition.pragma:
                if p.kind == nnkIdent and $p == "static":
                    methodDef.isStatic = true
                    break

            # For abstract functions that have no body, insert a body which just throws an error if called
            if methodDef.body.kind == nnkEmpty:
                let mName = $methodDef.definition.name
                let text = $classDef.name & "." & `mName` & "() is abstract, it must be implemented in a subclass."
                methodDef.body = newStmtList(
                    quote do: raiseAssert(`text`)
                )

        elif node.kind in RoutineNodes:

            # If they used a "proc" etc instead of a "method", stop right here
            error("Only 'method' routines are allowed in the class body.", node)

        elif node.kind == nnkCommentStmt:

            # Store comment
            previousComment = node

        else:

            # Some other node type, skip it
            previousComment = nil


## Insert "this" param in all methods
proc insertThisParam(classDef : ClassDescription) =

    # Go through all methods
    for methodDef in classDef.methods.definitions:

        # Stop if already modified
        if methodDef.hasModified:
            continue

        # Check if static
        if methodDef.isStatic:

            # Inject typedesc as the first param on static methods
            let classTypedesc = newNimNode(nnkBracketExpr)
            classTypedesc.add(ident"typedesc")
            classTypedesc.add(classDef.name)
            methodDef.definition.params.insert(1, newIdentDefs(ident"_", classTypedesc))

            # Make it a proc instead of a method
            let original = methodDef.definition
            let copy = newNimNode(nnkProcDef)
            copyChildrenTo(original, copy)
            methodDef.definition = copy

        else:

            # Inject the `this` parameter as the first argument
            methodDef.definition.params.insert(1, newIdentDefs(ident"this", classDef.name))

        # Done
        methodDef.hasModified = true


## Generate forward declarations for all methods
proc generateForwardDeclarations(classDef : ClassDescription) =

    # Add declaration for each method
    for methodDef in classDef.methods.definitions:

        # Make a copy of the definition
        let methodCopy = copyNimTree(methodDef.definition)

        # Mark as base method if needed, ie if not static and there's no super method
        if not methodDef.isStatic and not methodDef.existsIn(classDef.superClass):
            methodCopy.addPragma(ident"base")

        # Output it
        classDef.output.add(methodCopy)


## Generate actual definitions for all methods
proc generateMethods(classDef : ClassDescription) =

    # Add each method
    for methodDef in classDef.methods.definitions:

        # Make a copy and add the body back in
        var methodCopy = copyNimTree(methodDef.definition)
        methodCopy.body = copyNimTree(methodDef.body)

        # # Find matching method in the superclass
        # var superMethod : Method = nil
        # for superMethodDef in classDef.superClass.methods.definitions:
        #     if $superMethodDef.definition.name == $methodDef.definition.name and superMethodDef.definition.params.repr == methodDef.definition.params.repr:
        #         superMethod = superMethodDef
        #         break

        # # Mark as base method if needed, ie if not static and there's no super method
        # if not methodDef.isStatic and superMethod == nil:
        #     methodCopy.addPragma(ident"base")
        
        # Output it
        classDef.output.add(methodCopy)


## Log class info
proc debugEcho(classDef : ClassDescription) =

    # Output all methods
    for methodDef in classDef.methods.definitions:

        # Get name
        var nameDef = methodDef.definition.name

        # Output it
        echo "- Method: " & $nameDef


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGatherDefinitions: gatherDefinitions(classDef)
        if stage == ClassCompilerModifyDefinition2: insertThisParam(classDef)
        if stage == ClassCompilerGenerateOutput1: generateForwardDeclarations(classDef)
        if stage == ClassCompilerGenerateOutput3: generateMethods(classDef)
        if stage == ClassCompilerDebugEcho: debugEcho(classDef)
    )

