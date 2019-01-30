--[[
    Lua Promise/A+
	
    MIT License
    Copyright (c) 2019 Alexis Munsayac
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
]]
local M = {}

local PENDING = "PENDING"
local FULFILLED = "FULFILLED"
local REJECTED = "REJECTED"

local function isFunction(fn)
    return type(fn) == "function"
end

local function isPromise(x)
    return getmetatable(x) == M
end 

local function rejectPromise(promise, value)
    if(promise.state == PENDING) then 
        promise.value = value
        promise.state = REJECTED
    
        local queue = promise.rqueue
        local job = queue.first
    
        while(job) do 
            local status, err = pcall(
                function ()
                    return job(value)
                end
            )
            if(not status) then 
                promise.value = err
            end 
            job = queue[job]
        end
    end 
end

local function resolvePromise(promise, x)
    if(promise.state == PENDING) then 
        assert(promise ~= x, "TypeError")

        if(isPromise(x)) then 
            local xstate = x.state 
    
            if(xstate == PENDING) then 
                after(x, 
                    function(value)
                        resolve(promise, value)
                    end,
                    function(value)
                        rejectPromise(promise, value)
                    end
                )
            elseif(xstate == FULFILLED) then 
                resolvePromise(promise, x.value)
            elseif(xstate == REJECTED) then 
                rejectPromise(promise, x.value)
            end 
        else
            promise.value = x
            promise.state = FULFILLED
    
            local queue = promise.fqueue
            local job = queue.first
    
            while(job) do 
                local status, err = pcall(
                    function ()
                        return job(x)
                    end
                )
                
                if(not status) then 
                    promise.value = err
                    promise.state = REJECTED
                end 
                job = queue[job]
            end 
        end 
    end
end

local function new(_, executor)
    --[[
        Create a table
    ]]
    local promise = {}
    --[[
        Set initial state to pending
    ]]
    promise.state = PENDING 

    --[[
        Callback queues
    ]]
    promise.fqueue = {}
    promise.rqueue = {}


    --[[
        Execute executor
    ]]
    local status, err = pcall(
        function ()
            return executor(
                function (value)
                    resolvePromise(promise, value)
                end, 
                function (value)
                    rejectPromise(promise, value)
                end
            )
        end
    )

    if(not status) then 
        rejectPromise(promise, err)
    end 

    return setmetatable(promise, M)
end

local function newFulfillmentHandler(promise, onFulfilled)
    --[[

        Schedule the fulfillment handler using a queue

    ]]
    local queue = promise.fqueue
    
    if(not queue.first) then 
        queue.first = onFulfilled
    else 
        queue[queue.last] = onFulfilled
    end 

    queue.last = onFulfilled
    queue[onFulfilled] = nil
end

local function newRejectionHandler(promise, onRejected)
    --[[

        Schedule the rejection handler using a queue

    ]]
    local queue = promise.rqueue
    
    if(not queue.first) then 
        queue.first = onRejected
    else 
        queue[queue.last] = onRejected
    end 

    queue.last = onRejected
    queue[onRejected] = nil
end

