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

    ## The generated method within `outputBody`
    outputCode* : NimNode

    ## True if it's a static method
    isStatic* : bool

    ## If true, we won't insert 'this' first param when the code is generated
    insertUnmodified* : bool


## Clone a method definition
proc clone*(this : Method) : Method =

    # Copy everything
    let methodCopy = Method()
    methodCopy.definition = copyNimTree(this.definition)
    methodCopy.body = copyNimTree(this.body)
    methodCopy.comment = copyNimTree(this.comment)
    methodCopy.insertUnmodified = this.insertUnmodified
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
        if firstParamDone: hash &= ","
        firstParamDone = true
        hash &= param[1].repr
    hash &= ")"

    # Add return type
    if this.definition.params[0].kind != nnkEmpty:
        hash &= ":" & this.definition.params[0].repr
    
    # Done
    return hash


## Return true if the class definition contains a matching method itself or in any of it's superclasses
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


## Generate forward declarations for all methods
proc generateCode(classDef : ClassDescription) =

    # Add declaration for each method
    for methodDef in classDef.methods.definitions:

        # Make a copy of the definition
        var methodCopy = copyNimTree(methodDef.definition)

        # Mark as base method if needed, ie if not static and there's no super method
        if not methodDef.insertUnmodified and not methodDef.isStatic and not methodDef.existsIn(classDef.superClass):
            methodCopy.addPragma(ident"base")

        # Insert 'this'
        if not methodDef.insertUnmodified and methodDef.isStatic:

            # Inject typedesc as the first param on static methods
            let classTypedesc = newNimNode(nnkBracketExpr)
            classTypedesc.add(ident"typedesc")
            classTypedesc.add(classDef.name)
            methodCopy.params.insert(1, newIdentDefs(ident"_", classTypedesc))

            # Make it a proc instead of a method
            let original = methodCopy
            let copy = newNimNode(nnkProcDef)
            copyChildrenTo(original, copy)
            methodCopy = copy

        elif not methodDef.insertUnmodified:

            # Inject the `this` parameter as the first argument
            methodCopy.params.insert(1, newIdentDefs(ident"this", classDef.name))

        # Output the forward declaration
        classDef.outputForwardDeclarations.add(methodCopy)

        # Make another copy, this time with the full body
        var methodWithBody = copyNimTree(methodCopy)
        methodWithBody.body = copyNimTree(methodDef.body)
        classDef.outputBody.add(methodWithBody)
        methodDef.outputCode = methodWithBody


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
        if stage == ClassCompilerGenerateCode: generateCode(classDef)
        if stage == ClassCompilerDebugEcho: debugEcho(classDef)
    )

