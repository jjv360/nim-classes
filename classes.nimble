# Package
version       = "0.2.9"
author        = "jjv360"
description   = "Adds class support to Nim."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 1.4.0"

# Tasks
task test, "Test": 

    # Note: To get more debug information, add the --define:debugclasses flag to the below commands

    # Execute the test with the JS compiler
    exec "nim js --run test.nim"

    # Execute the test with the native compiler
    exec "nim compile --run test.nim"