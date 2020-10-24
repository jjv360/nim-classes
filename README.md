# Classes

A collection of macros which add class support to Nim. To install, clone this repo and run `nimble install`. Features include:

- Simple class syntax
- Class variables with default values
- Inheritance and `super.calls()`
- Default constructors
- Static and abstract methods
- Methods and variables defined in any order
- ... and more! Run `nimble test` or look at test.nim to see more.

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
        echo "Drawing a square of size " & $this.

    ## Calculate size
    method calculateSize(): float = super.calculateSize() + this.radius


# Two ways of creating objects:
let obj = Square().init()
let obj = newSquare()
```