local function after(promise, onFulfilled, onRejected)
    local validF = isFunction(onFulfilled)
    local validR = isFunction(onRejected)

    if(not validR) then 
        onRejected = function (value)
            error(value)
        end
        validR = true
    end 
    --[[

        Schedule handlers if the promise is pending

    ]]
    local state = promise.state
    if(state == PENDING) then 
        if(validF) then 
            newFulfillmentHandler(promise, onFulfilled)
        end 
    
        if(validR) then 
            newRejectionHandler(promise, onRejected)
        end
    else
        --[[
            Execute the fulfillment handler
        ]]
        local status, err, valid
        if(state == FULFILLED and validF) then 
            status, err = pcall(
                function ()
                    return onFulfilled(promise.value)
                end
            )

            valid = true
        elseif(state == REJECTED and validR) then 
            status, err = pcall(
                function ()
                    return onRejected(promise.value)
                end
            )

            valid = true
        end 

        if(valid) then
            --[[
                Check if the handlers didn't throw an error
            ]]
            if(status) then 
                --[[
                    check if the returned value is a promise
                ]]
                if(isPromise(err)) then 
                    --[[
                        Evaluate promise state
                    ]]
                    local promiseState = err.state

                    if(promiseState == PENDING) then 

                    elseif(promiseState == FULFILLED) then 
                        --[[
                            return a resolved promise
                        ]]
                        return new(nil, function (resolve, reject)
                            resolve(err.value)
                        end)
                    elseif(promiseState == REJECTED) then 
                        --[[
                            return a rejected promise
                        ]]
                        return new(nil, function (resolve, reject)
                            reject(err.value)
                        end)
                    end 
                end

                return new(nil, function (resolve, reject)
                    resolve(err)
                end)
            else
                return new(nil, function (resolve, reject)
                    reject(err)
                end)
            end 
        end
    end


    --[[
        Create a pending promise
    ]]
    local newPromise = new(nil, function (resolve, reject) end)

    --[[
        attach a thenable to the promise
        so that if the promise is fulfilled/rejected,
        the new promise gets the same state.
    ]]
    newFulfillmentHandler(promise, function (value)
        resolvePromise(newPromise, value)
    end)
        
    newRejectionHandler(promise, function (value)
        rejectPromise(newPromise, value)
    end)
        
    
    --[[
        return the promise
    ]]
    return newPromise
end

local function catch(promise, onRejected)
    return after(promise, nil, onRejected)
end

local function finally(promise, onFinally)
    return after(promise,
        function (value)
            return after(
                new(_, function (resolve)
                    resolve(onFinally())
                end),
                function ()
                    return value 
                end
            )
        end,
        function (value)
            return after(
                new(_, function (resolve)
                    resolve(onFinally())
                end),
                function ()
                    error(value) 
                end
            )
        end
    )
end 

local function newResolve(_, x)
    return new(_, function (resolve)
        resolve(x)
    end)
end

local function newReject(_, x)
    return new(_, function (resolve, reject)
        reject(x)
    end)
end

local function all(_, iterable)
    --[[
        Used to store the promise values
    ]]
    local accumulator = {}
    --[[
        Create a new promise that resolves
        if all of the iterable items have resolved.
    ]]
    return new(_, function (resolve, reject)
        --[[
            Check if iterable is a table
        ]]
        if(type(iterable) == "table") then 
            --[[
                Store the table size
            ]]
            local counter = #iterable
            --[[
                Check if iterable is not empty
            ]]
            if(counter > 0) then 
                --[[
                    Iterate iterable
                ]]
                for k, v in ipairs(iterable) do 
                    --[[
                        Check if item is a Promise
                    ]]
                    if(isPromise(v)) then 
                        --[[
                            attach a fulfillmnet handler to the promise
                        ]]
                        after(
                            after(v, 
                                function (value)
                                    --[[
                                        Insert value to accumulator
                                    ]]
                                    accumulator[k] = value
                                end
                            ),
                            function ()
                                --[[
                                    Success

                                    check if accumulator is to be resolved
                                    if all iterables have been resolved
                                ]]
                                counter = counter - 1

                                if(counter == 0) then 
                                    resolve(accumulator)
                                end 
                            end
                        )
                    else 
                        --[[
                            The item is not a promise, add to accumulator
                        ]]
                        counter = counter - 1 
                        accumulator[k] = v
                    end 
                end 
                --[[
                    Resolve if counter is 0
                ]]
                if(counter == 0) then 
                    resolve(accumulator)
                end   
            else 
                --[[
                    Resolve if empty
                ]]
                resolve()
            end 
        else 
            --[[
                Resolve the iterable instead
            ]]
            resolve(iterable)
        end 
    end)
end 

local function race(_, iterable)
    return new(_, function (resolve, reject)
        if(type(iterable) == "table") then 
            if(#iterable > 0) then
                
                for k, v in ipairs(iterable) do 
                    if(isPromise(v)) then 
                        after(v, function (value)
                            resolve(value)
                        end)
                    else
                        resolve(v)
                    end
                end 
            end 
        end 
    end)
end

local P = setmetatable({}, M)

M.__call = new
M.__index = {
    after = after,
    catch = catch,
    finally = finally,
    resolve = newResolve,
    reject = newReject,
    all = all,
    race = race
}

return P