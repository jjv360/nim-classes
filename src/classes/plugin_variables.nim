##
## This plugin gathers variable definitions from the class body

{.used.}

import std/macros
import std/tables
import std/sequtils
import ./internal
import ./utils


## Compile time variable info
type Variable* = ref object of RootRef

    ## Variable (nnkIdentDefs)
    definition* : NimNode

    ## Comment (nnkCommentStmt)
    comment* : NimNode


## Clone a var definition
proc clone*(this : Variable) : Variable =

    # Copy everything
    let copy = Variable()
    copy.definition = copyNimTree(this.definition)
    copy.comment = copyNimTree(this.comment)
    
    # Done
    return copy


## Compile time variable info
type Variables* = ref object of RootRef

    ## Variables
    definitions* : seq[Variable]


## Get variables for a class
proc vars*(this : ClassDescription) : Variables =
    
    # Get or create them
    if not this.metadata.contains("vars"): this.metadata["vars"] = Variables()
    return (Variables) this.metadata["vars"]


## Attempts to identify the type of a nnkIdentDefs node if it doesn't exist already
proc autodetectVarType(identDef : NimNode) =

    # Get name
    var nameDef = identDef.variableName

    # Get type, stop if already exists
    var typeNode : NimNode = identDef[1]
    if typeNode.kind != nnkEmpty:
        return

    # Get value, fail if that doesn't exist either
    let valueNode = identDef[2]
    if valueNode.kind == nnkEmpty:
        error("The class variable '" & $nameDef & "' doesn't have a type.", identDef)

    # If they haven't specified a type, but they have specified a literal value, use that value's type
    if valueNode.kind == nnkCharLit: typeNode = ident"char"
    elif valueNode.kind == nnkIntLit: typeNode = ident"int"
    elif valueNode.kind == nnkInt8Lit: typeNode = ident"int8"
    elif valueNode.kind == nnkInt16Lit: typeNode = ident"int16"
    elif valueNode.kind == nnkInt32Lit: typeNode = ident"int32"
    elif valueNode.kind == nnkInt64Lit: typeNode = ident"int64"
    elif valueNode.kind == nnkUIntLit: typeNode = ident"uint"
    elif valueNode.kind == nnkUInt8Lit: typeNode = ident"uint8"
    elif valueNode.kind == nnkUInt16Lit: typeNode = ident"uint16"
    elif valueNode.kind == nnkUInt32Lit: typeNode = ident"uint32"
    elif valueNode.kind == nnkUInt64Lit: typeNode = ident"uint64"
    elif valueNode.kind == nnkFloatLit: typeNode = ident"float"
    elif valueNode.kind == nnkFloat32Lit: typeNode = ident"float32"
    elif valueNode.kind == nnkFloat64Lit: typeNode = ident"float64"
    elif valueNode.kind == nnkFloat128Lit: typeNode = ident"float128"
    elif valueNode.kind == nnkStrLit: typeNode = ident"string"
    elif valueNode.kind == nnkSym and $valueNode == "false": typeNode = ident"bool"
    elif valueNode.kind == nnkSym and $valueNode == "true": typeNode = ident"bool"
    elif valueNode.kind == nnkIdent and $valueNode == "false": typeNode = ident"bool"
    elif valueNode.kind == nnkIdent and $valueNode == "true": typeNode = ident"bool"
    else: error("The class variable '" & $nameDef & "' doesn't have a type.", identDef)

    # Get type from value if we still don't know the type
    # TODO: Nim can autodetect the type from the value definition, but can't seem to do it programmatically...
    # if typeNode.kind == nnkEmpty:
    #     echo identDef.treeRepr
    #     typeNode = getTypeInst(newVarStmt(nameDef, valueNode))
    #     if typeNode == nil or typeNode.kind == nnkEmpty:
    #         error("The class variable '" & $nameDef & "' doesn't have a type.", identDef)

    # Store the detected type
    identDef[1] = typeNode



## Gather variables from the class body
proc gatherDefinitions(classDef : ClassDescription) =

    # Gather variable definitions
    var previousComment : NimNode = nil
    traverseClassStatementList classDef.originalBody, proc(idx: int, parent: NimNode, node: NimNode) =

        # Check node type
        if node.kind == nnkLetSection or node.kind == nnkConstSection:

            # If they used a "let" instead of a "var", stop right here
            # TODO: Support constants in the class definition? Maybe translate them into getters?
            error("Variables must be defined with 'var'.", node)

        elif node.kind == nnkVarSection:

            # Store the variable definitions individually
            for identDef in node:

                # Store it and try to autodetect the type if it's not specified already
                let copyIdent = identDef.copyNimTree()
                autodetectVarType(copyIdent)
                classDef.vars.definitions.add(Variable(definition: copyIdent, comment: previousComment))
                previousComment = nil

        elif node.kind == nnkCommentStmt:

            # Store comment
            previousComment = node

        else:

            # Some other node type, skip it
            previousComment = nil


## Generate type definitions in the output code
proc generateOutput1(classDef : ClassDescription) =

    # Set a new RecList on the class object
    let recList = newNimNode(nnkRecList)
    classDef.outputObject[0][2][0][2] = recList

    # Go through each variable
    for variable in classDef.vars.definitions:

        # Add it's comment if there is one
        # TODO: Nim doesn't support comments on object vars in the RecList? "illformed AST"
        # if variable.comment != nil:
        #     recList.add(variable.comment)

        # Skip if already defined in the superclass
        if classDef.superClass.vars.definitions.anyIt($it.definition.variableName == $variable.definition.variableName):
            continue

        # Store it in the recList and ensure it doesn't have a preset value
        let varCopy = copyNimTree(variable.definition)
        varCopy[2] = newEmptyNode()
        recList.add(varCopy)



## Log class info
proc debugEcho(classDef : ClassDescription) =

    # Output all variables
    for variable in classDef.vars.definitions:

        # Get type
        let typeDef = variable.definition[1]

        # Output it
        echo "- Variable: " & $variable.definition.variableName & " : " & typeDef.repr


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGatherDefinitions: gatherDefinitions(classDef)
        if stage == ClassCompilerGenerateOutput1: generateOutput1(classDef)
        if stage == ClassCompilerDebugEcho: debugEcho(classDef)
    )

