---A functional programming library providing implementations of common lazy iterators,
-- such as `map`, `filter` and `reduce`, both in standalone form, as well as in a chainable
-- form via the `Stream` class (e.g. `stream{1, 2, 3}:filter(...):map(...):limit(5):collect()`)
--
-- Author: R. Baltrusch

-- todo document how iterator functions work - also termination on nil

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

-- Backwards compatibility for Lua 5.1 and below
---@diagnostic disable-next-line: deprecated
table.unpack = table.unpack or unpack
table.pack = table.pack or function(...) return { n = select("#", ...), ... } end

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

    -- bitwise operators are not available before Lua 5.3, so commenting them out for now...
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

    -- Calls the first input with all other arguments and returns the result.
    ---@generic T
    ---@param x fun(...): T
    ---@return T
    call = function(x, ...) return x(...) end,

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
-- * input nil/unspecified => empty iterator
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
    if type_ == "function" then
        return iterable
    end
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
    error("Cannot convert object of type '" .. type_ .. "' to an iterator!", 2)
end

-- Returns an iterator function yielding all keys of the specified table in random order.
-- <br>Note that this yields numeric indices for array tables.
---@generic T
---@generic S
---@param object table<T, S>
---@return Iterator<T>
local function keys(object)
    local key
    return function()
        key = next(object, key)
        return key
    end
end

-- Returns an iterator function yielding all values of the specified table in random order.
---@generic T
---@generic S
---@param object table<T, S>
---@return Iterator<T>
local function values(object)
    local key, value
    return function()
        key, value = next(object, key)
        return value
    end
end

-- Returns an iterator function yielding all key-value pairs, each packed into a table,
-- of the specified table in random order.
-- <br><br> Example: `items{a = 1, b = 2}` yields `{"a", 1}` and `{"b", 2}` (order not guaranteed).
-- <br><br>Note that this yields numeric indices as keys for array tables.
---@generic T
---@generic S
---@param object table<T, S>
---@return Iterator<table<T | S>>
local function items(object)
    local key, value
    return function()
        key, value = next(object, key)
        if key == nil and value == nil then
            return nil
        end
        return {key, value}
    end
end

-- Returns an iterator function yielding numbers from `start` to `stop` (including both ends).
-- <br>An optional third `step` parameter can be provided to control the interval
-- between the yielded numbers.
-- <br><br>**Warning**: produces an infinite iterator when `step` is 0 and `start` != `stop`.
-- <br><br>Example: `range(1, 5, 2)` yields 1, then 3, then 5.
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

-- Returns an iterator function yielding all items in the iterable for which
-- the specified predicate tests truthy.
-- <br>Filters out `false` values when no predicate function is specified.
-- <br><br>Example: `filter({1, 2, 3}, function(x) return x % 2 == 0 end)` yields 1 and 3.
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

-- Returns an iterator function yielding elements from the iterable, transformed
-- by applying the specified mapper function to each original element individually.
-- <br><br> Example: `map({1, 2, 3}, function(x) return x + 1 end)` yields 2, 3, and 4.
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

-- Returns an iterator function yielding elements from the iterable until the
-- specified predicate tests false for an element for the first time.
-- <br><br> Example: `takewhile({1, 2, -1, 3, -2}, function(x) return x > 0 end)` yields 1 and 2.
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

-- Returns an iterator function skipping elements from the iterable until the
-- specified predicate tests false for an element for the first time, then yields
-- all remaining elements.
-- <br><br> Example: `dropwhile({1, 2, -1, 3, -2}, function(x) return x > 0 end)` yields -1, 3, and -2
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

-- Returns an iterator function yielding elements from each result of applying
-- the specified mapper function to each element in the iterable, resulting in
-- a flat, un-nested iterable containing all mapping results.
-- <br><br>Example: `flatmap({1, 2, 3} function(x) return {x, x})` yields 1, 1, 2, 2, 3, 3.
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

-- Returns an iterator function yielding at most the specified `amount` of elements
-- from the original iterable.
-- <br><br> Example: `limit({3, 5, 7}, 1)` yields 3.
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

