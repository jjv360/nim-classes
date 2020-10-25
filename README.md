# Classes

![](https://img.shields.io/badge/status-alpha-red)

A collection of macros which add class support to Nim. To install, clone this repo and run `nimble install`. Features include:

- Simple class syntax
- Class variables with default values
- Inheritance and `super.calls()`
- Default constructors
- Static and abstract methods
- Methods and variables defined in any order

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

    ## Optional destructor (not implemented yet)
    method destroy() =
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
```