---A functional programming library providing implementations of common lazy iterators,
-- such as `map`, `filter` and `reduce`, both in standalone form, as well as in a chainable
-- form via the `Stream` class (e.g. `stream{1, 2, 3}:filter(...):map(...):limit(5):collect()`)
--
-- Author: R. Baltrusch

-- todo: separate range function
-- todo: distinct (unique)
-- todo Stream gatherers (moving window)

-- A function that yields items, or `nil` to signify termination. Can be used in generic for-loops.
---@generic T
---@class Iterator<T> fun(): T?

-- An object that can act as input to the `iter` function: either a table, a string, or an iterator.
---@generic T
---@class Iterable<T>: table<T> | string | Iterator<T> | Stream<T>

-- An object that aggregates an entire iterable into another form, such as a table or length count.
---@generic T
---@generic S
---@class CollectorInstance<T, S>
---@field collect fun(T): nil
---@field get fun(): S

-- A function that builds and returns a new `CollectorInstance`.
---@generic T
---@class Collector<T>: (fun(): CollectorInstance<T>)

-- A list of all Lua operators exposed as functions.
local operators = {

    -- Adds two numbers.
    ---@param x number
    ---@param y number
    ---@return number
    add = function(x, y) return x + y end,

    -- Subtracts two numbers.
    ---@param x number
    ---@param y number
    ---@return number
    sub = function(x, y) return x - y end,

    -- Multiplies two numbers.
    ---@param x number
    ---@param y number
    ---@return number
    mul = function(x, y) return x * y end,

    -- Divides two numbers.
    ---@param x number
    ---@param y number
    ---@return number
    div = function(x, y) return x / y end,

    -- Returns the remainder of integer division x by y (modulus).
    ---@param x number
    ---@param y number
    ---@return number
    mod = function(x, y) return x % y end,

    -- Returns the exponentiation of x to the power of y.
    ---@param x number
    ---@param y number
    ---@return number
    pow = function(x, y) return x ^ y end,

    -- Returns the unary negation of x.
    ---@param x number
    ---@return number
    neg = function(x) return -x end,

    -- Returns the result of `x and y`.
    ---@param x any
    ---@param y any
    ---@return any
    and_ = function(x, y) return x and y end,

    -- Returns the result of `x or y`.
    ---@param x any
    ---@param y any
    ---@return any
    or_ = function(x, y) return x or y end,

    -- Returns the result of `not x`.
    ---@param x any
    ---@return any
    not_ = function(x) return not x end,

    -- Returns true if x is truthy, otherwise returns false.
    ---@param x any
    ---@return any
    truthy = function(x) return not not x end,

    -- band = function(x, y) return x & y end,
    -- bor = function(x, y) return x | y end,
    -- bnot = function(x) return ~x end,
    -- xor = function(x, y) return x ~ y end,
    -- lshift = function(x, y) return x << y end,
    -- rshift = function(x, y) return x >> y end,

    -- Returns the result of `x == y`.
    ---@param x any
    ---@param y any
    ---@return boolean
    eq = function(x, y) return x == y end,

    -- Returns the result of `x ~= y`.
    ---@param x any
    ---@param y any
    ---@return boolean
    neq = function(x, y) return x ~= y end,

    -- Returns the result of `x > y`.
    ---@param x any
    ---@param y any
    ---@return boolean
    gt = function(x, y) return x > y end,

    -- Returns the result of `x < y`.
    ---@param x any
    ---@param y any
    ---@return boolean
    lt = function(x, y) return x < y end,

    -- Returns the result of `x >= y`.
    ---@param x any
    ---@param y any
    ---@return boolean
    gte = function(x, y) return x >= y end,

    -- Returns the result of `x <= y`.
    ---@param x any
    ---@param y any
    ---@return boolean
    lte = function(x, y) return x <= y end,

    -- Returns the concatenation of x and y.
    ---@param x string
    ---@param y string
    ---@return string
    concat = function(x, y) return x .. y end,

    -- Returns the length of x (as determined by the `#` operator).
    ---@param x any
    ---@return number
    len = function(x) return #x end,

    -- Returns the unchanged input (no op).
    ---@generic T
    ---@param x T
    ---@return T
    id = function(x) return x end,

    -- Returns the result of `x[i]`.
    ---@param i number | string
    ---@param x table
    ---@return any
    index = function(i, x) return x[i] end,

    -- Returns the first element of x.
    ---@param x table
    ---@return any
    first = function(x) return x[1] end,

    -- Returns the second element of x.
    ---@param x table
    ---@return any
    second = function(x) return x[2] end,
}

