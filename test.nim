import ./src/classes
import terminal
import ./test2



# Helpers for testing
proc group(str: string) = styledEcho "\n", fgBlue, "+ ", fgDefault, str
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

assert(ClassWithVars().init().var0 == 0)
assert(ClassWithVars.init().var1 == "hello")
assert(newClassWithVars().var2 == 2)
assert(ClassWithVars.new().var2 == 2)



test "Class variables overwritten by subclass"
class ClassWithVars2 of ClassWithVars: 
    var var1 = "hello rewritten"

assert(ClassWithVars2().init().var1 == "hello rewritten")



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
assert(ClassWith3Init.new(5, 5, 5, e=4.5, d=3.4).v1 == 15)



group "Destructors"
test "Called on dealloc"
warn "Not implemented yet"



group "Superclass access"
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






group "Exported classes"
test "Use a method"
Test2Class1.init().test()
newTest2Class1().test()
Test2Class1.new().test

test "Use a static method"
Test2Class2.test()
discard Database.shared()





# All tests done
echo ""