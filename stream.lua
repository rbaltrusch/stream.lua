-- todo zip, any, all
-- todo stream-api: generate(supplier), peek(consumer), skip(amount), collect(collector), partition(predicate), parallel ?

---@alias Iterator fun(): any
---@alias Iterable table | string | Iterator

---@param iterable Iterable
---@return Iterator
local function iter(iterable)
    local type_ = type(iterable)
    if type_ == "table" then
        local index = 0
        return function()
            index = index + 1
            return iterable[index]
        end
    end
    if type_ == "string" then
        return iterable:gmatch(".")
    end
    return iterable
end

---@param iterable Iterable
---@param predicate fun(any): boolean
---@return Iterator
local function filter(iterable, predicate)
    local iterator = iter(iterable)
    return function()
        repeat
            local value = iterator()
            if value ~= nil and predicate(value) then
                return value
            end
        until value == nil
    end
end

---@param iterable Iterable
---@param mapper fun(any): any
---@return Iterator
local function map(iterable, mapper)
    local iterator = iter(iterable)
    return function()
        local value = iterator()
        return value ~= nil and mapper(value) or nil
    end
end

---@param iterable Iterable
---@param mapper fun(any): Iterable
---@return Iterator
local function flatmap(iterable, mapper)
    local iterator = iter(iterable)
    local inner_iterator
    return function()
        local inner_value
        repeat
            if inner_iterator ~= nil then
                inner_value = inner_iterator()
                if inner_value ~= nil then
                    return inner_value
                end
            end

            local value = iterator()
            if value == nil then
                return nil
            end
            inner_iterator = iter(mapper(value))
        until inner_value ~= nil
    end
end

---@param iterable Iterable
---@param amount number
---@return Iterator
local function limit(iterable, amount)
    local iterator = iter(iterable)
    local count = 0
    return function()
        count = count + 1
        return count <= amount and iterator() or nil
    end
end

---@param iterable Iterable
---@param consumer fun(any)
local function each(iterable, consumer)
    for value in iter(iterable) do
        consumer(value)
    end
end

local function collect(iterable)
    local list = {}
    for value in iter(iterable) do
        table.insert(list, value)
    end
    return list
end

---@param iterable Iterable
---@param seed any
---@param binary_operation fun(any, any): any
---@return any
local function reduce(iterable, seed, binary_operation)
    local accumulated = seed
    for value in iter(iterable) do
        accumulated = binary_operation(accumulated, value)
    end
    return accumulated
end

local function partial(fn, ...)
    local n, args = select('#', ...), { ... }
    return function(...)
        return fn(unpack(args, 1, n), ...)
    end
end

local Stream = {}

---@param iterable Iterable
---@return Stream
function Stream.from(iterable)
    ---@class Stream
    local stream = {
        iterator = iter(iterable)
    }

    ---@param predicate fun(any): boolean
    ---@return Stream
    function stream:filter(predicate)
        self.iterator = filter(self.iterator, predicate)
        return self
    end

    ---@param mapper fun(any): any
    ---@return Stream
    function stream:map(mapper)
        self.iterator = map(self.iterator, mapper)
        return self
    end

    ---@param mapper fun(any): any
    ---@return Stream
    function stream:flatmap(mapper)
        self.iterator = flatmap(self.iterator, mapper)
        return self
    end

    ---@param amount number
    ---@return Stream
    function stream:limit(amount)
        self.iterator = limit(self.iterator, amount)
        return self
    end

    ---@param consumer fun(any)
    function stream:each(consumer)
        each(self.iterator, consumer)
    end

    ---@return table
    function stream:collect()
        return collect(self.iterator)
    end

    ---@param seed any
    ---@param binary_operation fun(any, any): any
    ---@return any
    function stream:reduce(seed, binary_operation)
        return reduce(self.iterator, seed, binary_operation)
    end

    setmetatable(stream, {
        __call = function() return stream.iterator() end,
        __index = function() return stream.iterator() end,
    })
    return stream
end

setmetatable(Stream, {
    __call = Stream.from,
})

---@param start number
---@param stop number
---@param step number?
---@return Stream
function Stream.range(start, stop, step)
    step = step or 1
    local value = start - step
    return Stream.from(
        function()
            value = value + step
            return value <= stop and value or nil
        end
    )
end

return {
    iter = iter,
    filter = filter,
    map = map,
    flatmap = flatmap,
    limit = limit,
    each = each,
    collect = collect,
    partial = partial,
    Stream = Stream,
}
