##
## This file adds support for classes to Nim.

import macros
import tables
import sequtils

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
    methodDefs: seq[NimNode]
    mixinVars: seq[NimNode]
    mixinMethods: seq[NimNode]

var allClasses {.compileTime.}: seq[ClassInfo] = @[
    ClassInfo(classIdent: ident("RootRef"))
]

## Compile time function to get class info for an ident
proc getClassInfo(classIdent: NimNode, shouldFail: bool): ClassInfo {.compileTime.} =

    # Find the class with a matching ident
    for inf in allClasses:
        if eqIdent(inf.classIdent, classIdent):
            return inf

    # Not found! Fail.
    if shouldFail:
        error("Class definition of " & $classIdent & " not found. Has this class been defined?", classIdent)
    else:
        return nil


proc createClassStructure(head: NimNode, body: NimNode, result: NimNode, isSingleton: bool) =

    # Show debug info?
    const showDebugInfo = defined(debugclasses)
    const thisVarName = "this"

    # Create new statement list
    if showDebugInfo: echo "\n\n========= Defining a class =========="

    # Check what format was used
    var className: NimNode
    var baseName: NimNode
    if head.kind == nnkIdent:

        # Format is: class MyClass
        className = head
        baseName = ident"RootRef"

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

    # Create internal className() method
    let classNameStr = $className
    body.add(quote do:
        method className(): string {.used.} = `classNameStr`
    )

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
    var parentClassInfo = getClassInfo(baseName, shouldFail = false)
    if parentClassInfo == nil:

        # Warn that parent class was not found.
        warning("Could not find definition for class '" & $baseName & "'. If this is a nim-style object, your mileage may vary.", baseName)
        parentClassInfo = ClassInfo()
        parentClassInfo.classIdent = baseName
        allClasses.add(parentClassInfo)

    # Copy idents from the parent
    classInfo.varIdents.add(parentClassInfo.varIdents)
    classInfo.methodIdents.add(parentClassInfo.methodIdents)
    classInfo.mixinVars.add(parentClassInfo.mixinVars)
    classInfo.mixinMethods.add(parentClassInfo.mixinMethods)

    # Replace all top-level 'when' blocks
    # for idx, node in body:
        
    #     # Only processing when blocks here
    #     if node.kind != nnkWhenStmt:
    #         continue

    #     echo node.treeRepr
    #     quit()

    # Gather all mixins
    for idx, node in body:

        # We're only processing mixins here
        if node.kind != nnkMixinStmt:
            continue

        # We have a mixin statement! Get the class name
        let mixingClassIdent = node[0]
        if mixingClassIdent.kind != nnkIdent:
            error("Please specify a class name to mix in.", mixingClassIdent)

        # Find the class definition. It should be in `allClasses` at this point. If not, it hasn't been defined yet.
        let mixingClassInfo = getClassInfo(mixingClassIdent, shouldFail = true)
        if showDebugInfo:
            echo "Injecting variables and methods via mixin from " & $mixingClassIdent

        # Remove this statement
        body[idx] = newCommentStmtNode("Mixin: " & $mixingClassIdent)

        # Go through mixin class vars
        for varDef in mixingClassInfo.mixinVars:

            # Inject it!
            body.add(varDef)

        # Go through mixin class methods
        for methodDef in mixingClassInfo.mixinMethods: 
            
            # Skip init methods, mixin constructors are not supported! Also skip all special class methods
            if $methodDef.name == "init" or $methodDef.name == "className":
                continue

            # Remove {.base.} pragma, since we will be reassigning them manually later and it doesn't
            # make sense for mixins anyway
            var copyDef = methodDef.copyNimTree()
            copyDef.pragma = nnkEmpty.newNimNode()
            for idx2, pragmaNode in methodDef.pragma:
                if pragmaNode.name != ident"base":
                    copyDef.addPragma(pragmaNode)

            # Inject it!
            body.add(copyDef)

    
    # In case this class is used as a mixin, make a copy of all vars and methods
    for node in body:
        if node.kind == nnkVarSection: classInfo.mixinVars.add(node.copyNimTree())
        if node.kind == nnkMethodDef: classInfo.mixinMethods.add(node.copyNimTree())
            



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
                if valueNode.kind == nnkSym and $valueNode == "false": typeNode = ident"bool"
                if valueNode.kind == nnkSym and $valueNode == "true": typeNode = ident"bool"
                if valueNode.kind == nnkIdent and $valueNode == "false": typeNode = ident"bool"
                if valueNode.kind == nnkIdent and $valueNode == "true": typeNode = ident"bool"

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


    # Add default constructors for all constructors that don't exist in the subclass but do in the parent class
    for methodNode in parentClassInfo.methodDefs:

        # Stop if not an init
        if $methodNode.name != "init":
            continue

        # Check if this method signature exists
        var didExist = false
        for node in body:
            if node.kind == nnkMethodDef and $node.name == "init" and node.params.repr == methodNode.params.repr:
                didExist = true
                break

        # Stop if exists
        if didExist:
            continue

        # It doesn't exist! We need to create an automatic constructor here to map the params
        if showDebugInfo: echo "Adding autogenerated init method to match superclass: " & methodNode.repr
        let newFunc = quote do:
            method init() {.base.} = super.init()

        # For each IdentDef, add it
        for i, identDef in methodNode.params:

            # Ignore first one which is the return value
            if i == 0:
                continue

            # For each ident inside
            let typeNode = identDef[identDef.len()-2]
            for x, paramIdent in identDef:

                # Skip last two
                if x >= identDef.len()-2:
                    continue

                # Add to template's param list
                newFunc.params.add(newIdentDefs(paramIdent, typeNode, newEmptyNode()))

                # Add to template's function call
                newFunc[6][0].add(paramIdent)

        # Done, add it
        body.add(newFunc)


    # Check if we have at least one init now
    var hasGotInit = false
    for node in body:
        if node.kind == nnkMethodDef and $node.name == "init":
            hasGotInit = true
            break

    # If not, create a blank one
    if not hasGotInit:

        # Create and add it
        if showDebugInfo: echo "Adding autogenerated constructor since there was no init() defined"
        body.add(quote do:
            method init() = discard
        )

            


    # Add forward declarations, so that the order of the methods doesn't matter
    for node in body:

        # We only care about method definitions right now
        if node.kind != nnkMethodDef: continue

        # Store this method def
        let copiedDef = copyNimTree(node)
        copiedDef.body = newEmptyNode()
        classInfo.methodDefs.add(copiedDef)

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


    # If singleton, add the shared function now
    let sharedVarName = ident("shared__" & $className)
    result.add(quote do:
        var `sharedVarName`: `className` = nil
        proc shared(_: type[`className`]): `className` =
            if `sharedVarName` == nil: `sharedVarName` = `className`.init()
            return `sharedVarName`
    )
    


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

                # Discard the result
                item = newStmtList(
                    newTree(nnkDiscardStmt, item)
                )

                # Go through each variable that has a default value and set it again. This is a bit nasty... but it ensures that calling super.init() doesn't
                # overwrite the subclass's reassigned var values
                if showDebugInfo: echo "Injecting initial var values into init() method again since super was called, count = ", $initialValues.len()
                for name, value in initialValues:

                    # Add code
                    let varIdent = ident(name)
                    item.add(quote do:
                        this.`varIdent` = `value`
                    )

            # Done
            return

        # Not found, try the children
        for i, child in item:

            # Modify child
            var child2 = child
            replaceSuper(child2)
            item[i] = child2


    # Add real methods
    for i, node in body:

        # We only care about method definitions right now
        if node.kind != nnkMethodDef: continue

        # Get method + body
        var methodNode = copyNimTree(node)

        # Check for comment directly above the method, if so copy it into the method, but only if the first entry in the method is not a comment.
        # This is to support the comment style with the comment directly above the class.
        if i > 0 and body[i-1].kind == nnkCommentStmt and methodNode.body[0].kind != nnkCommentStmt:
            methodNode.body.insert(0, body[i-1])

        # If this is an init method, add a newClass wrapper function for it
        if $methodNode.name == "init":

            # Create wrapper function
            let funcName = ident("new" & $className)
            var newFunc = quote do: 
                proc `funcName`(): untyped {.used.} = `className`().init()

            # Set return type
            newFunc[3][0] = className

            # For each IdentDef, add it
            for i, identDef in methodNode.params:

                # Ignore first one
                if i == 0:
                    continue

                # For each ident inside
                let typeNode = identDef[identDef.len()-2]
                for x, paramIdent in identDef:

                    # Skip last two
                    if x >= identDef.len()-2:
                        continue

                    # Add to template's param list
                    # let varName = "v" & $i & "_" & $x
                    newFunc.params.add(newIdentDefs(paramIdent, typeNode, newEmptyNode()))

                    # Add to template's function call
                    newFunc[6][0].add(paramIdent)

            # Done, add it
            result.add(newFunc)

        # If this is an init method, add a Class.init() wrapper function for it. 
        # NOTE: We can use this for static methods!
        if $methodNode.name == "init":

            # Create wrapper function
            let initName = ident"init"
            let underscore = ident"_"
            var newFunc = quote do: 
                proc `initName`(`underscore`: typedesc[`className`]): untyped {.used.} = `className`().init()

            # Set return type
            newFunc[3][0] = className

            # For each IdentDef, add it
            for i, identDef in methodNode.params:

                # Ignore first one
                if i == 0:
                    continue

                # For each ident inside
                let typeNode = identDef[identDef.len()-2]
                for x, paramIdent in identDef:

                    # Skip last two
                    if x >= identDef.len()-2:
                        continue

                    # Add to template's param list
                    # let varName = "v" & $i & "_" & $x
                    newFunc.params.add(newIdentDefs(paramIdent, typeNode, newEmptyNode()))

                    # Add to template's function call
                    newFunc[6][0].add(paramIdent)

            # Done, add it
            result.add(newFunc)
            # echo newFunc.repr

        # If this is an init method, add a Class.new() wrapper function for it.
        if $methodNode.name == "init":

            # Create wrapper function
            let initName = ident"new"
            let underscore = ident"_"
            var newFunc = quote do: 
                proc `initName`(`underscore`: typedesc[`className`]): untyped {.used.} = 
                    let o = `className`()
                    discard o.init()
                    return o

            # echo newFunc.treeRepr
            # quit()

            # Set return type
            newFunc[3][0] = className

            # For each IdentDef, add it
            for i, identDef in methodNode.params:

                # Ignore first one
                if i == 0:
                    continue

                # For each ident inside
                let typeNode = identDef[identDef.len()-2]
                for x, paramIdent in identDef:

                    # Skip last two
                    if x >= identDef.len()-2:
                        continue

                    # Add to template's param list
                    newFunc.params.add(newIdentDefs(paramIdent, typeNode, newEmptyNode()))

                    # Add to template's function call
                    newFunc[6][1][0].add(paramIdent)

            # Done, add it
            result.add(newFunc)
            # echo newFunc.repr
            # if $className == "DialerWindow": quit()

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
        let hasInitialComment = methodNode.body[0].kind == nnkCommentStmt
        if not isStatic:
            let sname = ident"super"
            methodNode.body.insert(if hasInitialComment: 1 else: 0, quote do: 
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
                methodNode.body.insert(if hasInitialComment: 2 else: 1, quote do:
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


        # Make sure it's exported
        if methodNode[0].kind == nnkIdent:
            methodNode[0] = newTree(nnkPostfix, ident"*", methodNode[0])

        # Add it
        if showDebugInfo: echo "Adding implementation for " & (if isStatic: "static " else: "") & "method: name=" & $methodNode.name & " args=" & $(methodNode.params.len()-2)
        result.add(methodNode)
        classInfo.methodIdents.add(methodNode.name)

    # Add {.base.} to all methods which don't have a super version
    for i, node in body:

        # We only care about method definitions right now
        if node.kind != nnkMethodDef: continue

        # Find matching function in parent class
        var superMethodDef : NimNode = nil
        for methodNode in parentClassInfo.methodDefs:
            if $methodNode.name == $node.name and methodNode.params.repr == node.params.repr:
                superMethodDef = methodNode
                break

        # Stop if found
        if superMethodDef != nil:
            continue

        # This is a base method. First check if it has the {.base.} pragma already
        var hasBasePragma = false
        for pragmaNode in node.pragma:
            if pragmaNode == ident"base":
                hasBasePragma = true
                break

        # Stop if already has it
        if hasBasePragma:
            continue

        # We need to add base pragma, find all methods with this name
        var addCount = 0
        for i2, editNode in result:

            # Stop if not applicable
            if editNode.kind != nnkMethodDef: continue
            if editNode.name != node.name: continue

            # Found it, add base
            editNode.addPragma(ident"base")
            addCount += 1

        # Sanity check: Make sure we found it
        if addCount == 0:
            warning("Unable to add {.base.} pragma to method " & $node.name, node)
        else:
            if showDebugInfo: echo "Adding {.base.} pragma to method: " & $node.name


    # Export class
    let newClassName = ident("new" & $className)
    let newMacro = ident"new"
    result.add(quote do:
        export `className`
        export `newClassName`
        export `newMacro`
    )

    # Export all functions
    for m in classInfo.methodIdents:
        result.add(quote do:
            export `m`
        )

    # if $className == "AsyncCls":
    # echo result.repr

    # Export new keyword which was imported from our lib
    # let newIdent = ident"new"
    # result.add(quote do:
    #     export `newIdent`
    # )

    # Done, restore compiler warnings we temporarily disabled
    # result.add(quote do:
    #     {. pop.}
    # )

    # if $className == "CommentB":
    #     echo result.repr
    #     quit()





## Class definition
macro class*(head: untyped, body: untyped): untyped =

    # Create class
    result = newStmtList()
    createClassStructure(head, body, result, isSingleton=false)


## Support for empty class definition
macro class*(head: untyped): untyped = quote do: class `head`: discard


## Singleton class
macro singleton*(head: untyped, body: untyped): untyped =

    # Create class
    result = newStmtList()
    createClassStructure(head, body, result, isSingleton=true)


## Support for using the `new` keyword
# macro new*(args: untyped): untyped =

#     # Replacement function for object creation
#     var hasDone = false
#     proc replaceObjConstr(item: var NimNode) =

#         # Stop once one is done
#         if hasDone: return

#         # Find the first
#         if item.kind == nnkObjConstr or item.kind == nnkCall:

#             echo item.treeRepr

#             let vv = quote do:
#                 type A = ref object of RootObj
#                 A()
#                 (A().init())

#             # Found a match, wrap the construction in (Obj().init())
#             echo vv.treeRepr
#             quit()
#             # item = newTree(nnkCommand,
#             #     bindSym("procCall"),
#             #     copyNimTree(item)
#             # )

#             # If calling super.init(), discard the result
#             # if $item[1][0][1] == "init":

#             #     # Discard the result
#             #     item = newStmtList(
#             #         newTree(nnkDiscardStmt, item)
#             #     )

#             #     # Go through each variable that has a default value and set it again. This is a bit nasty... but it ensures that calling super.init() doesn't
#             #     # overwrite the subclass's reassigned var values
#             #     for name, value in initialValues:

#             #         # Add code
#             #         let varIdent = ident(name)
#             #         item.add(quote do:
#             #             this.`varIdent` = `value`
#             #         )

#             # Done
#             hasDone = true
#             return

#         # Not found, try the children
#         for i, child in item:

#             # Modify child
#             var child2 = child
#             replaceObjConstr(child2)
#             item[i] = child2

#     # Replace object constructor calls
#     var copyArgs = copyNimTree(args)
#     replaceObjConstr(copyArgs)
#     result = copyArgs