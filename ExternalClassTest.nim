import ./src/classes

class ExternalClass:

    var v1 = 5

    method test() = discard

    method testStatic {.static.} = discard


classtype ExternalClassAlias:

    var v1 = 5

    method test() = discard

    method testStatic {.static.} = discard
