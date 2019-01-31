# LuaPromise
ES6 Promise/A+ implementation in Lua

## Demo
```lua
local Promise = require "promise"

Promise(function (resolve, reject)
    print("Initial")

    resolve()
end)
:after(function ()
    error("Something failed")

    print("Do this")
end)
:catch(function ()
    print("Do that")
end)
:after(function ()
    print("Do this, no matter what happened before")
end)
```

## API
### Promise constructor
```lua
local testPromise = Promise(function (resolve, reject)
    ...
end)
```
### 'then' method 
Since 'then' is a reserved keyword, 'after' was chosen as a synonym for the method name
```lua
Promise(function (resolve, reject)
    resolve("Hello World")
end)
:after(
-- onFulfilled
    function (value)
        return value
    end,
-- onRejection
    function (value)
        return value
    end
)
```
### 'catch' method
```lua
Promise(function (resolve, reject)
    resolve(42)
end)
:after(function (value)
    error("Oops, something went wrong!")
end)
:catch(function (value)
    return value
end)
```
### 'finally' method
```lua

Promise(function (resolve, reject)
    resolve("foo")
end)
:finally(function () 
    return "bar" 
end)
:after(function (value) 
    print(value) 
end)

Promise(function (resolve, reject)
    reject("foo")
end)
:finally(function () 
    return "bar" 
end)
:after(function (value) 
    print(value) 
end)
:catch(function (value)
    print("caught", value)
end)


Promise(function (resolve, reject)
    resolve("foo")
end)
:after(function (value)
    error("Oopsie!")
end)
:finally(function () 
    return "bar" 
end)
:after(function (value) 
    print(value) 
end)
:catch(function (value)
    print("caught", value)
end)
```
### Promise:resolve and Promise:reject
```lua
Promise.resolve(1997)
:after(function (value)
    print(value)
end)
Promise.reject("Oopsie!")
:catch(function (value)
    print("caught", value)
end)
```
### Promise:race and Promise:all
```lua
Promise.all({25, 32, Promise:resolve(48)}):after(function (values)
    for k, v in ipairs(values) do 
        print(v)
    end
end)
Promise.race({1, 4, 9}):after(function (value)
    print(value)
end)
```
## Author Notes
This does not strictly follow the spec defined from the ECMA-262, the Promise/A+ website nor the w3c spec. The behavior defined in this script is solely based on reversed engineering and other tests.


## Changelog
1.1
- Fixed promises with the fulfillment handler returning a pending promise not resolving after the pending promise has been resolved.
- all, race, resolve and reject are now class methods rather than object methods.
- added two new object methods: resolve, which resolves the promise with a value and reject, which rejects the promise with a value.
1.0
- Release