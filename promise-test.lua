local Promise = require "promise"

--[[
    Error handling
]]
print("=============================================")
print("Error handling")
print("=============================================")
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

--[[
    Promise.all
]]
print("=============================================")
print("Promise all")
print("=============================================")
Promise.all({
    Promise.resolve("Test"),
    35,
    42,
})
:after(function (value)
    for k, v in ipairs(value) do 
        print(v)
    end 
end)

--[[
    Promise finally
]]
print("=============================================")
print("Promise finally")
print("=============================================")
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


--[[
    Promise resolve and reject
]]
print("=============================================")
print("Promise resolve and reject")
print("=============================================")
Promise.resolve(1997)
:after(function (value)
    print(value)
end)
Promise.reject("Oopsie!")
:catch(function (value)
    print("caught", value)
end)


--[[
    Asynchronous resolve
]]
print("=============================================")
print("Asynchronous resolve")
print("=============================================")
local trigger

local test = Promise(function (resolve)
    trigger = function (v) resolve(v) end
end)

local tests = {
    test:after(function (v)
        print(v)
        return v
    end),
    test:after(function (v)
        error(v)
    end)
    :catch(function (v)
        print("Error: ", v)
    end),
    test:after(function (v)
        print(v*2)
        return v*2
    end)
}

for k, v in ipairs(tests) do 
    print(v.state)
end 

trigger(42)

for k, v in ipairs(tests) do 
    print(v.state)
end 

--[[
    Asynchronous reject
]]
print("=============================================")
print("Asynchronous reject")
print("=============================================")
local test1 = Promise(function (resolve, reject)
    trigger = function (v) reject(v) end
end)

local test2 = test1:catch(function (reason)
    error("Error: "..reason)
end)

local test3 = test2:catch(function (reason)
    print(reason)
end)

print(test1.state)
print(test2.state)
print(test3.state)

trigger("Oopsie")
print(test1.state)
print(test2.state)
print(test3.state)

--[[
    Resolved promises as returned values
]]

print("=============================================")
print("Resolved promises as returned values")
print("=============================================")
Promise.resolve(2147483647)
:after(function (v)
    return Promise.resolve(v)
end)
:after(function (v)
    print(v)
end)



--[[
    Asynchronous resolve on pending promises returned by after
]]
print("=============================================")
print("Asynchronous resolve on pending promises returned by after")
print("=============================================")
local trg
local x = Promise.resolve(0xDEADBEEF)
local y = x:after(function (v)
    return Promise(function (resolve)
        trg = function (value)
            resolve(value)
        end
    end)
end)
local z = y:after(function (v)
    print(v)
end)

print(x.state)
print(y.state)
print(z.state)

trg(4096)

print(x.state)
print(y.state)
print(z.state)


--[[
    Pending resolve
]]
print("=============================================")
print("Pending resolve")
print("=============================================")
trg = function () end
local a = Promise.resolve(Promise(function (resolve)
    trg = function (value)
        resolve(value)
    end
end))

print(a.state, a.value)

trg(2017)

print(a.state, a.value)


--[[
    Double pending resolve
]]
print("=============================================")
print("Double pending resolve")
print("=============================================")
local trg 
local trg2

local a = Promise(function (resolve, reject)
    trg = function (v) resolve(v) end
end)

local b = a:after(function (v)
    return Promise(function (resolve, reject)
        trg2 = function (val) resolve(val) end        
    end)
end)

local c = b:after(function (v)
    print(v)
end)


print(a.state, a.value)
print(b.state, b.value)
print(c.state, c.value)

trg(2048)
print(a.state, a.value)
print(b.state, b.value)
print(c.state, c.value)

trg2(2048)
print(a.state, a.value)
print(b.state, b.value)
print(c.state, c.value)
