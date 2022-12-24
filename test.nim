import ./src/classes
import ExternalClassTest
import macros
import strutils

# Platform specific imports
when defined(js):

    # Code for Javascript
    const fgBlue = "\u001b[34m"
    const fgGreen = "\u001b[32m"
    const fgRed = "\u001b[31m"
    const fgDefault = "\u001b[0m"
    proc styledEcho(v: varargs[string]) = echo v.join("")

    const platformName = "js"

else:

    # Native code
    import asyncdispatch
    import terminal
    
    const platformName = "native"




# Helpers for testing
proc group(str: string) = styledEcho "\n", fgBlue, "+ ", fgDefault, str, " (" & platformName & " compiler)"
proc test(str: string) = styledEcho fgGreen, "  + ", fgDefault, str
proc warn(str: string) = styledEcho fgRed, "    ! ", fgDefault, str



group "Class variables"
test "Empty class definition"
class Empty1
class Empty2 of Empty1


test "Class variables"
class ClassWithVars:

    ## Comment here
    var var0 = 0
    var var1 = "hello"
    var var2: int = len("hi")
    var var3: seq[string]
    var var4: seq[string] = @["hi"]
    var var5 = true

assert(ClassWithVars().init().var0 == 0)
assert(ClassWithVars.init().var1 == "hello")
assert(newClassWithVars().var2 == 2)
assert(ClassWithVars.init().var5 == true)



test "Class variables overwritten by subclass"
class ClassWithVars2 of ClassWithVars: 
    var var1 = "hello rewritten"

assert(ClassWithVars2().init().var2 == 2)
assert(ClassWithVars2().init().var1 == "hello rewritten")



test "Data only class"
class DataOnly:
    var v1 = 5
    var v2: int
    var v3: string

assert(DataOnly(v3: "hi", v2: 10).init().v1 == 5)
assert(DataOnly(v3: "hi", v2: 10).init().v2 == 10)
assert(DataOnly(v3: "hi", v2: 10).init().v3 == "hi")



test "Using 'when' inside class body"
warn "Not implemented yet"
# class WhenClass:

#     when compileOption("threads"):
#         var hasThreads = true
#     else:
#         var hasThreads = false

# assert(WhenClass.init().hasThreads == compileOption("threads"))



test "Getters and setters"
class CustomGetterSetter:
    var v2private = 6
    method v2(): int = this.v2private
    method `v2=`(v: int) = this.v2private = v

let customGetterSetter = CustomGetterSetter.init()
customGetterSetter.v2 = 7
assert(customGetterSetter.v2 == 7)

let externalGetterSetter = ExternalClass.init()
externalGetterSetter.testCustomSetter = 8
assert(externalGetterSetter.testCustomSetter == 8)




group "Constructors"
test "Automatic constructors on the base class"
class ClassA

# Our method of creating classes
let classA1 = ClassA.init()

# Nim's method of creating classes
let classA2 = newClassA()




test "Automatic constructors on subclasses"

class C:
    var v1 = 5
    method init(i: int) = this.v1 = this.v1 + 5 + i

class D of C

assert(C.new(5).v1 == 15)
assert(D.new(5).v1 == 15)

var tmp1 = 5
class E:
    method init() =
        tmp1 = tmp1 + 5

class F of E

class G of F:
    method init() =
        super.init()
        tmp1 = tmp1 + 5

discard E.init()
assert(tmp1 == 10)
discard F.init()
assert(tmp1 == 15)
discard G.init()
assert(tmp1 == 25)


test "Automatic constructors on subclasses with overwritten vars"
warn "Not implemented yet, will not set variable values"
# class E of C:
#     var v1 = 10

# assert(E.new(5).v1 == 20)






test "Constructor with 0 args"
class ClassWithZeroInit:
    var v1 = 5
    method init() =
        this.v1 = this.v1 + 5

assert(ClassWithZeroInit().init().v1 == 10)



test "Constructor with 5 args"
class ClassWith3Init:
    var v1: int
    method init(a, b, c: int, d: float, e: float) =
        this.v1 = a + b + c

assert(ClassWith3Init().init(5, 5, 5, e=4.5, d=3.4).v1 == 15)
assert(newClassWith3Init(5, 5, 5, e=4.5, d=3.4).v1 == 15)
assert(ClassWith3Init.init(5, 5, 5, e=4.5, d=3.4).v1 == 15)