-- An empty iterator that yields no items.
local nil_iterator = function() return nil end

local stream_metatable = {}
local function is_stream(x)
    local metatable = getmetatable(x)
    return metatable ~= nil and getmetatable(metatable) == stream_metatable
end

-- Returns an iterator function that can be used to iterate through the input iterable:
-- * input nil => empty iterator
-- * input table => iterator through the table
-- * input string => iterator through the string
-- * input Stream => the stream iterator
-- * input iterator => itself
-- * input anything else => raises an error
---@generic T
---@param iterable Iterable<T>?
---@return Iterator<T>
local function iter(iterable)
    if iterable == nil then
        return nil_iterator
    end

    if is_stream(iterable) then
        return iterable
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
    if type_ == "function" then
        return iterable
    end
    error("Cannot convert object of type '" .. type_ .. "' to an iterator!", 2)
end

-- Returns an iterator function yielding numbers from `start` to `stop` (including both ends).
-- A `step`
-- Note: produces an infinite iterator when `step` is 0 and `start` != `stop`.
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

---@generic T
---@param iterable Iterable<T>
---@param predicate (fun(T): boolean)?
---@return boolean
local function any(iterable, predicate)
    local filtered = filter(iterable, predicate)
    local mapped = map(filtered, operators.truthy)
    return mapped() or false
end

---@generic T
---@param iterable Iterable<T>
---@param predicate (fun(T): boolean)?
---@return boolean
local function all(iterable, predicate)
    local mapped = map(iterable, predicate or operators.truthy)
    return reduce(mapped, true, operators.and_)
end

---@generic T
---@param binary_operation fun(T, T): T
---@param default_value T?
---@return fun(): CollectorInstance<T, T?>
local function _create_collector(binary_operation, default_value)
    return function()
        local value = default_value
        return {
            collect = function(self, x)
                value = value == default_value and x or binary_operation(value, x)
            end,
            get = function(self) return value end
        }
    end
end

---@generic T
---@alias tabler fun(): CollectorInstance<T, table<T>>
---@alias numeric fun(): CollectorInstance<T, number>
---@alias optional_numeric fun(): CollectorInstance<number, number?>
---@alias optional fun(): CollectorInstance<T, T?>
---@alias joiner fun(delimiter?: string): fun(): CollectorInstance<string, string>
---@class Collectors
---@field table tabler
---@field sum numeric
---@field count numeric
---@field min optional_numeric
---@field max optional_numeric
---@field average optional_numeric
---@field last optional
---@field join joiner
local collectors = {
    table = function()
        local value = {}
        return {
            collect = function(self, x) table.insert(value, x) end,
            get = function(self) return value end
        }
    end,
    sum = _create_collector(operators.add, 0),
    count = _create_collector(partial(operators.add, 1), 0),
    min = _create_collector(math.min),
    max = _create_collector(math.max),
    join = function(delimiter)
        local function join()
            local value = {}
            return {
                collect = function(self, x) table.insert(value, x) end,
                get = function(self) return table.concat(value, delimiter or "") end
            }
        end

        local collector = {}
        setmetatable(collector, {
            __call = join,

            -- default collector table
            -- allows joining a stream also with the syntax stream:collect(collectors.join)
            -- instead of stream:collect(collectors.join())
            __index = join(),
        })
        return collector --[[@as fun(): CollectorInstance<string, string>]]
    end,
    last = function()
        local value = nil
        return {
            collect = function(self, x) value = x end,
            get = function(self) return value end
        }
    end,
    average = function()
        return function()
            local sum = 0
            local count = 0
            return {
                collect = function(self, x)
                    sum = sum + x
                    count = count + x
                end,
                get = function(self)
                    if count == 0 then
                        return nil
                    end
                    return sum / count
                end
            }
        end
    end,
}

---@generic T
---@generic S
---@param iterable Iterable<T>
---@param collector Collector<T, S>?
---@return S
local function collect(iterable, collector)
    collector = collector or collectors.table
    local new_collector = collector()
    each(iterable, partial(new_collector.collect, new_collector))
    return new_collector:get()
end

