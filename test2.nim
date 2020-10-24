import ./src/classes

class Test2Class1:
    method test() = discard

class Test2Class2:
    method test() {.static.} = discard

## Database class
class Database:

    var hi: seq[string]

    ## Singleton
    method shared(): Database {.static.} =
        let db {.global.} = Database().init()
        return db