-- Returns an iterator function skipping the specified `amount` of elements
-- at the start of the iterable, then yields all remaining elements.
-- <br><br> Example: `skip({3, 5, 7}, 1)` yields 5 and 7.
---@generic T
---@param iterable Iterable<T>
---@param amount number
---@return Iterator<T>
local function skip(iterable, amount)
    local iterator = iter(iterable)
    local skipped = false
    return function()
        if skipped then
            return iterator()
        end

        local value
        for _ = 1, amount do
            value = iterator()
            if value == nil then
                return nil
            end
        end

        skipped = true
        return iterator()
    end
end

-- Calls the specified `consumer` function for each element yielded by the iterable.
-- <br><br> **Note**: this is a **terminal operation**, returning nothing.
-- <br><br> Example: `each({1, 2, 3}, print)` prints 1, then 2, then 3.
---@generic T
---@param iterable Iterable<T>
---@param consumer fun(T): nil
local function each(iterable, consumer)
    for value in iter(iterable) do
        consumer(value)
    end
end

-- Aggregates all elements yielded by the iterable into a single result using
-- the provided `seed` and the `binary_operation` aggregator function.
-- <br><br> **Note**: this is a **terminal operation**.
-- <br><br> Example: `reduce({1, 2, 3}, 0, operators.add)` returns 6.
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

-- Calls the `consumer` function for each element yielded by the iterable, then
-- yields that element, allowing further iterator chaining. This is mostly useful
-- for debugging complex iterator chains without collecting them.
-- <br><br> Note that, unlike the `each` iterator, this is not a terminal operation.
-- <br><br> Example:
-- ```lua
-- local increment = partial(operators.add, 1)
-- local result = collect(peek(map({1, 2, 3}, increment), print))
-- -- prints 2, then 3, then 4
-- -- result itself is equal to {2, 3, 4}
-- ```
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

-- Returns an iterator function that only yields distinct (unique) elements from the
-- original iterable.
-- <br><br>Example: `distinct{1, 3, 2, 3, 5, 1}` yields 1, 3, 2 and 5.
---@nodiscard
---@generic T
---@param iterable Iterable<T>
---@return Iterable<T>
local function distinct(iterable)
    local seen = {}
    return peek(
        filter(iterable, function(x) return seen[x] == nil end),
        function(x) seen[x] = true end
    )
end

-- Reduces the arity (amount of arguments) of a function by returning a closure
-- calling the specified function with all specified arguments pre-applied.
-- <br><br>Example:
-- ```lua
-- function add(x, y) return x + y end
-- increment = partial(add, 1)
-- print(increment(2))  -- 3
-- ```
---@nodiscard
---@generic T
---@param fn fun(...): T
---@return fun(...): T
local function partial(fn, ...)
    local args = { ... }
    local n = select('#', ...)
    return function(...)
        return fn(table.unpack(args, 1, n), ...)
    end
end

-- Returns `true` if any element yielded by the iterable matches the specified
-- predicate function, else returns `false`.
-- <br><br> Note: returns `false` for empty iterables.
-- <br><br>Example: `any({1, 3, 5, 4}, function(x) return x > 4 end)` returns `true`.
---@generic T
---@param iterable Iterable<T>
---@param predicate (fun(T): boolean)?
---@return boolean
local function any(iterable, predicate)
    local filtered = filter(iterable, predicate)
    local mapped = map(filtered, operators.truthy)
    return mapped() or false
end

-- Returns `true` if all elements yielded by the iterable match the specified
-- predicate function, else returns `false`.
-- <br><br> Note: returns `true` for empty iterables.
-- <br><br>Example: `all({1, 3, -1, 4}, function(x) return x > 0 end)` returns `false`.
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

