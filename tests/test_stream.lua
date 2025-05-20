local test = require("luaunit")
local fn = require("stream")

TestStream = {}
local stream = fn.stream
local Stream = fn.Stream
local op = fn.operators

function TestStream:testIter()
    local expected = 1
    for x in fn.iter({1, 2, 3}) do
        test.assertEquals(x, expected)
        expected = expected + 1
    end
end

function TestStream:testMultiIter()
    local expected = 1
    for x, y in fn.iter({1, 2, 3}), fn.iter({3, 5, 7}) do
        test.assertEquals(x, expected)
        test.assertEquals(y, nil)
        expected = expected + 1
    end
end

function TestStream:testIterString()
    local result = stream(fn.iter("abc")):filter(function(x) return x ~= "b" end):reduce("", function(x, y) return x..y end)
    test.assertEquals(result, "ac")
end

function TestStream:testIterNil()
    test.assertEquals(fn.collect(fn.iter()), {})
    test.assertEquals(fn.collect(fn.iter(nil)), {})
end

-- tests that false values arent dropped from the iterable (only drop nil)
function TestStream:testIterFalse()
    test.assertEquals(fn.collect(fn.iter{false}), {false})
end

function TestStream:testIterInfinite()
    local sum = 0
    for x in fn.limit(fn.iter(function() return 1 end), 5) do
        sum = sum + x
    end
    test.assertEquals(sum, 5)
end

function TestStream:testIterFail()
    local status, message = pcall(fn.iter, false)
    test.assertFalse(status)
    test.assertEquals("Cannot convert object of type 'boolean' to an iterator!", message)
end

function TestStream:testIterStream()
    test.assertEquals(fn.collect(fn.iter(stream{2, 4, 5})), {2, 4, 5})
end

function TestStream:testIterFilteredStream()
    local predicate = function(x) return x > 3 end
    test.assertEquals(fn.collect(fn.iter(stream{2, 4, 5}:filter(predicate))), {4, 5})
end

function TestStream:testZip()
    local sum = 0
    for first, second in fn.zip({1, 4, 0}, {2, 3, 4, 5}) do
        sum = sum + (first * second)
    end
    test.assertEquals(sum, 1 * 2 + 4 * 3)
end

function TestStream:testZipEmpty()
    test.assertEquals(fn.collect(fn.zip({1, 2, 3}, {})), {})
end

-- tests that false values arent dropped from the iterable (only drop nil)
function TestStream:testZipFalse()
    local sum = 0
    for first, condition in fn.zip({1, 4, 2}, {true, false, true}) do
        if condition then
            sum = sum + first
        end
    end
    test.assertEquals(sum, 3)
end

-- here, although understandable, unfortunately the zipping is totally disregarded by the stream.collect function
function TestStream:testZipCollect()
    test.assertEquals(fn.collect(fn.zip({1, 2, 3}, {2, 3, 4})), {1, 2, 3})
end

-- here, zipping is also disregarded by Stream.concat
function TestStream:testStreamConcatZip()
    local zipped = fn.zip({1, 3, 5}, {2, 4, 6})
    test.assertEquals(fn.Stream.concat(zipped):collect(), {1, 3, 5})
end

-- here, the multivalues yielded by zipping are combined into a table using the multicollect function
function TestStream:testMulticollectZip()
    local zipped = fn.zip({1, 2, 3}, {3, 5, 7})
    local expected = {{1, 3}, {2, 5}, {3, 7}}
    test.assertEquals(fn.collect(fn.multicollect(zipped)), expected)
end

function TestStream:testMapMultiCollectZip()
    local zipped = fn.multicollect(fn.zip({3, 5, 7, 6, 4}, {true, false, true, true}))
    test.assertEquals(stream(zipped):filter(op.second):map(op.first):reduce(0, op.add), 16)
end

function TestStream:testMultiCollectIter()
    test.assertEquals(fn.collect(fn.multicollect{1, 2, 3}), {{1}, {2}, {3}})
end

