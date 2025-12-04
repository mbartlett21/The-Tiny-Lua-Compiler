local lpats = require'mjb_lpatterns'

lpats._DEBUG = 1


local function tt(name, f, ...)
    local start = os.clock()
    assert(f(...))
    local e = os.clock()
    print(name, e - start)
end

local s1 = string.rep('a', 30000)

tt('a (300000) (s)', string.find, s1, '^a+$')
tt('a (300000) (l)', lpats.find, s1, '^a+$')