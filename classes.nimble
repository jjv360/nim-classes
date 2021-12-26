# Package
version       = "0.2.2"
author        = "jjv360"
description   = "Adds class support to Nim."
license       = "MIT"
srcDir        = "src"
installExt    = @["nim"]

# Dependencies
requires "nim >= 1.4.0"

# Tasks
task test, "Test": exec "nim compile --run --d:debugclasses test.nim"