# Package
version       = "1.0.18"
author        = "jjv360"
description   = "Adds class support to Nim."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 2.0.6"

# Tasks
task test, "Run native and Javascript tests": 

    # Note: To get more debug information, add the --define:debugclasses flag to the below commands

    # Execute the test with the JS compiler
    exec "nim js --run test.nim"

    # Execute the test with the native compiler
    exec "nim compile --run test.nim"


task debug, "Build tests and show debug information":

    # Built the tests with the native compiler, but include the debug flag so we can see code generation and other debug information
    exec "nim compile --run --define:debugclasses test.nim"