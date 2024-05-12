local fn = require "stream"

local t = {}
for index = 0, 1000000 do
    table.insert(t, index)
end

local res = fn.Stream.from(t)
    :filter(function(x) return x % 2 == 0 end)
    :limit(10000)
    :flatmap(function(x) return {x, x ^ 2} end)
    :reduce(0, function(x, y) return x + y end)
print(res)

print(fn.Stream.from({1, 5, 283428, 104, -10399232, 293428}):map(math.abs):reduce(0, math.max))
print(fn.Stream.from("abc"):map(function(x) return x .. x end):reduce("", function(x, y) return x .. "," .. y end))

local function add(x, y) return x + y end
print(fn.Stream.from({1, 2, 3}):map(fn.partial(add, 1)):each(print))

for v in fn.Stream.range(0, 100000)
    :filter(function(x) return x % 2 == 0 end)
    :map(function(x) return x ^ 2 end)
do
    -- print(v)
end
