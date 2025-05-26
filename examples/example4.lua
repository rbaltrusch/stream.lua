local fn = require "stream"
local batch = fn.gatherers.batch
local is_positive = fn.partial(fn.operators.lt, 0)

-- disregarding negative numbers, finds the batch of 3 numbers with the highest sum.
local max = fn.stream{1, 3, 7, -4, 12, 5, 0, 25, 3, 6}
    :filter(is_positive)
    :apply(batch(3))
    :map(function(it)
        return fn.collect(it, fn.collectors.sum)
    end)
    :collect(fn.collectors.max)

print(max)