test "Factory method"

class ClassWithFactory:
    var v1 = 0
    method withValue(v: int): ClassWithFactory {.static.} =
        let n = ClassWithFactory.init()
        n.v1 = v
        return n

assert(ClassWithFactory.withValue(3).v1 == 3)



group "Destructors"
test "Called on dealloc"
warn "Not implemented yet"



group "Comments"
test "Comment inside method"

class CommentA:

    method a() =
        ## Test
        discard

CommentA.init().a()


test "Comment outside method"

class CommentB:

    ## Test
    method b() =
        discard

    ## Test2
    method c() =
        ## Actual
        discard

    ## Test
    method d() =

        # Not real
        discard

CommentB.init().b() 
CommentB.init().c()
CommentB.init().d()

# TODO: How do we test for this?






group "Inheritance"
test "Super constructor"
class WithSuper3:
    var v1 = 5
    method init(a: int) =
        this.v1 += a

class WithSuper4 of WithSuper3:
    method init() = super.init(20)

assert(WithSuper3().init(5).v1 == 10)
assert(WithSuper4().init().v1 == 25)




test "Super call"
class WithSuper1:
    method test(): int = 5

class WithSuper2 of WithSuper1:
    method test(): int = super.test() + 5
    method test2(): int = super.test()

assert(newWithSuper2().test() == 10)
assert(newWithSuper2().test2() == 5)




test "Constructor inheritance"

class ClsInit1:
    var v1 = 1
    method init() = this.v1 += 2

class ClsInit2 of ClsInit1:
    method init() =
        super.init()
        this.v1 += 3

class ClsInit3 of ClsInit2:
    method init() =
        super.init()
        this.v1 += 4

assert(ClsInit3.init().v1 == 10)



test "Super call with skipped inheritance"

class TestInheritanceA1:
    var v1 = 1
    method increase() = this.v1 += 1

class TestInheritanceA2 of TestInheritanceA1

class TestInheritanceA3 of TestInheritanceA2:
    method increase() =
        super.increase()
        this.v1 += 2

let inheritanceA = TestInheritanceA3.init()
inheritanceA.increase()
assert(inheritanceA.v1 == 4)







group "Methods"
test "Abstract methods"
class WithAbstract:
    method overrideMe()

class WithAbstract2:
    method overrideMe() = discard

# Calling the abstract method directly should fail
doAssertRaises AssertionError, WithAbstract().overrideMe()

# Calling the overridden abstract method from the subclass should be fine
WithAbstract2().overrideMe()



test "Static methods"
class WithStatic:
    method staticFunc() {.static.} = discard
    method staticFunc2() {.used, static.} = discard

WithStatic.staticFunc()



test "Private methods"
warn "Not implemented yet"




group "Interop with Nim's class format"
test "Subclass a Nim class"

type NimClass = ref object of RootObj
    var1: string

class NimClass2 of NimClass:
    var var1 {.noDefine.} = "hi"

assert(NimClass2().init().var1 == "hi")




test "Nim subclass of our class"

class NimClass3:
    var v1 = "hi"

type NimClass4 = ref object of NimClass3

assert(NimClass4().init().v1 == "hi")



test "Type checking at compile time"

class InheritedFromNimClassA1 of NimClass
class InheritedFromNimClassA2 of InheritedFromNimClassA1
class InheritedFromNimClassA3 of InheritedFromNimClassA2
class InheritedClassB1
class InheritedClassB2 of InheritedClassB1
class InheritedClassB3 of InheritedClassB2

assert(InheritedFromNimClassA3.init() is NimClass == true)
assert(InheritedFromNimClassA3.init() is InheritedFromNimClassA1 == true)
assert(InheritedFromNimClassA3.init() is InheritedFromNimClassA2 == true)
assert(InheritedFromNimClassA3.init() is InheritedFromNimClassA3 == true)
assert(InheritedFromNimClassA3.init() is InheritedClassB1 == false)
assert(InheritedClassB3.init() is InheritedClassB1 == true)
assert(InheritedClassB3.init() is InheritedClassB2 == true)
assert(InheritedClassB3.init() is InheritedClassB3 == true)
assert(InheritedClassB3.init() is InheritedFromNimClassA3 == false)



test "Type checking at run time"

