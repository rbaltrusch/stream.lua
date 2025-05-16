-- todo any, all, takewhile, dropwhile, sorted, reversed ?
-- todo stream-api: peek(consumer) ?
-- todo cycle
-- todo add operators
-- todo inline documentation

---@generic T
---@class Iterator<T>: (fun(): T)
---@class Iterable<T>: table<T> | string | Iterator<T>

---@generic T
---@generic S
---@class CollectorInstance<T, S>
---@field collect fun(T): nil
---@field get fun(): S

---@generic T
---@class Collector<T>: (fun(): CollectorInstance<T>)

local nil_iterator = function() return nil end

local operators = {
    add = function(x, y) return x + y end,
    sub = function(x, y) return x - y end,
    mul = function(x, y) return x * y end,
    div = function(x, y) return x / y end,
    mod = function(x, y) return x % y end,
    pow = function(x, y) return x ^ y end,
    neg = function(x) return -x end,
    and_ = function(x, y) return x and y end,
    or_ = function(x, y) return x or y end,
    not_ = function(x) return not x end,
    truthy = function(x) return not not x end,
    -- band = function(x, y) return x & y end,
    -- bor = function(x, y) return x | y end,
    -- bnot = function(x) return ~x end,
    -- xor = function(x, y) return x ~ y end,
    -- lshift = function(x, y) return x << y end,
    -- rshift = function(x, y) return x >> y end,
    eq = function(x, y) return x == y end,
    neq = function(x, y) return x ~= y end,
    gt = function(x, y) return x > y end,
    lt = function(x, y) return x < y end,
    gte = function(x, y) return x >= y end,
    lte = function(x, y) return x <= y end,
    concat = function(x, y) return x .. y end,
    len = function(x) return #x end,
}

---@generic T
---@param iterable Iterable<T>?
---@return Iterator<T>
local function iter(iterable)
    if iterable == nil then
        return nil_iterator
    end

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

-- Note: produces an infinite iterator when step is 0
---@nodiscard
---@param start number
---@param stop number
---@param step number?
---@return Iterator<number>
local function range(start, stop, step)
    step = step or 1
    local value = start - step

    local comparator = (
        step >= 0
        and function(x, y) return x <= y end
        or function(x, y) return x >= y end
    )

    return function()
        value = value + step
        return comparator(value, stop) and value or nil
    end
end

---@nodiscard
---@generic T
---@generic S
---@param first Iterable<T>
---@param second Iterable<S>
---@return Iterator<[T, S]>
local function zip(first, second)
    local first_iterator = iter(first)
    local second_iterator = iter(second)
    return function()
        while true do
            local first_value = first_iterator()
            local second_value = second_iterator()
            if first_value == nil or second_value == nil then
                break
            end
            return first_value, second_value
        end
    end
end

---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@param predicate (fun(T): boolean)?
---@return Iterator<T>
local function filter(iterable, predicate)
    local iterator = iter(iterable)
    predicate = predicate or operators.truthy
    return function()
        repeat
            local value = iterator()
            if value ~= nil and predicate(value) then
                return value
            end
        until value == nil
    end
end

---@nodiscard
---@generic T
---@generic S
---@param iterable Iterable<T>
---@param mapper fun(T): S
---@return Iterator<S>
local function map(iterable, mapper)
    local iterator = iter(iterable)
    return function()
        local value = iterator()
        if value == nil then
            return nil
        end
        return mapper(value)
    end
end

---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@param predicate (fun(T): boolean)
---@return Iterator<T>
local function takewhile(iterable, predicate)
    local function mapper(x)
        local include = predicate(x)
        if include then
            return x
        end
        return nil
    end
    return map(iterable, mapper)
end

---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@param predicate (fun(T): boolean)
---@return Iterator<T>
local function dropwhile(iterable, predicate)
    local started = false
    local function wrapped_predicate(x)
        local exclude = predicate(x)
        if not exclude then
            started = true
        end
        return started
    end
    return filter(iterable, wrapped_predicate)
end

---@nodiscard
---@generic T
---@generic S
---@param iterable Iterable<T>
---@param mapper fun(T): Iterable<S>
---@return Iterator<S>
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

---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@param amount number
---@return Iterator<T>
local function limit(iterable, amount)
    local iterator = iter(iterable)
    local count = 0
    return function()
        count = count + 1
        return count <= amount and iterator() or nil
    end
end

---@generic T
---@param iterable Iterable<T>
---@param amount number
---@return Iterator<T>
local function skip(iterable, amount)
    local iterator = iter(iterable)
    local value
    for _ = 1, amount do
        value = iterator()
        if value == nil then
            return nil_iterator
        end
    end
    return iterator
end

---@generic T
---@param iterable Iterable<T>
---@param consumer fun(T): nil
local function each(iterable, consumer)
    for value in iter(iterable) do
        consumer(value)
    end
end

