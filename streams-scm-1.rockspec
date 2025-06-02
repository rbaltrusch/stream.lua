rockspec_format = "3.0"
package = "streams"
version = "scm"

source = {
  url = "git+https://github.com/rbaltrusch/stream.lua",
  branch = "main", -- this will be replaced by the release workflow
}

description = {
   summary = "Iterator-chaining library implementing common functional programming patterns such as `map`, `filter`, and `reduce`",
   detailed = [[
      This library provides a Java-like `Stream` class that provides a fluent interface of lazily-computed and chainable iterator operations such as `map`, `filter`, and `reduce`. For example:

      ```lua
      local fn = require "stream"
      fn.stream{2, 3, 4, 7}
          :filter(function(x) return x % 2 == 0 end)
          :map(function(x) return x ^ 2 end)
          :collect()  -- {4, 16}
      ```
   ]],
   homepage = "https://github.com/rbaltrusch/stream.lua",
   issues_url = "https://github.com/rbaltrusch/stream.lua/issues",
   license = "MIT",
   maintainer = "Richard Baltrusch",
}

dependencies = {
   "lua >= 5.1, < 5.4"
}

test_dependencies = {
  "luaunit",
}

build = {
  type = "builtin",
  modules = {
    stream = "stream.lua",
  },
}

test = {
  type = "command",
  script = "tests/run_tests.lua",
}