var inheritedInVariable: InheritedClassB1 = InheritedClassB3.init()
assert(inheritedInVariable of InheritedFromNimClassA3 == false)
assert(inheritedInVariable of InheritedClassB1 == true)
assert(inheritedInVariable of InheritedClassB2 == true)
assert(inheritedInVariable of InheritedClassB3 == true)





group "Exported classes"
test "Use a static method"
ExternalClass.testStatic()

test "Use a normal method"
ExternalClass.init().test()
newExternalClass().test()
ExternalClass.new().test




group "Advanced usage"
test "Get class name at runtime"

class Adv1
class Adv2 of Adv1

assert(Adv1.init().className == "Adv1")
assert(Adv2.init().className == "Adv2")


when not defined(js):

    test "Run an async function"

    class AsyncCls:
        method testVoid() {.async.} = discard
        method testInt(): Future[int] {.async.} = return 3

    waitFor AsyncCls.init().testVoid()
    let i: int = waitFor AsyncCls.init().testInt()
    assert(i == 3)



test "Proxied macro"

macro class2(head: untyped, body: untyped): untyped = 

    # TODO: Why does Nim put a `gensym123 suffix only on the injected variable, and not the injected method???
    let injectedVar = ident"injectedVar"
    
    # let injectedVar
    return quote do: 
        class `head`: 
            var `injectedVar`: int = 3
            method injectedMethod(): int = 5
            `body`

class2 MyProxiedClass:

    ## Original var
    var originalVar = 6

    ## Original method
    method checkMe(): int = 4

assert(MyProxiedClass.init().checkMe() == 4)
assert(MyProxiedClass.init().injectedVar == 3)
assert(MyProxiedClass.init().injectedMethod() == 5)
assert(MyProxiedClass.init().originalVar == 6)

class2 ProxyClass2 of MyProxiedClass:
    var v3 = 3
    method m4(): int = 4

assert(ProxyClass2.init().v3 == 3)
assert(ProxyClass2.init().m4 == 4)

class2 Cls2Init1:
    var v1 = 1
    method init() = this.v1 += 2

class2 Cls2Init2 of Cls2Init1:

    ## Override init
    method init() =
        super.init()
        this.v1 += 3

class2 Cls2Init3 of Cls2Init2:

    ## Override init again
    method init() =
        super.init()
        this.v1 += 4

assert(Cls2Init3.init().v1 == 10)



group "Mixins"
test "Apply mixin to class"

class Mixed1:

    ## Comment here
    var var0 = 0
    var var1 = "hello"

class Mixed2:
    mixin Mixed1

    ## Comment here
    var var2 = 0
    var var3 = "hello"

assert(Mixed2.init().var1 == "hello")


test "Modify mixin variable from class"

class Mixed3:
    method init() =
        this.var0 = 3

    mixin Mixed1

assert(Mixed3.init().var0 == 3)


test "Modify class variable from mixin"

class Mixed4:
    var var0 = 2
    method update() = 
        this.var0 = this.var0 * 2

class Mixed5:
    mixin Mixed4
    
let mixed5 = Mixed5.init()
mixed5.update()
assert(mixed5.var0 == 4)


test "Subclass with mixin"

class Mixed6 of Mixed1:
    mixin Mixed2

assert(Mixed6.init().var3 == "hello")


test "Subclassed mixin"

class Mixed7 of Mixed4
class Mixed8 of Mixed2:
    mixin Mixed7

let mixed8 = Mixed8.init()
mixed8.update()
assert(mixed8.var0 == 4)



group "Singletons"

test "Definition"

singleton Singleton1:
    var v1 = 3
    var v2 = 0
    method init() =
        this.v2 = 4

test "Variables"
assert(Singleton1.shared.v1 == 3)

test "Init"
assert(Singleton1.shared.v2 == 4)

singleton Singleton2 of Singleton1:
    var v3 = 0
    method init() =
        super.init()
        this.v3 = 5

    method myFunc(): int = 6

test "Subclassing"
assert(Singleton2.shared.v1 == 3)
assert(Singleton2.shared.v2 == 4)
assert(Singleton2.shared.v3 == 5)

test "Methods"
assert(Singleton2.shared.myFunc() == 6)

test "External singleton"
assert(ExternalSingleton.shared.v1 == 3)



# All tests done
echo ""