function TestStream:testFlatmapMultiCollectIter()
    test.assertEquals(fn.collect(fn.flatmap(fn.multicollect{1, 2, 3}, op.id)), {1, 2, 3})
end

function TestStream:testFlatMapMultiCollectZip()
    local zipped = fn.zip({1, 3, 5}, {2, 4, 6})
    test.assertEquals(fn.collect(fn.flatmap(fn.multicollect(zipped), op.id)), {1, 2, 3, 4, 5, 6})
end

function TestStream:testStreamIterator()
    local expected = 1
    for x in stream({1, 2, 3}) do
        test.assertEquals(x, expected)
        expected = expected + 1
    end
end

function TestStream:testEmptyStream()
    test.assertEquals(fn.stream():collect(), {})
end

function TestStream:testStreamConstructor()
    test.assertEquals(fn.stream({1, 2, 3}):collect(), {1, 2, 3})
end

function TestStream:testStreamStream()
    test.assertEquals(stream(stream{-1, 3, -5}):filter(function(x) return x < 0 end):collect(), {-1, -5})
end

function TestStream:testStreamCall()
    local stream_ = stream({1, 2})
    test.assertEquals(stream_(), 1)
    test.assertEquals(stream_(), 2)
    test.assertEquals(stream_(), nil)
end

-- the specific index used doesnt actually matter
function TestStream:testStreamIndex()
    local stream_ = stream({1, 2})
    test.assertEquals(stream_[1], 1)
    test.assertEquals(stream_[1], 2)
    test.assertEquals(stream_[3], nil)
end

function TestStream:testStreamCollect()
    test.assertEquals(stream({1}):collect(), {1})
end

function TestStream:testStreamFilter()
    test.assertEquals(stream({1, 2, 3, 4, 5}):filter(function(x) return x % 2 == 1 end):collect(), {1, 3, 5})
end

function TestStream:testStreamFilterOperator()
    test.assertEquals(stream{2, 4, 5}:filter(fn.partial(op.lt, 3)):collect(), {4, 5})
end

function TestStream:testStreamMap()
    test.assertEquals(stream({1, 2, 3}):map(function(x) return x + 1 end):collect(), {2, 3, 4})
end

function TestStream:testStreamLimit()
    test.assertEquals(stream({1, 3, 5, 7}):limit(3):collect(), {1, 3, 5})
end

function TestStream:testStreamSkip()
    test.assertEquals(stream({1, 2, 3}):skip(1):collect(), {2, 3})
end

function TestStream:testStreamSkipLimit()
    test.assertEquals(stream({1, 2, 3}):skip(1):limit(1):collect(), {2})
end

function TestStream:testStreamLimitSkip()
    test.assertEquals(stream({1, 2, 3}):limit(1):skip(1):collect(), {})
end

function TestStream:testStreamEach()
    local sum = 0
    stream({1, 3, 7, 9, -1, 15}):each(function(x) sum = sum + x end)
    test.assertEquals(sum, 34)
end

function TestStream:testStreamFlatMap()
    test.assertEquals(Stream.range(0, 2):flatmap(function(x) return {x * 2, x + 1} end):collect(), {0, 1, 2, 2, 4, 3})
end

function TestStream:testStreamReduce()
    test.assertEquals(Stream.range(1, 5):reduce(1, function(x, y) return x * y end), 120)
end

function TestStream:testPartial()
    local add = function(x, y) return x + y end
    local func = fn.partial(add, 2)
    test.assertEquals(func(4), 6)
end

function TestStream:testStreamRange()
    test.assertEquals(Stream.range(1, 5):collect(), {1, 2, 3, 4, 5})
end

function TestStream:testStreamRangeStep()
    test.assertEquals(Stream.range(3, 10, 2):collect(), {3, 5, 7, 9})
end

function TestStream:testStreamSum()
    test.assertEquals(Stream.range(1, 5):collect(fn.collectors.sum), 15)
end

function TestStream:testStreamSumEmpty()
    test.assertEquals(stream({}):collect(fn.collectors.sum), 0)
end

