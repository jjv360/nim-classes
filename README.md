# Classes

![](https://img.shields.io/badge/status-beta-orange)

A collection of macros which add class support to Nim. To install, run `nimble install classes`. Features include:

- Simple class syntax
- Class variables with default values
- Inheritance and `super.calls()`
- Default constructors
- Static and abstract methods
- Methods and variables defined in any order
- Mixins

## Examples

```nim
import classes

# A base class
class Shape:

    ## The position of the shape
    var x = 0
    var y = 0

    ## Optional constructor
    method init() =
        echo "Creating a Shape"

    ## Optional destructor (not supported in JS)
    method deinit() =
        echo "Destroying a Shape"

    ## Abstract draw function
    method draw()

    ## Calculate size
    method calculateSize(): float = return 0

    ## Static method
    method defaultSize(): float {.static.} = 5


# A subclass
class Square of Shape:

    # Radius
    var radius = 5

    ## Override constructor
    method init() =
        super.init()
        echo "Creating a Square"

    ## Draw it
    method draw() =
        echo "Drawing a square of size " & $this.calculateSize()

    ## Calculate size
    method calculateSize(): float = super.calculateSize() + this.radius


# Many ways of creating class instances:
let obj = Square.init()
let obj = Square().init()
let obj = newSquare()

# Call static methods
# NOTE: Static methods don't always work if the name of your nim file is the exact same as the class name. 
# You may get a `type mismatch: got <>` error in that case.
Shape.defaultSize()


# Data only classes
class DataOnly:
    var v0 = 7
    var v1: int
    var v2: string

# Constructing it this way allows you to pass in values for the variables that don't have values set
let obj = DataOnly(v1: 10, v2: "20").init()

# Using the mixin keyword will copy the variables and methods from one class to another
class CustomNote:
    var note = ""

class Circle of Shape:
    mixin CustomNote

let circle = Circle.init()
circle.note = "My custom note"

# Singleton classes act the same way as standard classes, but use a .shared() accessor instead of constructors.
# The default constructor is called the first time the singleton class is accessed.
singleton MySingletonClass:
    var v1 = 7
    method init() = echo "Singleton accessed for the first time!"

# Access the singleton, this also triggers the init() the first time
echo MySingletonClass.shared.v1
```

## Issues

- **JS backend:** As of Nim 1.4.8 (when I last tested), the internal [dom](https://nim-lang.org/docs/dom.html#class%2CNode) library is exposing a `class()` function, and this function always takes precedent over this library's `class` macro. I don't know how to fix this. In the mean time, you can replace the word `class` with `classes.class`