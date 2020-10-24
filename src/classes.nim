##
## This file adds support for classes to Nim.

import macros
import tables
import sequtils

## DEBUG: Print out the AST for some code
# macro printast(head: untyped, body: untyped): untyped = echo body.treeRepr
# printast tst:
#     var myString = ""
#     var myManualString: string = ""
#     var myNullString: string
#     var 
#         exposedString* = "hi"
#         another = "2"
#         third = @[]

#     type MyObj = object
#         var1: string

## Specify a class method as a static function
template static* {.pragma.}

## Specify that a variable should not be defined in the class. This is useful if you're subclassing a Nim-style class and trying to set a class variable.
template noDefine* {.pragma.}


## Compile time class info
type ClassInfo = ref object of RootObj
    classIdent: NimNode
    parentIdent: NimNode
    varIdents: seq[NimNode]
    methodIdents: seq[NimNode]

var allClasses {.compileTime.}: seq[ClassInfo] = @[
    ClassInfo(classIdent: ident("RootObj"))
]

## Class definition
macro class*(head: untyped, body: untyped): untyped =

    # Show debug info?
    const showDebugInfo = defined(debugclasses)
    const thisVarName = "this"

    # Create new statement list
    if showDebugInfo: echo "\n\n========= Defining a class =========="
    result = newStmtList()

    # Check what format was used
    var className: NimNode
    var baseName: NimNode
    if head.kind == nnkIdent:

        # Format is: class MyClass
        className = head
        baseName = ident"RootObj"

    if head.kind == nnkInfix:

        # Format is: class MyClass of BaseClass
        # Do safety checks
        if $head[0] != "of": raiseAssert("Unknown operator " & $head[0])
        if head[1].kind != nnkIdent: raiseAssert("Invalid class name: " & $head[1])
        if head[2].kind != nnkIdent: raiseAssert("Invalid base class name: " & $head[2])
        className = head[1]
        baseName = head[2]
    
    # We now have the class name and base class name
    if showDebugInfo: echo "Class name: " & $className
    if showDebugInfo: echo "Base class: " & $baseName

    # Prevent unused warnings
    # result.add(quote do:
    #     {. hints: off.}
    # )

    # Create type section
    result.add(quote do:
        type `className`* = ref object of `baseName`
    )

    # Create RecList, which is where we'll create class vars
    let recList = newTree(nnkRecList)
    result.last()[0][2][0][2] = recList

    # Store initial values for class vars
    var initialValues: Table[string, NimNode]
    let classInfo = ClassInfo()
    classInfo.classIdent = className
    allClasses.add(classInfo)

    # Find parent class info, if any
    var parentClassInfo: ClassInfo = nil
    for inf in allClasses:
        if eqIdent(inf.classIdent, baseName):
            parentClassInfo = inf
            break

    # Warn if not found
    if parentClassInfo == nil:

        # Create a placeholder
        warning("The object '" & $baseName & "' is not a class. Your mileage may vary.", baseName)
        parentClassInfo = ClassInfo()
        parentClassInfo.classIdent = baseName
        allClasses.add(parentClassInfo)

    # Copy idents from the parent
    classInfo.varIdents.add(parentClassInfo.varIdents)
    classInfo.methodIdents.add(parentClassInfo.methodIdents)

    # Gather all variable definitions
    for node in body:

        # If they used a "let" instead of a "var", stop right here
        if node.kind == nnkLetSection: error("Variables must be defined with 'var'.", node)

        # We only care about variable definitions right now
        if node.kind != nnkVarSection: continue
        
        # Copy the IdentDefs for this var section into this object
        for identDef in node:

            # Get variable name
            var nameNode = identDef[0]
            var typeNode = identDef[1]
            var valueNode = identDef[2]

            # Check if it has a pragma
            var pragmaNode = newTree(nnkPragmaExpr)
            if nameNode.kind == nnkPragmaExpr:
                pragmaNode = nameNode[1]
                nameNode = nameNode[0]

            # Try autodetect the type if not specified
            if typeNode.kind == nnkEmpty:
            
                # Fail if there's no value either
                # if valueNode.kind == nnkEmpty:
                #     error("The class variable '" & $nameNode & "' doesn't have a type.", identDef)

                # If they haven't specified a type, but they have specified a literal value, use that value's type
                # TODO: typeNode needs to contain the variable's type as an Ident. Surely there's a function 
                # somewhere to get the the correct type from valueNode, which specifies the intial value? 
                if valueNode.kind == nnkCharLit: typeNode = ident"char"
                if valueNode.kind == nnkIntLit: typeNode = ident"int"
                if valueNode.kind == nnkInt8Lit: typeNode = ident"int8"
                if valueNode.kind == nnkInt16Lit: typeNode = ident"int16"
                if valueNode.kind == nnkInt32Lit: typeNode = ident"int32"
                if valueNode.kind == nnkInt64Lit: typeNode = ident"int64"
                if valueNode.kind == nnkUIntLit: typeNode = ident"uint"
                if valueNode.kind == nnkUInt8Lit: typeNode = ident"uint8"
                if valueNode.kind == nnkUInt16Lit: typeNode = ident"uint16"
                if valueNode.kind == nnkUInt32Lit: typeNode = ident"uint32"
                if valueNode.kind == nnkUInt64Lit: typeNode = ident"uint64"
                if valueNode.kind == nnkFloatLit: typeNode = ident"float"
                if valueNode.kind == nnkFloat32Lit: typeNode = ident"float32"
                if valueNode.kind == nnkFloat64Lit: typeNode = ident"float64"
                if valueNode.kind == nnkFloat128Lit: typeNode = ident"float128"
                if valueNode.kind == nnkStrLit: typeNode = ident"string"

                # If they haven't specified a type, but they have created an object, use that type
                # This doesn't work, it would take the function itself as the type
                # if valueNode.kind == nnkIdent: typeNode = valueNode
                # if valueNode.kind == nnkCall and valueNode[0].kind == nnkIdent: typeNode = valueNode[0]
            
                # Fail if we could not determine the variable's type ... or just use auto? auto causes issues though
                if typeNode.kind == nnkEmpty:
                    # typeNode = ident"auto"
                    error("No type specified for '" & $nameNode & "'.", identDef)

            # Extract initial value, if set
            var initialValueInfo = ""
            if valueNode.kind != nnkEmpty:
                initialValueInfo = valueNode.lispRepr
                initialValues[$nameNode] = valueNode

            # Skip if this variable has been defined on the base class already
            if classInfo.varIdents.anyIt(it == nameNode):
                if showDebugInfo: echo "Skipping class var '" & $nameNode & "' because it was already defined on a superclass."
                continue

            # Check if they don't want us to define it
            var dontDefine = false
            for i, p in pragmaNode:
                if p.kind == nnkIdent and $p == "noDefine":
                    dontDefine = true
                    break

            # Debug info
            if showDebugInfo: echo (if dontDefine: "Skipping define of" else: "Adding") & " class var: name=" & $nameNode & " type=" & typeNode.repr & " value=" & initialValueInfo

            # Add this variable to the object definition, without the value
            if not dontDefine: recList.add(nnkIdentDefs.newTree(
                newTree(nnkPostfix, ident"*", nameNode), 
                typeNode, 
                newEmptyNode()
            ))
            classInfo.varIdents.add(nameNode)

    # Check if a constructor was given
    var hasGotInit = false
    for node in body:
        if node.kind == nnkMethodDef and $node.name == "init":
            hasGotInit = true
            break

    # Check if the parent class has a constructor
    var hasParentGotInit = false
    for node in parentClassInfo.methodIdents:
        if $node == "init":
            hasParentGotInit = true
            break

    # Add empty constructor if no constructor was given
    if not hasGotInit:

        # Warning, we don't yet support automatic mapping to the parent's init methods!
        if hasParentGotInit: warning("Class '" & $className & "' has no init() method, but '" & $baseName & "' does.")

        # Create default constructor
        # TODO: We should just call all the super class's init methods, passing the variables on
        if showDebugInfo: echo "Adding autogenerated constructor since there was no init() defined"
        let initNode = quote do:
            method init*() = discard

        body.add(initNode)

            


    # Add forward declarations, so that the order of the methods doesn't matter
    for node in body:

        # We only care about method definitions right now
        if node.kind != nnkMethodDef: continue

        # Make a copy with no body, since this is going to be a forward declaration
        var methodNode = copyNimTree(node)
        methodNode.body = newEmptyNode()

        # Check if it's static ... would have been nice to use hasCustomPragma() here?
        var isStatic = false
        for i, p in methodNode.pragma:
            if p.kind == nnkIdent and $p == "static":
                isStatic = true
                break

        # Check if static
        if isStatic:

            # Inject unused typedesc placeholder as the first param
            let underscore = ident"_"
            let vv = quote do:
                proc a(`underscore`: typedesc[`className`])

            methodNode.params.insert(1, vv.params[1])

        else:

            # Inject "this" as the first param
            methodNode.params.insert(1, newIdentDefs(ident(thisVarName), className))

        # If this is the constructor, set the return type to the class
        if $methodNode.name == "init":

            # Set return type
            methodNode.params[0] = className

        # Check if this is the base method
        # if not classInfo.methodIdents.anyIt(it == methodNode.name):

        #     # Add base pragma
        #     if methodNode.pragma.kind == nnkEmpty: methodNode.pragma = newTree(nnkPragma)
        #     methodNode.pragma.add(newNimNode(nnkPragma).add(ident"base"))

        # Make sure it's exported
        if methodNode[0].kind == nnkIdent:
            methodNode[0] = newTree(nnkPostfix, ident"*", methodNode[0])

        # Add it
        if showDebugInfo: echo "Adding declaration for " & (if isStatic: "static " else: "") & "method: name=" & $methodNode.name & " args=" & $(methodNode.params.len()-2)
        result.add(methodNode)


    # Replacement function for super
    proc replaceSuper(item: var NimNode) =

        # Check if it's a match
        if item.kind == nnkCall and item[0].kind == nnkDotExpr and item[0][0].kind == nnkIdent and $item[0][0] == "super":

            # Found a match, modify the NimNode to use procCall
            item = newTree(nnkCommand,
                bindSym("procCall"),
                copyNimTree(item)
            )

            # If calling super.init(), discard the result
            if $item[1][0][1] == "init":
                item = newTree(nnkDiscardStmt, item)

            # Done
            return

        # Not found, try the children
        for i, child in item:

            # Modify child
            var child2 = child
            replaceSuper(child2)
            item[i] = child2


    # Add real methods
    for node in body:

        # We only care about method definitions right now
        if node.kind != nnkMethodDef: continue

        # Get method + body
        var methodNode = copyNimTree(node)

        # If this is an init method, add a newClass wrapper function for it
        if $methodNode.name == "init":

            # Create wrapper function
            let funcName = ident("new" & $className)
            var newFunc = quote do: 
                template `funcName`(): untyped {.used.} = `className`().init()

            # For each param, add it
            for i, param in methodNode.params:

                # Ignore first one
                if i == 0:
                    continue

                # Add to template's param list
                let varName = "v" & $i
                newFunc.params.add(newIdentDefs(ident(varName), bindSym"untyped", newEmptyNode()))

                # Add to template's function call
                newFunc[6][0].add(ident(varName))

            # Done, add it
            result.add(newFunc)

        # If this is an init method, add a Class.init() wrapper function for it. 
        # NOTE: We can use this for static methods!
        if $methodNode.name == "init":

            # Create wrapper function
            let initName = ident"init"
            var newFunc = quote do: 
                template `initName`(_: typedesc[`className`]): untyped {.used.} = `className`().init()

            # For each param, add it
            for i, param in methodNode.params:

                # Ignore first one
                if i == 0:
                    continue

                # Add to template's param list
                let varName = "v" & $i
                newFunc.params.add(newIdentDefs(ident(varName), bindSym"untyped", newEmptyNode()))

                # Add to template's function call
                newFunc[6][0].add(ident(varName))

            # Done, add it
            result.add(newFunc)

        # Check if it's static ... would have been nice to use hasCustomPragma() here?
        var isStatic = false
        for i, p in methodNode.pragma:
            if p.kind == nnkIdent and $p == "static":
                isStatic = true
                break

        # Check if static
        if isStatic:

            # Inject unused typedesc placeholder as the first param
            let underscore = ident"_"
            let vv = quote do:
                proc a(`underscore`: typedesc[`className`])

            methodNode.params.insert(1, vv.params[1])

        else:

            # Inject "this" as the first param
            methodNode.params.insert(1, newIdentDefs(ident(thisVarName), className))

        # If this is the constructor, set the return type to the class
        if $methodNode.name == "init":

            # Set return type
            methodNode.params[0] = className

            # Return 'this' at the end
            methodNode.body.add(quote do:
                return this    
            )

        # If this is an abstract function, it will have no body. Add in a simple body which just throws an error if called.
        if methodNode.body.kind == nnkEmpty:
            let mName = $methodNode.name
            methodNode.body = newStmtList(
                quote do: raiseAssert("Method " & `mName` & "() is abstract, it must be implemented in a subclass.")
            )

        # Inject the 'super' variable, which is just this class cast to the base class type ... but not for static functions
        if not isStatic:
            let sname = ident"super"
            methodNode.body.insert(0, quote do: 
                let `sname`: `baseName` = cast[`baseName`](this)
                if super == super: discard # <-- HACK: I can't get rid of the "unused" warning ...
            )

        # If this is an init function, set variable default values
        if $methodNode.name == "init":

            # Go through each variable that has a default value
            if showDebugInfo: echo "Injecting initial var values into init() method, count = ", $initialValues.len()
            for name, value in initialValues:

                # Add code
                let varIdent = ident(name)
                methodNode.body.insert(1, quote do:
                    this.`varIdent` = `value`
                )

        # Modify all super calls and add "procCall" to them
        var methodBody = methodNode.body
        replaceSuper(methodBody)
        methodNode.body = methodBody

        # Check if this is the base method
        # if not classInfo.methodIdents.anyIt(it == methodNode.name):

        #     # Add base pragma
        #     if methodNode.pragma.kind == nnkEmpty: methodNode.pragma = newTree(nnkPragma)
        #     methodNode.pragma.add(newNimNode(nnkPragma).add(ident"base"))



        # Add it
        if showDebugInfo: echo "Adding implementation for " & (if isStatic: "static " else: "") & "method: name=" & $methodNode.name & " args=" & $(methodNode.params.len()-2)
        result.add(methodNode)
        classInfo.methodIdents.add(methodNode.name)

    # Export class
    result.add(quote do:
        export `className`
    )

    # Export all functions
    for m in classInfo.methodIdents:
        result.add(quote do:
            export `m`
        )

    # Done, restore compiler warnings we temporarily disabled
    # result.add(quote do:
    #     {. pop.}
    # )



## Support for empty class definition
macro class*(head: untyped): untyped = quote do: class `head`: discard