function TestStream:testStreamJoin()
    test.assertEquals(stream("abc"):collect(fn.collectors.join(";")), "a;b;c")
end

function TestStream.testVeryLongStreamJoin()
    local infinite = fn.iter(function() return "a" end)
    test.assertEquals(stream(infinite):limit(25000):collect(fn.collectors.join()), table.concat(stream(infinite):limit(25000):collect()))
end

function TestStream:testStreamJoinEmpty()
    test.assertEquals(stream({}):collect(fn.collectors.join(";")), "")
end

function TestStream:testInfiniteStream()
    local infinite = fn.iter(function() return 1 end)
    test.assertEquals(stream(infinite):limit(5):collect(), {1, 1, 1, 1, 1})
end

function TestStream:testStreamCount()
    test.assertEquals(stream({1, 2, 3}):count(), 3)
end

function TestStream:testStreamPeek()
    local sum = 0
    local consumer = function(x) sum = sum + x end
    test.assertEquals(stream({1, 2, 3}):peek(consumer):collect(), {1, 2, 3})
    test.assertEquals(sum, 6)
end

function TestStream:testStreamAllNoPredicate()
    test.assertTrue(stream{true, true, true}:all())
    test.assertFalse(stream{true, false, true}:all())
end

function TestStream:testStreamAll()
    test.assertTrue(stream{1, 2, 3}:all(function(x) return x > 0 end))
    test.assertFalse(stream{1, -2, 3}:all(function(x) return x > 0 end))
end

function TestStream:testStreamConcat()
    test.assertEquals(fn.Stream.concat({1}, stream{2, 3}, fn.iter(), stream{5}):collect(), {1, 2, 3, 5})
end

function TestStream:integrationTest()
    local list = Stream.range(10, 100, 4):collect()
    local result = fn.limit(
        fn.filter(
            fn.map(
                list,
                function(x) return x * 2 + 1 end
            ),
            function(x) return x % 3 == 0 or x > 100 end
        ),
        8
    )
    test.assertEquals(result, {21, 45, 69, 93, 101, 109, 117, 125})
end

function TestStream:streamIntegrationTest()
    local result = Stream.range(10, 100, 4)
        :map(function(x) return x * 2 + 1 end)
        :filter(function(x) return x % 3 == 0 or x > 100 end)
        :limit(8)
        :collect()
    test.assertEquals(result, {21, 45, 69, 93, 101, 109, 117, 125})
end

function TestStream:testRange()
    local sum = 0
    for x in fn.range(0, 5) do
        sum = sum + x
    end
    test.assertEquals(sum, 15)
end

function TestStream:testRangeStep()
    local sum = 0
    for x in fn.range(0, 5, 2) do
        sum = sum + x
    end
    test.assertEquals(sum, 6)
end

function TestStream:testRangeEqualLimits()
    local sum = 0
    for x in fn.range(1, 1) do
        sum = sum + x
    end
    test.assertEquals(sum, 1)
end

function TestStream:testRangeInvertedLimits()
    local sum = 0
    for x in fn.range(1, 0) do
        sum = sum + x
    end
    test.assertEquals(sum, 0)
end

-- infinite iterator
function TestStream:testRangeZeroStep()
    local sum = 0
    for x in fn.limit(fn.range(1, 2, 0), 100) do
        sum = sum + x
    end
    test.assertEquals(sum, 100)
end

function TestStream:testRangeNegativeStep()
    test.assertEquals(fn.collect(fn.range(5, 1, -1)), {5, 4, 3, 2, 1})
end

function TestStream:testFilterTable()
    test.assertEquals(fn.collect(fn.filter({1, 2, 3}, function(x) return x ~= 3 end)), {1, 2})
end

function TestStream:testFilterTableNoPredicate()
    test.assertEquals(fn.collect(fn.filter({false, true, false})), {true})
end

function TestStream:testMapTable()
    test.assertEquals(fn.collect(fn.map({1, 2, 3}, function(x) return x * x end)), {1, 4, 9})
end

