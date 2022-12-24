import ./src/classes

class ExternalClass:

    var v1 = 5

    method test() = discard

    method testStatic {.static.} = discard

    var testCustomSetterValue = 6
    method testCustomSetter(): int = this.testCustomSetterValue
    method `testCustomSetter=`(v: int) = this.testCustomSetterValue = v

singleton ExternalSingleton:
    var v1 = 3