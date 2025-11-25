local VirtualMachine = require'new_vm'

-- local type LuaExtFunc = VirtualMachine.LuaExtFunc
local type LuaExtFuncSimple = VirtualMachine.LuaExtFuncSimple
-- local type LuaVmFunc = VirtualMachine.LuaVmFunc
-- local type LuaUdata = VirtualMachine.LuaUdata
-- local type LuaTable = VirtualMachine.LuaTable
local type LuaValue = VirtualMachine.LuaValue

-- local type UpValue = VirtualMachine.UpValue
-- local type Closure = VirtualMachine.Closure

local record lstrlib
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

function lstrlib.gmatch(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   -- we return a simple closure
   local str = tostring(args[1])
   local pat = tostring(args[2])
   local init = args.n >= 3 and math.tointeger(args[3]) or 1
   local fn = string.gmatch(str, pat, init)
   return {
      n = 1,
      extfuncsimple(function(_vm: VirtualMachine, _inner: table.PackTable<LuaValue>): table.PackTable<LuaValue>
         return table.pack(fn())
      end),
   }
end

function lstrlib.match(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   -- we return a simple closure
   local str = tostring(args[1])
   local pat = tostring(args[2])
   local init = args.n >= 3 and math.tointeger(args[3]) or 1
   return table.pack(string.match(str, pat, init))
end

function lstrlib.sub(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   -- we return a simple closure
   local str = tostring(args[1])
   local st = math.tointeger(args[2] or 1)
   local ed = math.tointeger(args[3] or -1)
   return table.pack(string.sub(str, st, ed))
end

function lstrlib.char(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   -- we return a simple closure
   local ints: table.PackTable<integer> = { n = args.n }
   for i = 1, args.n do
      ints[i] = math.tointeger(args[i])
   end
   return { n = 1, string.char(table.unpack(ints, 1, ints.n)), }
end

function lstrlib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   local string2 = vm:simple_newtable()
   string2.values.gmatch = extfuncsimple(lstrlib.gmatch)
   string2.values.match = extfuncsimple(lstrlib.match)
   string2.values.char = extfuncsimple(lstrlib.char)
   string2.values.sub = extfuncsimple(lstrlib.sub)

   local meta_tbl = vm:simple_newtable()
   meta_tbl.values.__index = string2

   globals.values.string = string2
   vm.globalSetup.packages.values.string = string2
   vm.globalSetup.metatables.string = meta_tbl
end

return lstrlib
