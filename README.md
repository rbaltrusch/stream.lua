# Stream.lua

This small, single-file library is an iterator-chaining library implementing common functional programming patterns such as `map`, `filter`, and `reduce`:

For example, instead of the traditional approach using a for-loop with an if-statement to aggregate transformed data:

```lua
local source = {1, 3, 5}
local mapped = {}
for _, v in ipairs(source) do
    if v % 2 == 0 then
        table.insert(t, v ^ 2)
    end
end
```

We can instead use the more succinct iterator-chaining the library provides:

```lua
local fn = require "stream"
local mapped = fn.Stream.from({2, 3, 4, 7})
    :filter(function(x) return x % 2 == 0 end)
    :map(function(x) return x ^ 2 end)
    :collect()  -- {4, 16}
```

The iterator-functions can also be used stand-alone and can be iterated over using a `for-each` loop:
```lua
local fn = require "stream"
for v in fn.filter({2, 0, -3, -1, 5}, function(x) return math.abs(x) < 3 end) do
    print(v)  -- {2, 0, -1}
end
```

This means, that all iterator functions can also be nested (similar to Python), e.g. `map(f, filter({1, 2, 3}, f2))`.

An added benefit of using the library is that performance seems to be better than the traditional for-loop approach, although this is not the focus or main benefit of this library and as such is not guaranteed.

## Documentation

### Type syntax used and definitions

- An `Iterator` is a stateful function that can be called repeatedly, yielding different elements and finally `nil`, such that it can be used in a for-each loop, e.g. `for x in iter({1, 2, 3}) do`.
- An `Iterable` is the type union `Iterator | table | string`, which means it is either an `Iterator`, a `table`, or a `string`.
- Function arguments are specified inside the brackets, and return type is specified after the colon (e.g. `iter(Iterable): Iterator` takes an `Iterable` and returns an `Iterator`.)
- Functions supplied as arguments are typed like Javascript: `any => boolean` is a function that takes one argument of type `any` and returns a `boolean`.

### Single iterator functions provided

- `iter(Iterable): Iterator`: turns a table or string into an iterator. If the argument isn't a table, this function assumes it must be an iterator function.
- `filter(Iterable, any => boolean): Iterator`: yields all elements for which the supplied predicate function returns `true`.
- `map(Iterator | table, any => any): Iterator`: applies the supplied mapping function to each element and yields them.
- `flatmap(Iterable, any => table<X>): Iterator<X>`: applies the supplied function to each element and flattens the resulting iterator of tables to a flat iterator containing all elements.
- `limit(Iterable, int): Iterator`: limits the iterator to yield at most the specified maximum number of elements.
- `each(Iterable, any => void): void`: applies the supplied consumer function to each element in the `Iterator`. This is a terminal operation.
- `collect(Iterable): table`: collects all elements of the iterator into a table. This is a terminal operation

### Stream objects

A `Stream` object, which allows iterator chaining, can be constructed using the following constructors:
- `Stream.from(Iterable): Stream`: constructs a `Stream` object from the specified iterable.
- `Stream.range(start: int, stop: int, step: int?): Stream`: constructs a `Stream` object containing the numbers between the specified start and stop numbers (both ends included). The step between each number can optionally be specified and defaults to 1.

`Stream` objects provide the same iterator interface in chainable format: `iter`, `filter`, `map`, `flatmap`, `each`, `limit`, and `collect` (see more detailed documentation on each above).

Example iterator chaining:

```lua
local fn = require "stream"
local max = fn.Stream.from({1, 5, 283428, 104, -10399232, 293428})
    :map(math.abs)
    :reduce(0, math.max)  -- -10399232
```

### Utilities

A utility function called `partial` is also provided, which can be used to reduce the arity (amount of arguments) of a function: `partial(function, args...)`, for example:

```lua
local fn = require "stream"
local function add(x, y) return x + y end
local mapped = fn.Stream.from({1, 2, 3}):map(fn.partial(add, 1)):collect()  -- {2, 3, 4}
```
