# stream.lua

This single-file library is an iterator-chaining library implementing common functional programming patterns such as lazily-computed iterators `map`, `filter`, and `reduce`, a `Stream` class providing iterator-chaining via a fluent interface, and a number of [function utilities](#utilities).

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
local mapped = fn.stream{2, 3, 4, 7}
    :filter(function(x) return x % 2 == 0 end)
    :map(function(x) return x ^ 2 end)
    :collect()  -- {4, 16}
```

The iterator functions can also be used stand-alone and can be iterated over using a `for-each` loop:
```lua
local fn = require "stream"
for v in fn.filter({2, 0, -3, -1, 5}, function(x) return math.abs(x) < 3 end) do
    print(v)  -- {2, 0, -1}
end
```

Note that the values of all non-terminal iterator functions provided are lazily-computed, meaning that they are only computed on demand:

```lua
local fn = require "stream"
local op = fn.operators
local greater_than_two = fn.partial(op.lt, 2)
local stream = fn.stream{2, 4, 1, 5}:filter(greater_than_two) -- eagerly computes nothing at all
local first_value = stream.iterator() -- gets first value in stream that is greater than 2 ==> 4
local second_value = stream.iterator() -- gets second value... ==> 5 
```

This means, that all iterator functions can also be nested (similar to Python), e.g. `map(f, filter({1, 2, 3}, f2))`.

An added benefit of using the library is that performance seems to be better than the traditional for-loop approach, although this is not the focus or main benefit of this library and as such is not guaranteed.

## Getting started

To use the library, download the [stream.lua](stream.lua) file and include it in your project, then require it in your source code and you are all set up:

```lua
local fn = require "stream"
```

## Documentation

### Type syntax used and definitions

- An `Iterator` is a stateful function that can be called repeatedly, yielding different elements and finally `nil`, such that it can be used in a for-each loop, e.g. `for x in iter({1, 2, 3}) do`.
- An `Iterable` is the type union `Iterator | table | Stream | string`, which means it is either an `Iterator`, a `table`, a `Stream` or a `string`.
- Function arguments are specified inside the brackets, and return type is specified after the colon (e.g. `iter(Iterable): Iterator` takes an `Iterable` and returns an `Iterator`.)
- Functions supplied as arguments are typed like Javascript: `any => boolean` is a function that takes one argument of type `any` and returns a `boolean`.

### Single iterator functions provided

- `iter(Iterable<T>): Iterator<T>`: constructs an `Iterator` from a table or string. If the argument isn't a table or string, this function assumes it must be an iterator function of type `() => T`. Note that a stateless iterator function (e.g. `function() return 1 end`) results in infinite iterators.
- `range(start: int, stop: int, step: int?): Iterator<int>`: constructs a numeric `Iterator` yielding numbers from start to stop (including both ends). Takes an optional `step` parameter.
- `distinct(Iterable<T>): Iterable<T>`: yields all elements of the iterator, skipping elements that were already yielded.
- `cycle(Iterable<T>): Iterable<T>`: yields all elements of the iterator, repeatedly and infinitely. Note that this collects the iterator eagerly.
- `reversed(Iterable<T>): Iterable<T>`: yields all elements of the iterator in reverse order. Note that this collects the iterator eagerly.
- `filter(Iterable<T>, T => boolean): Iterator<T>`: yields all elements for which the supplied predicate function returns `true`. Note: omitting the optional predicate function yields all truthy elements.
- `map(Iterator<T>, T => S): Iterator<S>`: applies the supplied mapping function to each element and yields them.
- `reduce(Iterable<T>, T, (T, T) => T): T`: applies the supplied combining (bi-operator) function to all adjacent element pairs in the iterable, starting with the specified seed, then returns the result. This is a terminal operation.
- `flatmap(Iterable<T>, T => table<S>): Iterator<S>`: applies the supplied function to each element and flattens the resulting iterator of tables to a flat iterator containing all elements.
- `takewhile(Iterable<T>, T => boolean): Iterator<T>`: yields elements from the iterable until the supplied predicate function fails for an element for the first time, then stops yielding. 
- `dropwhile(Iterable<T>, T => boolean): Iterator<T>`: drops elements from the iterable until the supplied predicate function succeeds for an element for the first time, then yields all remaining elements in the iterable.
- `limit(Iterable<T>, int): Iterator<T>`: limits the iterator to yield at most the specified maximum number of elements.
- `skip(Iterable<T>, int): Iterator<T>`: skips the specified number of elements at the beginning of the iterator.
- `each(Iterable<T>, any => void): void`: applies the supplied consumer function to each element in the `Iterator`. This is a terminal operation.
- `collect(Iterable<T>): table<T>`: collects all elements of the iterator into a table. This is a terminal operation.
- `collect(Iterable<T>, collector): table<T>`: collects all elements of the iterator into an arbitrary format specified by the collector. Collectors provided by `stream.lua` are available under `collectors` (documented [here](#collectors)). This is a terminal operation.
- `any(Iterable<T>, T => boolean): boolean`: returns `true` if any element in the iterable matches the supplied predicate function. This is a terminal operation.
- `all(Iterable<T>, T => boolean): boolean`: returns `true` if all elements in the iterable match the supplied predicate function. This is a terminal operation.

Some standalone collector functions (all of which being terminal operations) are also provided: `sum`, `count`, `average`, `min`, `max` and `join`.

#### Object iterators

The iterator functions provided in this library cannot iterate objects directly, or use the built-in `pairs` function. Instead, the following iterators are provided to traverse objects:
- `keys(object): Iterable<string>`: yields all keys of the specified object table. Yields numbers when an array table is used as input.
- `values(object): Iterable`: yields all values (not keys) of the specified object table.
- `items(object): Iterable<{string, any}>`: Yields key-value pairs inside a two element table of the format `{key, value}` for all attributes in the specified object table. Yields `{index, value}` pairs if an array table is used as input.

Note: the object is traversed in random order.

### Stream objects

A `Stream` object, which allows iterator chaining, can be constructed using the following constructors:
- `Stream.from(Iterable<T>): Stream<T>`: constructs a `Stream` object from the specified iterable.
- `Stream.range(start: int, stop: int, step: int?): Stream`: constructs a `Stream` object containing the numbers between the specified start and stop numbers (both ends included). The step between each number can optionally be specified and defaults to 1.
- `Stream.concat(Iterable<T>...)`: constructs a `Stream` object from any number of iterables.

`Stream` objects provide the same iterator interface in chainable format: `filter`, `map`, `reduce`, `flatmap`, `peek`, `each`, `limit`, `skip`, `count`, `all`, and `collect` (see more detailed documentation on each above).

Additionally, `Stream` objects expose the `apply` method, which can be used to apply arbitrary iterator transformations to the stream, e.g. `gatherers.batch`, `takewhile` or custom iterators.

Example iterator chaining:

```lua
local fn = require "stream"
local max = fn.stream{1, 5, 283428, 104, -10399232, 293428}
    :map(math.abs)
    :reduce(0, math.max)  -- -10399232
```

Streams can also be traversed using generic `for-each` loops:

```lua
local fn = require "stream"
for x in fn.stream{1, 5, 283428, 104, -10399232, 293428}:map(math.abs) do
    print(x)
end
```

### Iterable aggregators

Implementations for several common aggregators are included in the library as `collectors` and `gatherers`. 

#### Collectors

Collectors can be used with the `collect` or `stream:collect` functions to traverse the entire stream and aggregate all elements into an aggregate result, such as a table or a number.

Provided default collectors are available under `collectors` and are:
- `table`: collects all elements yielded by an iterable into a table.
- `count`: counts the number of elements yielded by an iterable.
- `sum`: sums all numbers yielded by a numeric iterable.
- `average`: returns the average of all numbers yielded by a numeric iterable.
- `min`: returns the smallest of all numbers yielded by a numeric iterable.
- `max`: returns the largest of all numbers yielded by a numeric iterable.
- `join(delimiter: string?)`: joins all strings yielded by a string iterable into a single string (optionally delimited with the specified delimiter), then returns the joined string.
- `last`: returns the last element yielded by an iterable. (note that the first element can be retrieved simply by calling an iterator function once: `iter(something)()`)

Some of the most useful of the provided collectors are also provided as standalone functions (equivalent to `collect(collector)`), these being: `sum`, `count`, `average`, `min`, `max` and `join`.

Example collector usage:

```lua
local fn = require "stream"
local stream = fn.Stream.range(1, 5)
local sum = stream:collect(fn.collectors.sum)
print(sum)  -- 15
```

Custom collectors can also be implemented by implementing an argument-less factory function returning a new table with `collect` and `get` methods. The following example implements a custom collector multiplying all numbers in the iterable with each other:

```lua
local function custom_collector()
    local value = 1
    return {
        collect = function(self, element) value * element return nil end,
        get = function(self) return value end
    }
end

local fn = require "stream"
local stream = fn.Stream.range(1, 5)
local result = stream:collect(custom_collector)
print(result)  -- 120
```

#### Gatherers

Gatherers can be used with the `stream:apply` method to aggregate elements in the stream into intermediate aggregate results during iteration - they are not termination operations, but allow implementations for e.g. element batching or moving windows.

Provided default gatherers aer available under `gatherers` and are:
- `batch(batch_size): Iterable<T> => Iterable<table<T>>`: returns an iterable mapper function that aggregates elements from the original iterable, yielding batches of the specified size (in table form).
- `window(window_size): Iterable<T> => Iterable<table<T>>`: returns an iterable mapper function that aggregates elements from the original iterable, yielding sliding windows of the specified size (in table form). Note that the windows for the first elements may be smaller than the specified size, while elements are still being aggregated into windows (if required, these smaller windows can be filtered out with a `dropwhile` statement).

Example:

```lua
local fn = require "stream"
local stream = fn.Stream.range(1, 7):apply(fn.gatherers.batch(3)):collect()
-- results in {{1, 2, 3}, {4, 5, 6}, {7}}
```

### Utilities

#### zip

The provided `zip` function allows combining two `Iterable` objects into a single `Iterator` yielding pairs sourced from both iterables, for example:

```lua
local fn = require "stream"
local numbers = {1, 2, 3}
local chars = {"a", "b", "c"}
for number, char in fn.zip(numbers, chars) do
    print(number, char) -- prints (1, "a"), then (2, "b"), then (3, "c")
end
```

Note that the `Iterator` returned by the `zip` function stops yielding element pairs upon exhaustion of the shortest of the two iterables.

Note also that the multivalues yielded by the `zip` iterator do not get handled by the other iterator factory functions in this library. Instead, they only consider the first value of each multivalue: `collect(zip({1, 2}, {2, 3})) === {1, 2}`. To use `zip` in an extended iterator chain, use the `multicollect` function, which converts the multivalues into tables:

```lua
local fn = require "stream"
local zipped = fn.multicollect(fn.zip({1, 2, 3}, {"a", "b", "c"}))
fn.each(function(x) print(x[1], x[2]) end)
```

A practical example of combined `zip` and `multicollect` usage:

```lua
-- adds all numbers from the first table for which the respective element from the second table is true.
local fn = require "stream"
local op = fn.operators
local zipped = fn.multicollect(fn.zip({1, 2, 3}, {true, false, true}))
fn.stream(zipped):filter(op.second):map(op.first):reduce(0, op.add)  -- prints 4
```

#### partial

A utility function called `partial` is also provided, which can be used to reduce the arity (amount of arguments) of a function: `partial(function, args...)`, for example:

```lua
local fn = require "stream"
local add = fn.operators.add
local increment = fn.partial(add, 1)
local mapped = fn.stream{1, 2, 3}:map(increment):collect()  -- {2, 3, 4}
```

#### operators

All built-in Lua operators are provided in function form and exposed under `operators`.

Example:

```lua
local fn = require "stream"
print(fn.operators.add(1, 2)) -- 3
```

## Run tests

Tests for this library are written using the [luaunit](https://github.com/bluebird75/luaunit) and [luacov](https://github.com/lunarmodules/luacov) modules. Install them with `luarocks` using the following commands:

```
luarocks install luaunit
luarocks install luacov
```

Run tests using the following command:

```bat
lua tests/run_tests.lua
```

To check the test coverage in HTML format, run the following commands:

```bat
lua -lluacov tests/run_tests.lua
luacov
start luacov.report.html
```

## Lua version

Written for Lua 5.1, but should also work for all other versions of Lua.

## License

Licensed under the [MIT license](LICENSE).

## Contact

For bug reports and feature requests, please raise a Github issue. Feel free to submit pull requests to solve those issues. For anything else, please contact the author of this library, Richard Baltrusch, via email: [richard@baltrusch.net](mailto:richard@baltrusch.net).