---@see collect
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
-- Provides implementations for several useful collectors that can be used
-- in conjunction with the `collect` or `stream.collect` functions to aggregate
-- elements into a single result.
local collectors = {

    -- Collects an iterable to a table.
    -- <br><br>Example: `collect(range(1, 5), collectors.table)` results in `{1, 2, 3, 4, 5}`.
    table = function()
        local value = {}
        return {
            collect = function(self, x) table.insert(value, x) end,
            get = function(self) return value end
        }
    end,

    -- Returns the sum of all numbers yielded by a numeric iterable.
    -- <br><br>Example: `collect(range(1, 5), collectors.sum)` results in 15.
    sum = _create_collector(operators.add, 0),

    -- Returns the count of elements yielded by an iterable.
    -- <br><br>Example: `collect({1, 2, 3}, collectors.count)` results in 3.
    count = _create_collector(partial(operators.add, 1), 0),

    -- Returns the smallest number yielded by a numeric iterable.
    -- <br><br>Note: returns `nil` for empty iterables.
    -- <br><br>Example: `collect({1, -1, 3}, collectors.min)` results in -1.
    min = _create_collector(math.min),

    -- Returns the largest number yielded by a numeric iterable.
    -- <br><br>Note: returns `nil` for empty iterables.
    -- <br><br>Example: `collect({1, -1, 3}, collectors.max)` results in 3.
    max = _create_collector(math.max),

    -- Returns a collector that joins all strings yielded by an iterable into
    -- a single string, optionally delimited by the specified string delimiter.
    -- <br><br>Note: although this is actually a collector *factory* function, it can
    -- also be used as a collector without being called first.
    -- <br><br>Examples:
    -- * 1. `collect({"a", "d", "e"}, collectors.join)` results in `"ade"`.
    -- * 2. `collect({"a", "b", "c"}, collectors.join(";"))` results in `"a;b;c"`.
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

            -- default collector table.
            -- Allows joining a stream also with the syntax `stream:collect(collectors.join)`
            -- instead of `stream:collect(collectors.join())`
            __index = join(),
        })
        return collector --[[@as fun(): CollectorInstance<string, string>]]
    end,

    -- Returns the last element yielded by an iterable.
    -- <br><br>Note: returns `nil` for empty iterables.
    -- <br><br>Example: `collect({3, 5, 2}, collectors.last)` results in 2.
    last = function()
        local value = nil
        return {
            collect = function(self, x) value = x end,
            get = function(self) return value end
        }
    end,

    -- Returns the average of all numbers yielded by a numeric iterable.
    -- <br><br>Note: returns `nil` for empty iterables.
    -- <br><br>Example: `collect(range(1, 6), collectors.average)` results in `3.5`.
    average = function()
        local sum = 0
        local count = 0
        return {
            collect = function(self, x)
                sum = sum + x
                count = count + 1
            end,
            get = function(self)
                if count == 0 then
                    return nil
                end
                return sum / count
            end
        }
    end,
}

-- Collects the iterable to a single aggregated result using the specified collector,
-- or to a table, if no collector is specified.
-- <br><br>**Note**: this is a **terminal operation**.
-- <br><br>**Warning**: collecting an infinite iterable will result in an infinite loop.
-- <br><br>A collector is a table with this interface: `{collect = (item) -> nil, get = () -> aggregate} `.
-- <br><br> Examples:
-- * 1. `collect(range(1, 5))` returns `{1, 2, 3, 4, 5}`.
-- * 2. `collect({"a", "b", "c"}, collectors.join(";"))` returns `"a;b;c"`.
--
---@see collectors
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

-- Returns the count of elements yielded by an iterable.
-- <br><br>Equivalent to `collect(iterable, collectors.count)`.
---@param iterable Iterable<any>
---@return number
local count = function(iterable) return collect(iterable, collectors.count) end

-- Returns the sum of all numbers yielded by a numeric iterable.
-- <br><br>Equivalent to `collect(iterable, collectors.sum)`.
---@param iterable Iterable<number>
---@return number
local sum = function(iterable) return collect(iterable, collectors.sum) end

-- Returns the smallest number yielded by a numeric iterable.
-- <br><br>Equivalent to `collect(iterable, collectors.min)`.
---@param iterable Iterable<number>
---@return number
local min = function(iterable) return collect(iterable, collectors.min) end

-- Returns the largest number yielded by a numeric iterable.
-- <br><br>Equivalent to `collect(iterable, collectors.max)`.
---@param iterable Iterable<number>
---@return number
local max = function(iterable) return collect(iterable, collectors.max) end

-- Returns the average of all numbers yielded by a numeric iterable.
-- <br><br>Equivalent to `collect(iterable, collectors.average)`.
---@param iterable Iterable<number>
---@return number
local average = function(iterable) return collect(iterable, collectors.average) end

-- Returns a collector that joins all strings yielded by an iterable into
-- a single string, optionally delimited by the specified string delimiter.
-- <br><br>Equivalent to `collect(iterable, collectors.join(delimiter))`.
---@generic T
---@param iterable Iterable<T>
---@param delimiter string?
---@return string
local join = function(iterable, delimiter) return collect(iterable, collectors.join(delimiter)) end

