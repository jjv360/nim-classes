##
## Extra NimNode processing utilities

import std/macros


## Iterator which traverses nnkStmtList no matter how deeply nested it is
## NOTE: I tried implementing this as an iterator which would have been nice, but I can't get around the "recursion is not supported" error
proc traverseClassStatementList*(item: NimNode, callback: proc(index: int, parent: NimNode, node: NimNode)) =

    # Sanity check: Only nnkStmtList must be passed to this function
    if item.kind != nnkStmtList:
        raiseAssert("Only nnkStmtList nodes can be passed to traverseClassStatementList()")

    # Go through children
    for idx, childNode in item:

        # Check node kind
        if childNode.kind == nnkStmtList:

            # It's a nested stmt list! Go deeper
            traverseClassStatementList(childNode, callback)

        else:

            # Not a stmt list, yield this one
            callback(idx, item, childNode)


## Iterator which traverses a method's parameters
proc traverseParams*(item : NimNode, callback: proc(idx : int, nameNode : NimNode, typeNode : NimNode, identDef : NimNode, identDefIdx : int)) =

    # Get details
    var paramsNode : NimNode
    if item.kind == nnkFormalParams:

        # Already in the format we need
        paramsNode = item

    elif item.kind in RoutineNodes:

        # Get params node
        paramsNode = item.params

    else:

        # Wrong node type
        error("Expected a routine node (nnkMethodDef etc) but got a " & $item.kind & " instead.", item)

    # Go through param defs
    var paramIdx = 0
    for i, identDef in paramsNode:

        # Ignore first one which is the method's return type
        if i == 0:
            continue

        # For each ident inside
        let typeNode = identDef[identDef.len()-2]
        for x, paramIdent in identDef:

            # Skip last two which define the value type
            if x >= identDef.len()-2:
                continue

            # Return this one
            callback(paramIdx, paramIdent, typeNode, identDef, x)
            paramIdx += 1


## Get variable name (nnkIdent or nnkSym) from definition (nnkIdentDefs)
proc variableName*(this: NimNode): NimNode =

    # If already in the right format, return it
    if this.kind == nnkIdent or this.kind == nnkSym:
        return this

    # If it's not an nnkIdentDefs, stop
    if this.kind != nnkIdentDefs:
        error("Expected an identifier but got " & $this.kind & " instead.", this)

    # Get first ident
    var item = this[0]

    # If it's a postfix, remove the postfix
    if item.kind == nnkPostfix:
        item = item[1]

    # If it's a pragam expression, remove the pragma
    if item.kind == nnkPragmaExpr:
        item = item[0]

    # We should have an nnkIdent here, return it
    if item.kind == nnkIdent or item.kind == nnkSym:
        return item
    else:
        error("Unexpected identifier in " & $this.kind & " node.", this)


## Unbind all nnkSym and turn them back into nnkIdent's
proc unbindAllSym*(node : NimNode) =

    # Go through all nodes
    for i, child in node:

        # Unbind it if needed
        if child.kind == nnkSym:
            node[i] = ident($child)

        # Continue recursively
        unbindAllSym(child)