-- tests that false values arent dropped from the iterable (only drop nil)
function TestStream:testMapFalse()
    test.assertEquals(fn.collect(fn.map({false}, function(x) return x end)), {false})
end

function TestStream:testReduceEmptyTable()
    test.assertEquals(fn.reduce({}, 0, function(x, y) return x + y end), 0)
end

function TestStream:testReduceTable()
    test.assertEquals(fn.reduce({1, 2, 3, 4, 5}, 0, function(x, y) return x + y end), 15)
end

function TestStream:testFlatmapTable()
    test.assertEquals(fn.collect(fn.flatmap({1, 2, 3}, function(x) return {x, x + 1} end)), {1, 2, 2, 3, 3, 4})
end

function TestStream:testLimitTable()
    test.assertEquals(fn.collect(fn.limit({1, 2, 3, 4, 5}, 3)), {1, 2, 3})
end

function TestStream:testSkipTable()
    test.assertEquals(fn.collect(fn.skip({1, 2, 3, 4, 5}, 3)), {4, 5})
end

function TestStream:testSkipAllTable()
    test.assertEquals(fn.collect(fn.skip({1, 2, 3, 4, 5}, 6)), {})
end

function TestStream:testForEachTable()
    local sum = 0
    fn.each({1, 2, 3}, function(x) sum = sum + x end)
    test.assertEquals(sum, 6)
end

function TestStream:testTakeWhileTable()
    test.assertEquals(fn.collect(fn.takewhile({1, 2, 3, -1, 4, 5}, function(x) return x > 0 end)), {1, 2, 3})
end

function TestStream:testDropWhileTable()
    test.assertEquals(fn.collect(fn.dropwhile({1, 2, -3, -1, 4, -5}, function(x) return x > 0 end)), {-3, -1, 4, -5})
end

function TestStream:testReversedTable()
    test.assertEquals(fn.collect(fn.reversed{1, 2, 3}), {3, 2, 1})
end

function TestStream:testCollect()
    local get_iterator = function()
        local value = 0
        return function()
            value = value + 1
            if value <= 3 then
                return value
            end
        end
    end

    test.assertEquals(fn.collect(get_iterator()), {1, 2, 3})
end

function TestStream:testCollectEmpty()
    local iterator = function() return nil end
    test.assertEquals(fn.collect(iterator), {})
end

function TestStream:testAnyEmpty()
    test.assertEquals(fn.any({}), false)
end

function TestStream:testAnyNoPredicate()
    test.assertEquals(fn.any({false, true, false}), true)
    test.assertEquals(fn.any({false, false, false}), false)
end

function TestStream:testAnyFalse()
    test.assertEquals(fn.any({1, 2, 3, 4}, function(x) return x > 5 end), false)
end

function TestStream:testAnyTrue()
    test.assertEquals(fn.any({1, 2, 3, 4}, function(x) return x >= 3 end), true)
end

function TestStream:testAllEmpty()
    test.assertEquals(fn.all({}), true)
end

function TestStream:testAllNoPredicate()
    test.assertEquals(fn.all({true, true}), true)
    test.assertEquals(fn.all({false, true, false}), false)
end

function TestStream:testAllFalse()
    test.assertEquals(fn.all({1, 2, 3, 4}, function(x) return x > 2 end), false)
end

function TestStream:testAllTrue()
    test.assertEquals(fn.all({1, 2, 3, 4}, function(x) return x < 5 end), true)
end

function TestStream:testPeek()
    local sum = 0
    local consumer = function(x) sum = sum + x end
    test.assertEquals(fn.collect(fn.peek({1, 2, 3}, consumer)), {1, 2, 3})
    test.assertEquals(sum, 6)
end

function TestStream:testCycle()
    test.assertEquals(fn.collect(fn.limit(fn.cycle({1, 2, 3}), 10)), {1, 2, 3, 1, 2, 3, 1, 2, 3, 1})
end

function TestStream:testAdd()
    test.assertEquals(fn.operators.add(2, 3), 5)
end

function TestStream:testSub()
    test.assertEquals(fn.operators.sub(2, 3), -1)
