local VirtualMachine = require'new_vm'

-- local type LuaExtFunc = VirtualMachine.LuaExtFunc
local type LuaExtFuncSimple = VirtualMachine.LuaExtFuncSimple
-- local type LuaVmFunc = VirtualMachine.LuaVmFunc
-- local type LuaUdata = VirtualMachine.LuaUdata
local type LuaTable = VirtualMachine.LuaTable
local type LuaValue = VirtualMachine.LuaValue

-- local type UpValue = VirtualMachine.UpValue
-- local type Closure = VirtualMachine.Closure

local record ltablib
   open: function(vm: VirtualMachine)
end

-- local macroexp extfunc(fn: function(VirtualMachine, table.PackTable<LuaValue>): table.PackTable<LuaValue>): LuaExtFunc
--    return { kind = 'ExtFunc', run = fn }
-- end

-- local function wrap_simplef(fn: function(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>): function(VirtualMachine): integer
--    return function(vm: VirtualMachine): integer
--       local arg_n = vm:lua_gettop()
--       local tbl: table.PackTable<LuaValue> = { n = arg_n }
--       for i = 1, arg_n do
--          tbl[i] = vm:lua_unstackvalue(i)
--       end
--       local res = fn(vm, tbl)
--       for i = 1, res.n do
--          vm:lua_stackvalue(res[i])
--       end
--       return res.n
--    end
-- end

local macroexp extfuncsimple(fn: function(VirtualMachine, table.PackTable<LuaValue>): table.PackTable<LuaValue>): LuaExtFuncSimple
   return { kind = 'ExtFuncSimple', run = fn }
end

-- we need these for the-tiny-lua-compiler
-- table.insert
-- table.concat
-- table.remove

function ltablib.insert(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local tbl = args[1]
   if tbl is LuaTable then
      local num = #(tbl.values as {any}) + 1
      local pos: integer
      if args.n == 2 then
         -- called with 2 arguments = insert at end
         pos = num
      elseif args.n == 3 then
         pos = math.tointeger(args[2])
         if pos > num then
            num = pos
         end
         -- move elements above
         for i = num, pos + 1, -1 do
            tbl.values[i] = tbl.values[i - 1]
         end

      else
         vm:lua_error("wrong number of arguments to table.insert")
      end

      tbl.values[pos] = args[args.n]
   else
      vm:lua_error("table.insert requires a table as arg 1")
   end
   return { n = 0 }
end

function ltablib.remove(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local tbl = args[1]
   if tbl is LuaTable then
      local num = #(tbl.values as {any})
      local pos = math.tointeger(args[2] or num)
      if not pos then
         vm:lua_error("table.remove requires an integer")
      end
      local res = tbl.values[pos]

      for i = pos, num - 1 do
         tbl.values[i] = tbl.values[i + 1]
      end
      tbl.values[num] = nil

      return { n = 1, res }
   else
      vm:lua_error("table.remove requires a table as arg 1")
   end
end

-- function ltablib.gmatch(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
--    -- we return a simple closure
--    local str = tostring(args[1])
--    local pat = tostring(args[2])
--    local init = args.n >= 3 and math.tointeger(args[3]) or 1
--    local fn = table.gmatch(str, pat, init)
--    return {
--       n = 1,
--       extfuncsimple(function(vm: VirtualMachine, _inner: table.PackTable<LuaValue>): table.PackTable<LuaValue>
--          return table.pack(fn())
--       end),
--    }
-- end

-- function ltablib.match(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
--    -- we return a simple closure
--    local str = tostring(args[1])
--    local pat = tostring(args[2])
--    local init = args.n >= 3 and math.tointeger(args[3]) or 1
--    return table.pack(table.match(str, pat, init))
-- end

-- function ltablib.sub(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
--    -- we return a simple closure
--    local str = tostring(args[1])
--    local st = math.tointeger(args[2] or 1)
--    local ed = math.tointeger(args[3] or -1)
--    return table.pack(table.sub(str, st, ed))
-- end

-- function ltablib.char(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
--    -- we return a simple closure
--    local ints: table.Packtable<integer> = { n = args.n }
--    for i = 1, args.n do
--       ints[i] = math.tointeger(args[i])
--    end
--    return { n = 1, table.char(table.unpack(ints, 1, ints.n)), }
-- end

function ltablib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   local table2 = vm:simple_newtable()
   table2.values.insert = extfuncsimple(ltablib.insert)
   table2.values.remove = extfuncsimple(ltablib.remove)
   -- table2.values.match = extfuncsimple(ltablib.match)
   -- table2.values.char = extfuncsimple(ltablib.char)
   -- table2.values.sub = extfuncsimple(ltablib.sub)

   globals.values.table = table2
   vm.globalSetup.packages.values.table = table2
end

return ltablib