-- Returns an iterator function that yields items from all iterables provided.
-- <br><br>Example:
-- ```lua
-- local infinite_iter = function() return 0 end
-- for x, y, z in zip(range(1, 5), {"a", "b", "c"}, infinite_iter) do
--     print(x, y, z)
--     -- prints 1, "a", 0
--     -- then prints 2, "b", 0
--     -- then prints 3, "c", 0
-- end
-- ```
---@nodiscard
---@vararg Iterable
---@return Iterator<[any...]>
local function zip(...)
    local iterators = collect(map({...}, iter))
    local amount = #iterators
    return function()
        while true do
            local values = collect(map(iterators, operators.call))

            -- preserves nils
            local value_iter = map(range(1, amount), function(x) return {values[x]} end)
            if any(value_iter, function(x) return x[1] == nil end) then
                return nil
            end
            return table.unpack(values)
        end
    end
end

-- Returns an iterator function yielding tables containing the multivalues yielded
-- by the original iterable.
-- <br><br>Example: `multicollect(zip({1, 2, 3}, {3, 5, 7}))` yields `{1, 3}`, `{2, 5}` and `{3, 7}`.
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

-- Returns an infinite iterator function repeatedly yielding elements from the iterable,
-- or a specified amount of times if the optional `repeats` argument is specified.
-- <br><br>**Note**: eagerly collects the original iterable.
-- <br><br>Example: `cycle{1, 2}` yields 1, then 2, then 1, then 2...
---@generic T
---@param iterable Iterable<T>
---@param repeats number?
---@return Iterator<T>
local function cycle(iterable, repeats)
    local list = collect(iterable)
    local infinite = function() return 0 end
    local mapped = flatmap(infinite, function(_) return iter(list) end)
    return repeats and limit(mapped, repeats * #list) or mapped
end

-- Returns an iterator function yielding elements from the iterable in reverse order.
-- <br><br>**Note**: eagerly collects the original iterable.
-- <br><br>Example: `reversed{1, 2, 3}` yields 3, then 2, then 1.
---@generic T
---@param iterable Iterable<T>
---@return Iterator<T>
local function reversed(iterable)
    local list = collect(iterable)
    return map(range(#list, 1, -1), function(index) return list[index] end)
end

-- `Stream` class, providing a fluent interface for lazily-computed iterator-chains.
local Stream = {}

-- Creates a `Stream` object from the specified iterable and returns it. This
-- object provides a fluent interface for lazily-computed iterator-chains.
---@nodiscard
---@generic T
---@param iterable Iterable<T>?
---@return Stream<T>
function Stream.from(iterable)

    -- A `Stream` object, providing a fluent interface for lazily-computed iterator-chains.
    ---@generic T
    ---@class Stream<T>
    local stream = {}

    local iterator = iter(iterable)

    -- Allows applying an arbitrary iterator transformation to this stream to
    -- accomodate for iterator transformations not provided by the interface of
    -- the `Stream` class.
    -- <br><br>Example:
    -- ```lua
    -- local is_positive = function(x) return x > 0 end
    -- local iter_mapper = function(it) return takewhile(it, is_positive) end
    -- stream:apply(iter_mapper):collect()
    -- ```
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param mapper fun(iterator: Iterator<T>): Iterator<T>
    ---@return Stream<T>
    function stream:apply(mapper)
        iterator = mapper(iterator)
        return self
    end

    -- Changes the stream to only yield distinct (unique) elements.
    -- <br><br>Example: `stream{1, 2, 3, 2, 1}:distinct():count()` returns 3.
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@return Stream<T>
    function stream:distinct()
        iterator = distinct(iterator)
        return self
    end

    -- Filters the stream using the specified predicate, dropping all elements
    -- that do not test true, then returns the stream.
    -- <br><br>Example: `stream{0, 1, 0, 2}:filter(function(x) return x ~= 0 end):collect()` results in `{1, 2}`.
    --
    ---@see filter
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param predicate (fun(T): boolean)?
    ---@return Stream<T>
    function stream:filter(predicate)
        iterator = filter(iterator, predicate)
        return self
    end

    -- Maps each element in the stream to the result of applying the mapper function
    -- to the element, then returns the stream.
    -- <br><br>Example: `stream{1, 2, 3}:map(function(x) return x + 1 end):collect()` results in `{2, 3, 4}`.
    --
    ---@see map
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

    -- Applies the mapper to each element in the stream, then includes the yielded
    -- result iterables in the stream in order, then returns the stream.
    -- <br><br>Example: `stream{1, 2, 3}:flatmap(function(x) return {x, x} end):collect()` results in `{1, 1, 2, 2, 3, 3}`.
    --
    ---@see flatmap
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

    -- Limits the amount of elements yielded by the stream to at most the specified
    -- `amount`, then returns the stream.
    -- <br><br>Example: `Stream.range(1, 5):limit(3):collect()` results in `{1, 2, 3}`.
    --
    ---@see limit
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param amount number
    ---@return Stream<T>
    function stream:limit(amount)
        iterator = limit(iterator, amount)
        return self
    end

    -- Skips the specified `amount` of elements from the start of the stream, then
    -- returns the stream.
    -- <br><br>Example: `Stream.range(1, 5):skip(3):collect()` results in `{4, 5}`.
    --
    ---@see skip
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param amount number
    ---@return Stream<T>
    function stream:skip(amount)
        iterator = skip(iterator, amount)
        return self
    end

    -- Calls the `consumer` function for each element yielded by the stream, then
    -- yields that element, allowing further iterator chaining. This is mostly useful
    -- for debugging complex iterator chains without collecting them.
    -- <br><br> Note that, unlike the `stream:each` method, this is not a terminal operation.
    -- <br><br> Example:
    -- ```lua
    -- local increment = partial(operators.add, 1)
    -- local result = stream{1, 2, 3}:map(increment):peek(print):collect()
    -- -- prints 2, then 3, then 4
    -- -- result itself is equal to {2, 3, 4}
    -- ```
    --
    ---@see peek
    ---@generic T
    ---@param self Stream<T>
    ---@param consumer fun(any)
    ---@return Stream<T>
    function stream:peek(consumer)
        iterator = peek(iterator, consumer)
        return self
    end

    -- Calls the `consumer` function for each element yielded by the stream.
    -- <br><br>**Note**: this is a **terminal operation**, returning nothing.
    -- <br><br>Example: `stream{1, 2, 3}:each(print)` prints 1, then 2, then 3.
    --
    ---@see each
    ---@param consumer fun(any)
    ---@return nil
    function stream:each(consumer)
        each(iterator, consumer)
    end

    -- Returns `true` if all elements yielded by the stream match the specified
    -- predicate function, else returns `false`.
    -- <br><br> Note: returns `true` for empty streams.
    -- <br><br>**Note**: this is a **terminal operation**.
    -- <br><br>Example: `stream{1, -1, 2}:all(function(x) return x > 0 end)` returns `false`.
    --
    ---@see all
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param predicate (fun(T): boolean)?
    ---@return boolean
    function stream:all(predicate)
        return all(iterator, predicate)
    end

    -- Returns `true` if any element yielded by the stream matches the specified
    -- predicate function, else returns `false`.
    -- <br><br> Note: returns `false` for empty streams.
    -- <br><br>**Note**: this is a **terminal operation**.
    -- <br><br>Example: `stream{0, 1, -2}:any(function(x) return x > 0 end)` returns `true`.
    --
    ---@see all
    ---@nodiscard
    ---@generic T
    ---@param self Stream<T>
    ---@param predicate (fun(T): boolean)?
    ---@return boolean
    function stream:any(predicate)
        return any(iterator, predicate)
    end

    -- Collects the stream to a single aggregated result using the specified collector,
    -- or to a table, if no collector is specified.
    -- <br><br>**Note**: this is a **terminal operation**.
    -- <br><br>**Warning**: collecting an infinite stream will result in an infinite loop.
    -- <br><br>Examples:
    -- * 1. `Stream.range(1, 5):collect()` returns `{1, 2, 3, 4, 5}`.
    -- * 2. `stream{"a", "b", "c"}:collect(collectors.join)` returns `"abc"`.
    --
    ---@see collect
    ---@generic T
    ---@generic S
    ---@param self Stream<T>
    ---@param collector Collector<T, S>?
    ---@return S
    function stream:collect(collector)
        return collect(iterator, collector)
    end

    -- Returns the count of elements yielded by the stream.
    -- <br><br>**Note**: this is a **terminal operation**.
    -- <br><br>Example: `stream{1, 3, 5}:count()` returns 3.
    --
    ---@see collectors.count
    ---@generic T
    ---@param self Stream<T>
    ---@return number
    function stream:count()
        return self:collect(collectors.count)
    end

    -- Aggregates all elements yielded by the stream into a single result using
    -- the provided `seed` and the `binary_operation` aggregator function.
    -- <br><br>**Note**: this is a **terminal operation**.
    -- <br><br>Example: `stream{1, 2, 3}:reduce(0, operators.add)` returns 6.
    --
    ---@see reduce
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

-- Returns a stream yielding numbers from `start` to `stop` (including both ends).
-- <br>An optional third `step` parameter can be provided to control the interval
-- between the yielded numbers.
-- <br><br>**Warning**: produces an infinite iterator when `step` is 0 and `start` != `stop`.
-- <br><br>Example: `Stream.range(1, 5):collect()` results in `{1, 2, 3, 4, 5}`.
---@see range
---@param start number
---@param stop number
---@param step number?
---@return Stream<number>
function Stream.range(start, stop, step)
    return Stream.from(range(start, stop, step))
end

local stream = Stream.from

-- Concatenates all provided iterables into a single, un-nested stream yielding
-- the elements of all iterables in sequence, then returns that stream.
-- <br><br>Example: `Stream.concat(range(1, 3), {2}, stream{5, 4}):collect()` results in `{1, 2, 3, 2, 5, 4}`.
---@generic T
---@vararg Iterable<T>
---@return Stream<T>
function Stream.concat(...)
    local streams = {...}
    return stream(flatmap(streams, iter))
end

---@generic T
---@alias IteratorMapper fun(iterable: Iterable<T>): Iterator<T>
---@class Gatherers
---@field batch fun(batch_size: number): IteratorMapper
---@field window fun(window_size: number): IteratorMapper
-- Provides implementations for stream gatherers that can be used to transform elements
-- yielded by a stream into item collections via the `stream:apply` method.
-- <br><br>Example: `Stream.range(1, 6):apply(gatherers.batch(2)):collect()` results in `{{1, 2}, {3, 4} {5, 6}}`.
local gatherers = {

    -- Can be used to gather items yielded from an iterable into batches of a specified size.
    -- <br><br>Example: `Stream.range(1, 6):apply(gatherers.batch(2)):collect()` results in `{{1, 2}, {3, 4} {5, 6}}`.
    -- <br><br>Note: this is a factory function for an iterator function factory.
    batch = function (batch_size)
        if batch_size <= 0 then
            error("Specified batch size should be greater than zero!", 2)
        end

        -- iterator function factory
        return function(iterable)
            local iterator = iter(iterable)

            -- the actual iterator function
            return function()
                local values_ = {}
                each(range(1, batch_size), function(_)
                    local value = iterator()
                    table.insert(values_, value)
                end)
                if values_[1] == nil then
                    return nil
                end
                return values_
            end
        end
    end,

    -- Can be used to gather items yielded from an iterable into a moving window (table) of a specified size.
    -- <br><br>Example: `Stream.range(1, 4):apply(gatherers.window(3)):collect()`
    -- results in `{{1}, {1, 2}, {1, 2, 3}, {2, 3, 4}}`.
    -- <br><br>Note: this is a factory function for an iterator function factory.
    window = function(window_size)
        if window_size <= 0 then
            error("Specified window size should be greater than zero!", 2)
        end

        local first = operators.first

        local function create_collector()
            local value = nil
            return {
                collect = function(x) value = x end,
                get = function() return value end
            }
        end

        -- iterator function factory
        return function(iterable)
            local collectors_ = collect(map(range(1, window_size), create_collector))
            local collector_iter = cycle(collectors_)
            local iterator = peek(iterable, function(x) collector_iter().collect(x) end)

            -- the actual iterator function
            return map(iterator, function ()
                local limited_collectors = limit(collector_iter, window_size)
                local values_ = map(limited_collectors, function(x) return {x.get()} end)
                local filtered_values = map(filter(values_, first), first)
                return collect(filtered_values)
            end)
        end
    end
}

return {
    iter = iter,
    range = range,
    keys = keys,
    values = values,
    items = items,
    cycle = cycle,
    reversed = reversed,
    distinct = distinct,
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
    count = count,
    sum = sum,
    min = min,
    max = max,
    average = average,
    join = join,
    stream = stream,
    Stream = Stream,
    collectors = collectors,
    gatherers = gatherers,
    operators = operators,
}
