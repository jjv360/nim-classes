##
## Class info types

import std/macros
import std/tables
import std/strutils

## Pragma to specify a class method as a static function
template static* {.pragma.}

## Compile time class info
type ClassDescription* = ref object of RootRef

    ## The name of the macro which generated this class
    macroName* : string

    ## Original class head (nnkIdent or nnkInfix)
    originalHead* : NimNode

    ## Original class body (nnkStmtList)
    originalBody* : NimNode

    ## Class name (nnkIdent)
    name* : NimNode

    # Class comment (nnkCommentStmt)
    comment* : NimNode

    ## Parent class name (nnkIdent)
    superClass* : ClassDescription

    ## Extra properties used by plugins
    metadata* : Table[string, RootRef]

    ## Code to output before the class type definition (nnkStmtList)
    outputPrefix* : NimNode

    ## Code to generate the object definition
    outputObject* : NimNode

    ## Forward declarations (nnkStmtList)
    outputForwardDeclarations* : NimNode

    ## Actual methods (nnkStmtList)
    outputBody* : NimNode

    ## Code to output after the class type definition (nnkStmtList)
    outputSuffix* : NimNode


## Class compiler stages
type ClassCompilerStage* = enum

    ## Called before processing begins
    ClassCompilerPreload

    ## Called to gather definitions from the class body
    ClassCompilerGatherDefinitions

    ## Called after we've collected the class definition, this step allows plugins to add extra methods and vars
    ClassCompilerAddExtraDefinitions

    ## Called to allow plugins to modify the class before the output is generated
    ClassCompilerModifyDefinitions

    ## Called to allow plugins to generate the code output in stages
    ClassCompilerGenerateCode

    ## Called after code has been generated
    ClassCompilerFinalize

    ## If class debugging is on, this allows plugins to add echo output
    ClassCompilerDebugEcho


## A class modifier plugin. This is a function which is called during multiple stages, and allows code to modify
## the class creation process.
type ClassCompilerPlugin* = proc(stage : ClassCompilerStage, classDef : ClassDescription)

## List of all class compiler plugins
var classCompilerPlugins* {.compileTime.} : seq[ClassCompilerPlugin] = @[]

## List of class definitions already compiled
var classCompilerCache* {.compileTime.} : seq[ClassDescription] = @[]

## Get the bound symbol for a class, or return nil if not bound yet. Returns an nnkSym node, or nil if class is unbound.
proc boundSym*(this : ClassDescription) : NimNode =

    # Once the macro has run and a class has been output, the `outputObject` NimNode will contain the class
    # object definition used by Nim. Nim will then transform nnkIdent's to nnkSym nodes, which represent an
    # actual object in code and not just an identifier. We can then use this nnkSym node to identify an
    # object even if there are multiple objects with the same name.
    if this.outputObject.kind == nnkTypeSection and this.outputObject[0].kind == nnkTypeDef and this.outputObject[0][0].kind == nnkSym:
        return this.outputObject[0][0]

    # Check if the class has not been bound to a symbol yet
    if this.outputObject.kind == nnkTypeSection and this.outputObject[0].kind == nnkTypeDef and this.outputObject[0][0].kind == nnkIdent:
        return nil

    # Invalid format!
    error("Unable to get class symbol for '" & $this.name & "'", this.name)


## Find an existing class definition, or null if it doesn't exist
proc classDefinitionFor*(name : NimNode) : ClassDescription =

    # We're expecting a nnkIdent or nnkSym here
    if name.kind != nnkIdent and name.kind != nnkSym:
        error("Expected an identifier.", name)

    # Find it
    # TODO: This comparison is not right, it can detect two unrelated classes with the same name as being the same ... at least we can error out if this happens though
    var foundDefinition : ClassDescription = nil
    for classDef in classCompilerCache:
        if $classDef.name == $name:
            if foundDefinition != nil: error("Multiple class defintions found for " & $name, name)
            foundDefinition = classDef

    # Done
    return foundDefinition

## Create an empty class definition for RootRef
proc emptyClassDescription*(name : NimNode) : ClassDescription =
    let desc = ClassDescription()
    desc.macroName = "class"
    desc.name = name
    return desc


## Create a class description for the specified block of code
proc newClassDescription*(macroName : string, head : NimNode, body : NimNode) : ClassDescription =

    # Create new class definition
    let classDef = ClassDescription()
    classDef.macroName = macroName
    classDef.originalHead = head
    classDef.originalBody = body
    classDef.outputPrefix = newNimNode(nnkStmtList)
    classDef.outputForwardDeclarations = newNimNode(nnkStmtList)
    classDef.outputBody = newNimNode(nnkStmtList)
    classDef.outputSuffix = newNimNode(nnkStmtList)

    # Get class name and parent
    if head.kind == nnkIdent:

        # Format is: class MyClass
        classDef.name = head
        classDef.superClass = emptyClassDescription(ident"RootRef")

    elif head.kind == nnkInfix:

        # Format is: class MyClass of BaseClass
        # Do safety checks
        if $head[0] != "of": error("Unknown operator, expected 'of'", head[0])
        if head[1].kind != nnkIdent: error("Invalid class name", head[1])
        if head[2].kind != nnkIdent: error("Invalid base class name", head[2])
        classDef.name = head[1]
        classDef.superClass = classDefinitionFor(head[2])
        if classDef.superClass == nil:
            warning("Unable to find class definition for '" & $head[2] & "'.")
            classDef.superClass = emptyClassDescription(head[2])

    else:

        # Invalid class syntax
        error("Invalid class syntax.", head)
        return nil

    # Call plugin stages
    for plugin in classCompilerPlugins: plugin(ClassCompilerPreload, classDef)
    for plugin in classCompilerPlugins: plugin(ClassCompilerGatherDefinitions, classDef)
    for plugin in classCompilerPlugins: plugin(ClassCompilerAddExtraDefinitions, classDef)
    for plugin in classCompilerPlugins: plugin(ClassCompilerModifyDefinitions, classDef)

    # Create class object definition header
    let className = classDef.name
    let parentName = classDef.superClass.name
    classDef.outputObject = quote do:
        type `className`* = ref object of `parentName`

    # Call plugin stages
    for plugin in classCompilerPlugins: plugin(ClassCompilerGenerateCode, classDef)
    for plugin in classCompilerPlugins: plugin(ClassCompilerFinalize, classDef)

    # Done
    return classDef


## Get code for a class definition (nnkStmtList)
proc compile*(this : ClassDescription) : NimNode =

    # Store this class definition
    classCompilerCache.add(this)

    # Generate code
    var code = newStmtList()
    code.add(this.outputPrefix)
    code.add(this.outputObject)
    code.add(this.outputForwardDeclarations)
    code.add(this.outputBody)
    code.add(this.outputSuffix)

    # Show debug info if requested
    const debugclasses {.strdefine.} = ""
    let debugClassNames = debugclasses.split(",")
    if debugclasses == "true" or debugClassNames.contains($this.name):
        echo "\n=== Created " & this.macroName & " " & $this.name & " of " & $this.superClass.name
        for plugin in classCompilerPlugins: plugin(ClassCompilerDebugEcho, this)
        echo ""
        echo code.repr
        echo ""

    # Done
    return code