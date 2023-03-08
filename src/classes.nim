##
## This file adds support for classes to Nim.

import std/macros
import ./classes/internal
import ./classes/plugin_variables
import ./classes/plugin_methods
import ./classes/plugin_constructors
import ./classes/plugin_exports
import ./classes/plugin_super
import ./classes/plugin_meta
import ./classes/plugin_mixins
import ./classes/plugin_singleton
export static

## Class definition
macro class*(head: untyped, body: untyped): untyped =
    
    # Get class definition
    let classDef = newClassDescription("class", head, body)

    # Done, output code
    return newStmtList(classDef.outputPrefix, classDef.outputObject, classDef.output, classDef.outputSuffix)


## Empty class definition
macro class*(head: untyped): untyped =
    
    # Get class definition
    let classDef = newClassDescription("class", head, newStmtList())

    # Done, output code
    return newStmtList(classDef.outputPrefix, classDef.outputObject, classDef.output, classDef.outputSuffix)



## Singleton class definition. Only one instance of a singleton class exists at any one time.
macro singleton*(head: untyped, body: untyped): untyped =
    
    # Get class definition
    let classDef = newClassDescription("singleton", head, body)

    # Done, output code
    return newStmtList(classDef.outputPrefix, classDef.outputObject, classDef.output, classDef.outputSuffix)