local fn = require "stream"

fn.each("abc", print)

fn.Stream.from({1, 2, 3}):map(function(x) return x * 2 end):each(print)

for v in fn.filter({2, 0, -3, -1, 5}, function(x) return math.abs(x) < 3 end) do
    print(v)
end

fn.Stream.from({2, 3, 4, 7})
    :filter(function(x) return x % 2 == 0 end)
    :limit(10000)
    :map(function(x) return x ^ 2 end)
    :each(print)
