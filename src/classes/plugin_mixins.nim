##
## This plugin adds support for mixins. Mixins allow copying the variable and method definitions from a "template" to the class which uses it.

{.used.}

import std/macros
import std/tables
import ./internal
import ./plugin_methods
import ./plugin_variables
import ./utils


## Compile time mixin info
type Mixins* = ref object of RootRef

    ## All mixins for this class
    all* : seq[ClassDescription]


## Get mixins for a class
proc mixins*(this : ClassDescription) : Mixins =
    
    # Get or create them
    if not this.metadata.contains("mixins"): this.metadata["mixins"] = Mixins()
    return (Mixins) this.metadata["mixins"]
    


## Gather mixins
proc gatherMixins(classDef : ClassDescription) =

    # Gather mixins
    traverseClassStatementList classDef.originalBody, proc(idx: int, parent: NimNode, node: NimNode) =

        # We're only processing mixins here
        if node.kind != nnkMixinStmt:
            return

        # We have a mixin statement! Get the class definition
        let mixingClassIdent = node[0]
        let mixingClass = classDefinitionFor(mixingClassIdent)
        if mixingClass == nil: 
            error("The mixin '" & $mixingClassIdent & "' was not found.", node)

        # Add it
        classDef.mixins.all.add(mixingClass)


## Inject a mixin into the class
proc injectMixin(classDef : ClassDescription, mixinDef : ClassDescription) =

    # Copy all methods
    for methodDef in mixinDef.methods.definitions: 

        # Skip meta stuff
        if $methodDef.definition.name == "init": continue
        if $methodDef.definition.name == "className": continue

        # Make a new copy of this method
        let methodCopy = methodDef.clone()

        # Replace the "this" argument type
        if methodCopy.isStatic:

            # Inject typedesc as the first param on static methods
            let classTypedesc = newNimNode(nnkBracketExpr)
            classTypedesc.add(ident"typedesc")
            classTypedesc.add(classDef.name)
            methodCopy.definition.params[1] = newIdentDefs(ident"_", classTypedesc)

        else:

            # Inject the `this` parameter as the first argument
            methodCopy.definition.params[1] = newIdentDefs(ident"this", classDef.name)

        # If the method returns the mixin class, make it return this class instead
        if methodCopy.definition.params[0].kind == nnkIdent and $methodCopy.definition.params[0] == $mixinDef.name:
            methodCopy.definition.params[0] = classDef.name

        # Add it
        classDef.methods.definitions.add(methodCopy)

    # Copy all variables
    for varDef in mixinDef.vars.definitions:

        # Add it
        classDef.vars.definitions.add(varDef.clone())

    # If the mixin has a parent class, inject those too
    if mixinDef.superClass != nil:
        injectMixin(classDef, mixinDef.superClass)


## Inject vars and methods from the mixins
proc injectMixins(classDef : ClassDescription) =

    # Go through each mixin
    for mixinDef in classDef.mixins.all:

        # inject each class's mixins, up the superclass chain recursively
        injectMixin(classDef, mixinDef)


## Log class info
proc debugEcho(classDef : ClassDescription) =

    # Output all mixins
    for mixinDef in classDef.mixins.all:
        echo "- Mixin: " & $mixinDef.name


## Register the plugin at compile-time
static:
    classCompilerPlugins.add(proc(stage : ClassCompilerStage, classDef : ClassDescription) =
        if stage == ClassCompilerGatherDefinitions: gatherMixins(classDef)
        if stage == ClassCompilerModifyDefinition1: injectMixins(classDef)
        if stage == ClassCompilerDebugEcho: debugEcho(classDef)
    )

