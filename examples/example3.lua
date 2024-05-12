local fn = require "stream"
local function add(x, y) return x + y end
local mapped = fn.Stream.from({1, 2, 3}):map(fn.partial(add, 1)):collect()  -- {2, 3, 4}
fn.each(mapped, print)

local fn = require "stream"
local max = fn.Stream.from({1, 5, 283428, 104, -10399232, 293428})
    :map(math.abs)
    :reduce(0, math.max)  -- 10399232
print(max)

local fn = require "stream"
for v in fn.filter({2, 0, -3, -1, 5}, function(x) return math.abs(x) < 3 end) do
    print(v)  -- {2, 0, -1}
end

local fn = require "stream"
local mapped = fn.Stream.from({2, 3, 4, 7})
    :filter(function(x) return x % 2 == 0 end)
    :map(function(x) return x ^ 2 end)
    :collect()  -- {4, 16}
fn.each(mapped, print)