end

function TestStream:testMul()
    test.assertEquals(fn.operators.mul(2, 3), 6)
end

function TestStream:testDiv()
    test.assertEquals(fn.operators.div(5, 2), 2.5)
end

function TestStream:testMod()
    test.assertEquals(fn.operators.mod(3, 2), 1)
end

function TestStream:testPow()
    test.assertEquals(fn.operators.pow(2, 3), 8)
end

function TestStream:testNeg()
    test.assertEquals(fn.operators.neg(2), -2)
end

function TestStream:testAnd()
    test.assertEquals(fn.operators.and_(2, 3), 3)
    test.assertEquals(fn.operators.and_(true, true), true)
    test.assertEquals(fn.operators.and_(2, nil), nil)
    test.assertEquals(fn.operators.and_(false, 2), false)
end

function TestStream:testOr()
    test.assertEquals(fn.operators.or_(2, 3), 2)
    test.assertEquals(fn.operators.or_(true, true), true)
    test.assertEquals(fn.operators.or_(2, nil), 2)
    test.assertEquals(fn.operators.or_(false, 2), 2)
    test.assertEquals(fn.operators.or_(false, nil), nil)
end

function TestStream:testNot()
    test.assertEquals(fn.operators.not_(0), false)
    test.assertEquals(fn.operators.not_(false), true)
    test.assertEquals(fn.operators.not_(true), false)
    test.assertEquals(fn.operators.not_(nil), true)
end

function TestStream:testTruthy()
    test.assertEquals(fn.operators.truthy(0), true)
    test.assertEquals(fn.operators.truthy(false), false)
    test.assertEquals(fn.operators.truthy(true), true)
    test.assertEquals(fn.operators.truthy(nil), false)
end

function TestStream:testEqual()
    test.assertEquals(fn.operators.eq(nil, nil), true)
    test.assertEquals(fn.operators.eq(nil, false), false)
    test.assertEquals(fn.operators.eq(1, 1), true)
    test.assertEquals(fn.operators.eq(1, 2), false)
end

function TestStream:testNotEqual()
    test.assertEquals(fn.operators.neq(nil, nil), false)
    test.assertEquals(fn.operators.neq(nil, false), true)
    test.assertEquals(fn.operators.neq(1, 1), false)
    test.assertEquals(fn.operators.neq(1, 2), true)
end

function TestStream:testGreaterThan()
    test.assertEquals(fn.operators.gt(1, 2), false)
    test.assertEquals(fn.operators.gt(2, 2), false)
    test.assertEquals(fn.operators.gt(3, 2), true)
end

function TestStream:testLessThan()
    test.assertEquals(fn.operators.lt(1, 2), true)
    test.assertEquals(fn.operators.lt(2, 2), false)
    test.assertEquals(fn.operators.lt(3, 2), false)
end

function TestStream:testGreaterThanOrEqual()
    test.assertEquals(fn.operators.gte(1, 2), false)
    test.assertEquals(fn.operators.gte(2, 2), true)
    test.assertEquals(fn.operators.gte(3, 2), true)
end

function TestStream:testLessThanOrEqual()
    test.assertEquals(fn.operators.lte(1, 2), true)
    test.assertEquals(fn.operators.lte(2, 2), true)
    test.assertEquals(fn.operators.lte(3, 2), false)
end

function TestStream:testConcat()
    test.assertEquals(fn.operators.concat("a", "b"), "ab")
end

function TestStream:testLength()
    test.assertEquals(fn.operators.len({3, 5, 7}), 3)
end

function TestStream:testId()
    test.assertEquals(stream{1, false, "test"}:map(op.id):collect(), {1, false, "test"})
end

function TestStream:testFirst()
    test.assertEquals(op.first({5, 3, 1}), 5)
end

function TestStream:testSecond()
    test.assertEquals(op.second({5, 3, 2}), 3)
end

function TestStream:testIndex()
    test.assertEquals(op.index(3, {5, 3, 4, 2}), 4)
end