---@generic T
---@generic S
---@param iterable Iterable<[T, S]>
---@return Iterator<table<T | S>>
local function multicollect(iterable)
    local iterator = iter(iterable)
    return function()
        local list = {iterator()}
        if list[1] == nil then
            return nil
        end
        return list
    end
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
---@param iterable Iterable<T>?
---@return Stream<T>
function Stream.from(iterable)

    ---@generic T
    ---@class Stream<T>
    local stream = {}

    local iterator = iter(iterable)

    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param mapper fun(iterator: Iterator<T>): Iterator<T>
    ---@return Stream<T>
    function stream:apply(mapper)
        iterator = mapper(iterator)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param predicate (fun(T): boolean)?
    ---@return Stream<T>
    function stream:filter(predicate)
        iterator = filter(iterator, predicate)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@generic S
    ---@param self Stream<T>
    ---@param mapper fun(T): S
    ---@return Stream<T>
    function stream:map(mapper)
        iterator = map(iterator, mapper)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@generic S
    ---@param self Stream<T>
    ---@param mapper fun(T): Iterable<S>
    ---@return Stream<S>
    function stream:flatmap(mapper)
        iterator = flatmap(iterator, mapper)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param amount number
    ---@return Stream<T>
    function stream:limit(amount)
        iterator = limit(iterator, amount)
        return self
    end

    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param amount number
    ---@return Stream<T>
    function stream:skip(amount)
        iterator = skip(iterator, amount)
        return self
    end

    ---@generic T
    ---@param self Stream<T>
    ---@param consumer fun(any)
    ---@return Stream<T>
    function stream:peek(consumer)
        iterator = peek(iterator, consumer)
        return self
    end

    ---@param consumer fun(any)
    ---@return nil
    function stream:each(consumer)
        each(iterator, consumer)
    end

    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param predicate (fun(T): boolean)?
    ---@return boolean
    function stream:all(predicate)
        return all(iterator, predicate)
    end

    ---@generic T
    ---@generic S
    ---@param self Stream<T>
    ---@param collector Collector<T, S>?
    ---@return S
    function stream:collect(collector)
        return collect(iterator, collector)
    end

    ---@generic T
    ---@param self Stream<T>
    ---@return number
    function stream:count()
        return self:collect(collectors.count)
    end

    ---@generic T
    ---@param self Stream<T>
    ---@param seed T
    ---@param binary_operation fun(T, T): T
    ---@return T
    function stream:reduce(seed, binary_operation)
        return reduce(iterator, seed, binary_operation)
    end

    -- this function wrapping looks redundant but is required because stream.iterator can change.
    local function stream_iter()
        return iterator()
    end

    local metatable = {
        __call = stream_iter,
        __index = stream_iter,
    }
    setmetatable(metatable, stream_metatable)
    setmetatable(stream, metatable)
    return stream
end

---@param start number
---@param stop number
---@param step number?
---@return Stream
function Stream.range(start, stop, step)
    return Stream.from(range(start, stop, step))
end

local stream = Stream.from

---@generic T
---@vararg Stream<T> | Iterator<T>
---@return Stream<T>
function Stream.concat(...)
    local streams = {...}
    return stream(flatmap(streams, iter))
end

---@generic T
---@alias IteratorMapper fun(iterable: Iterable<T>): Iterator<T>
---@class Gatherers
---@field batch fun(batch_size: number): IteratorMapper
local gatherers = {

    -- Can be used to gather items yielded from an iterable into batches of a specified size.
    -- <br/>Example: `Stream.range(1, 6):apply(gatherers.batch(2)):collect()` results in `{{1, 2}, {3, 4} {5, 6}}`.
    -- <br/>Note: this is a factory function for an iterator function factory.
    batch = function (batch_size)
        if batch_size <= 0 then
            error("Specified batch size should be greater than zero!", 2)
        end

        -- iterator function factory
        return function(iterable)
            local iterator = iter(iterable)

            -- the actual iterator function
            return function()
                local values = {}
                each(range(1, batch_size), function(_) table.insert(values, iterator()) end)
                if values[1] == nil then
                    return nil
                end
                return values
            end
        end
    end
}

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
    multicollect = multicollect,
    partial = partial,
    zip = zip,
    any = any,
    all = all,
    stream = stream,
    Stream = Stream,
    collectors = collectors,
    gatherers = gatherers,
    operators = operators,
}
