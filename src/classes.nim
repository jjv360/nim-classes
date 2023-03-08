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
# import ./classes/plugin_destructors
export static

## Class definition
macro class*(head: untyped, body: untyped): untyped =
    return newClassDescription("class", head, body).compile()

## Empty class definition
macro class*(head: untyped): untyped =
    return newClassDescription("class", head, newStmtList()).compile()

## Singleton class definition. Only one instance of a singleton class exists at any one time.
macro singleton*(head: untyped, body: untyped): untyped =
    return newClassDescription("singleton", head, body).compile()