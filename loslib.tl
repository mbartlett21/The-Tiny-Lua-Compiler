local VirtualMachine = require'new_vm'

-- local type LuaExtFunc = VirtualMachine.LuaExtFunc
local type LuaExtFuncSimple = VirtualMachine.LuaExtFuncSimple
-- local type LuaVmFunc = VirtualMachine.LuaVmFunc
-- local type LuaUdata = VirtualMachine.LuaUdata
-- local type LuaTable = VirtualMachine.LuaTable
local type LuaValue = VirtualMachine.LuaValue

-- local type UpValue = VirtualMachine.UpValue
-- local type Closure = VirtualMachine.Closure

local record loslib
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

function loslib.clock(_vm: VirtualMachine, _args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   return { n = 1, os.clock() }
end

function loslib.char(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local ints: table.PackTable<integer> = { n = args.n }
   for i = 1, args.n do
      ints[i] = math.tointeger(args[i])
   end
   return { n = 1, string.char(table.unpack(ints, 1, ints.n)), }
end

function loslib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   local os2 = vm:simple_newtable()
   os2.values.clock = extfuncsimple(loslib.clock)

   globals.values.os = os2
   vm.globalSetup.packages.values.os = os2
end

return loslib
