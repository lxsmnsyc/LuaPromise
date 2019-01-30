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

Promise:all({
    Promise:reject("Test"),
    35,
    42,
})
:after(function (value)
    for k, v in ipairs(value) do 
        print(v)
    end 
end)

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



Promise:resolve(1997)
:after(function (value)
    print(value)
end)
Promise:reject("Oopsie!")
:catch(function (value)
    print("caught", value)
end)