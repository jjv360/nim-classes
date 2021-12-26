import ./src/classes

class ExternalClass:

    var v1 = 5

    method test() = discard

    method testStatic {.static.} = discard

singleton ExternalSingleton:
    var v1 = 3