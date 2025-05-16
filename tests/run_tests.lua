-- run from root repo folder with: lua tests/run_tests.lua

local luaunit = require("luaunit")

require("tests.test_stream")

os.exit(luaunit.LuaUnit.run())
