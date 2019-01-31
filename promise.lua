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

--[[
    Promise states
]]
local PENDING = "PENDING"
local FULFILLED = "FULFILLED"
local REJECTED = "REJECTED"

--[[
    Type identifiers
]]
local function isFunction(fn)
    return type(fn) == "function"
end

local function isPromise(x)
    return getmetatable(x) == M
end 

--[[
    Execute queued handlers
]]
local function executeQueue(queue, value)
    local job = queue.first
    while(job) do 
        local status, err = pcall(function ()
            return job(value)
        end)
        job = queue[job]
    end
end
--[[
    Enqueues handlers
]]
local function enqueueHandler(queue, handler)
    if(not queue.first) then 
        queue.first = handler
    else 
        queue[queue.last] = handler
    end 

    queue.last = handler
    queue[handler] = nil
end
--[[
    Rejects 'promise' with reason 'value'

    Upon rejection, all enqueued rejection handlers
    will be called, passing the reason 'value' to every
    handler.
]]
local function rejectPromise(promise, value)
    if(promise.state == PENDING) then 
        promise.value = value
        promise.state = REJECTED
        executeQueue(promise.rqueue, value)
    end 
end
--[[
    Fulfill 'promise' with value 'value'

    Upon fulfillment, all enqueued fulfillment handlers
    will be called, passing the value 'value' to every 
    handler.
]]

local function fulfillPromise(promise, value)
    if(promise.state == PENDING) then 
        promise.value = value
        promise.state = FULFILLED
        executeQueue(promise.fqueue, value)
    end