---@generic T
---@param iterable Iterable<T>
---@param seed T
---@param binary_operation fun(T, T): T
---@return T
local function reduce(iterable, seed, binary_operation)
    local accumulated = seed
    for value in iter(iterable) do
        accumulated = binary_operation(accumulated, value)
    end
    return accumulated
end

---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@param consumer fun(T): nil
---@return Iterator<T>
local function peek(iterable, consumer)
    local mapper = function (x)
        consumer(x)
        return x
    end
    return map(iterable, mapper)
end

---@nodiscard
local function partial(fn, ...)
    local n, args = select('#', ...), { ... }
    return function(...)
        ---@diagnostic disable-next-line: deprecated
        return fn(unpack(args, 1, n), ...)
    end
end

local operators = {
    add = function(x, y) return x + y end
}

---@class Collectors
---@field table fun(): CollectorInstance
---@field sum fun(): CollectorInstance
---@field join fun(string): fun(): CollectorInstance
local collectors = {
    table = function()
        return {
            value = {},
            collect = function(self, x) table.insert(self.value, x) end,
            get = function(self) return self.value end
        }
    end,
    sum = function()
        return {
            value = 0,
            collect = function(self, x) self.value = self.value + x end,
            get = function(self) return self.value end
        }
    end,
    count = function()
        return {
            value = 0,
            collect = function(self, _) self.value = self.value + 1 end,
            get = function(self) return self.value end
        }
    end,
    join = function (delimiter)
        return function()
            return {
                value = {},
                collect = function(self, x) table.insert(self.value, x) end,
                get = function(self) return table.concat(self.value, delimiter or "") end
            }
        end
    end
}

---@generic T
---@param iterable Iterable<T>
---@param collector Collector<T>?
---@return table<T>
local function collect(iterable, collector)
    collector = collector or collectors.table
    local new_collector = collector()
    each(iterable, partial(new_collector.collect, new_collector))
    return new_collector:get()
end

---@generic T
---@param iterable Iterable<T>
---@return Iterator<T>
local function cycle(iterable)
    local list = collect(iterable)
    local infinite = function() return 0 end
    return flatmap(infinite, function(_) return iter(list) end)
end

---@generic T
---@param iterable Iterable<T>
---@return Iterator<T>
local function reversed(iterable)
    local list = collect(iterable)
    return map(range(#list, 1, -1), function(index) return list[index] end)
end

local Stream = {}

---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@return Stream<T>
function Stream.from(iterable)
    ---@class Stream
    local stream = {
        iterator = iter(iterable)
    }

    ---@nodiscard
    ---@generic T
    ---@param predicate (fun(T): boolean)?
    ---@return Stream<T>
    function stream:filter(predicate)
        self.iterator = filter(self.iterator, predicate)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@generic S
    ---@param mapper fun(T): S
    ---@return Stream<T>
    function stream:map(mapper)
        self.iterator = map(self.iterator, mapper)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@generic S
    ---@param mapper fun(T): Iterable<S>
    ---@return Stream<S>
    function stream:flatmap(mapper)
        self.iterator = flatmap(self.iterator, mapper)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@param amount number
    ---@return Stream<T>
    function stream:limit(amount)
        self.iterator = limit(self.iterator, amount)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@param amount number
    ---@return Stream<T>
    function stream:skip(amount)
        self.iterator = skip(self.iterator, amount)
        return self
    end

    ---@generic T
    ---@param self Stream<T>
    ---@param consumer fun(any)
    ---@return Stream<T>
    function stream:peek(consumer)
        self.iterator = peek(self.iterator, consumer)
        return self
    end

    ---@param consumer fun(any)
    ---@return nil
    function stream:each(consumer)
        each(self.iterator, consumer)
    end

    ---@generic T
    ---@param collector Collector<T>?
    ---@return table<T>
    function stream:collect(collector)
        return collect(self.iterator, collector)
    end

    ---@generic T
    ---@param self Stream<T>
    ---@return number
    function stream:count()
        return self:collect(collectors.count)
    end

    ---@generic T
    ---@param seed T
    ---@param binary_operation fun(T, T): T
    ---@return T
    function stream:reduce(seed, binary_operation)
        return reduce(self.iterator, seed, binary_operation)
    end

    setmetatable(stream, {
        __call = stream.iterator,
        __index = stream.iterator,
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
    return Stream.from(range(start, stop, step))
end

local stream = Stream.from

return {
    iter = iter,
    range = range,
    cycle = cycle,
    reversed = reversed,
    filter = filter,
    map = map,
    flatmap = flatmap,
    reduce = reduce,
    dropwhile = dropwhile,
    takewhile = takewhile,
    limit = limit,
    skip = skip,
    each = each,
    peek = peek,
    collect = collect,
    partial = partial,
    zip = zip,
    stream = stream,
    Stream = Stream,
    collectors = collectors,
    operators = operators,
}