end
--[[
    Resolves 'promise' with value x

    if x is a promise:
        - if x is pending, 'promise' adapts to the resolution of x after x is resolved.
        - if x is fulfilled, 'promise' is also fulfilled with the value of x.
        - if x is rejected, 'promise' is also rejected with the same reason as x.
    if x is not a promise:
        - execute all handlers enqueued to the fulfillment queue, passing x as the value.
]]
local function resolvePromise(promise, x)
    if(promise.state == PENDING) then 
        assert(promise ~= x, "TypeError")
        if(isPromise(x)) then 
            local xstate = x.state 
    
            if(xstate == PENDING) then 
                x:after( 
                    function(value)
                        resolvePromise(promise, value)
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
            fulfillPromise(promise, x)
        end 
    end
end

--[[
    Promise constructor

    executors passed as an argument are executed at
    the same time the constructor is executed.

    if the executor throws an error, the promise 
    is rejected with the thrown error as the reason.
]]
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
    --[[
        if the executor throws an error,
        reject the promise
    ]]
    if(not status) then 
        rejectPromise(promise, err)
    end 

    return setmetatable(promise, M)
end
--[[
    The 'then' method of Promises

    The handlers passed as an argument to the after method
    will be executed at the same time the promise gets resolved.
    If the promise remains pending after declaring the after statement,
    the handlers are enqueued and will be executed if the promise gets
    resolved.

    This method returns a new promise, which allows chaining.
    The state of the promise is defined by:
    - if the parent promise is already resolved, the new promise
    is resolved in the same way the parent is.
        - if the parent is rejected, the new promise is rejected with
            the same reason as the parent.
        - if the parent is fulfilled, the new promise is fulfilled with
            the same value as the parent.

    - if the parent promise is pending, the new promise remains pending
    until the parent is resolved.
    - if the parent gets resolved, the handlers are executed. Handlers can
    also affect what state the new promise will be in.
        - if the handler is executed without errors and returns a value,
        the new promise resolves the new value as the promise value.
        - if the handler is executed without erros and did not return any
        value, the new promise resolves "nil" as the promise value.
        - if the handler throws an error, the new promise is rejected
        with the thrown error as the rejection reason.
        - if the handler returns a resolved promise, the new promise is 
        resolved with the same value as the returned promise.
        - 
]]
local function after(promise, onFulfilled, onRejected)
    --[[
        Check if handlers are functions
    ]]
    local validF = isFunction(onFulfilled)
    local validR = isFunction(onRejected)


    --[[
        If the rejection handler is not a function,
        replace it with a 
    ]]
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
    if(not (state == PENDING)) then 
        --[[
            Execute the fulfillment handler
        ]]
        local status, err, valid
        if(state == FULFILLED and validF) then 
            status, err = pcall(function ()
                return onFulfilled(promise.value)
            end)

            valid = true
        elseif(state == REJECTED and validR) then 
            status, err = pcall(function ()
                return onRejected(promise.value)
            end)

            valid = true
        end 
        --[[
            Check if there are any valid handlers executed
        ]]
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
                        --[[
                            Create a pending promise
                        ]]
                        local newPromise = new(nil, function (resolve, reject) end)

                        --[[
                            Resolve the promise to that of the returned promise
                        ]]
                        enqueueHandler(err.fqueue, function (value)
                            resolvePromise(newPromise, value)
                        end)

                        --[[
                            Reject as well
                        ]]
                        enqueueHandler(err.rqueue, function (value)
                            rejectPromise(newPromise, value)
                        end)

                        return newPromise
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
                else 
                    --[[
                        Resolve with the returned value if the returned
                        value is not a promise
                    ]]
                    return new(nil, function (resolve, reject)
                        resolve(err)
                    end)
                end
            else
                --[[
                    Reject promise if 'then' threw an error.
                ]]
                return new(nil, function (resolve, reject)
                    reject(err)
                end)
            end 
        end
    end

    --[[
        Create a pending promise
    ]]
    local newPromise = new(nil, function () end)

    --[[
        attach a 'then' to the promise
        so that if the promise is fulfilled/rejected,
        the new promise gets the same state.
    ]]
    enqueueHandler(promise.fqueue, function (value)
        if(validF) then 
            local status, err = pcall(function ()
                return onFulfilled(value)
            end)


            if(status) then 
                resolvePromise(newPromise, err)
            else
                rejectPromise(newPromise, err)
            end 
        end 
    end)
        
    enqueueHandler(promise.rqueue, function (value)
        local status, err = pcall(function ()
            return onRejected(value)
        end)

        if(status) then 
            resolvePromise(newPromise, err)
        else
            rejectPromise(newPromise, err)
        end 
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

--[[
    Wrapper

    Returns a resolve promise with reason
]]
local function newResolve(x)
    return new(nil, function (resolve)
        resolve(x)
    end)
end


--[[
    Wrapper

    Returns a rejected promise with reason
]]
local function newReject(x)
    return new(nil, function (resolve, reject)
        reject(x)
    end)
end

--[[
    Returns a promise that resolves only after all values
    passed to the iterable are not pending promises and
    the values can be resolved.

    the passed value will be the table of values from the iterable
]]
local function all(iterable)
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

--[[
    Returns a pending promise which resolves to the value
    of the first iterable that is:
    - if all iterables  are promises, the first to resolve
    will be used as the resolution value.
    - if not all iterables are promises, the first non-promise
    value will be used as the resolution value

    If the iterable is empty and/or all items are promises that
    remains pending, the returned promise will remain pending.
]]
local function race(iterable)
    --[[
        Return a pending promise
    ]]
    return new(nil, function (resolve, reject)
        --[[
            Check if iterable is a table
        ]]
        if(type(iterable) == "table") then 
            --[[
                check if iterable is a non-empty table
            ]]
            if(#iterable > 0) then
                --[[
                    iterate items
                ]]
                for k, v in ipairs(iterable) do 
                    --[[
                        check if item is a Promise
                    ]]
                    if(isPromise(v)) then 
                        --[[
                            if a promise, attach an after fulfillment handler
                            which resolves the race promise.
                        ]]
                        after(v, function (value)
                            resolve(value)
                        end)
                    else
                        --[[
                            Otherwise, resolve the promise
                        ]]
                        resolve(v)
                    end
                end 
            end 
        else 
            --[[
                Otherwise, resolve to the value.
            ]]
            resolve(iterable)
        end 
    end)
end

local P = setmetatable({}, M)

P.resolve = newResolve
P.reject = newReject
P.all = all 
P.race = race

M.__call = new
M.__index = {
    after = after,
    catch = catch,
    finally = finally,

    resolve = resolvePromise,
    reject = rejectPromise,
}

return P