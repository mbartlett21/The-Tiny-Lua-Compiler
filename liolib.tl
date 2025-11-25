local VirtualMachine = require'new_vm'

-- local type LuaExtFunc = VirtualMachine.LuaExtFunc
local type LuaExtFuncSimple = VirtualMachine.LuaExtFuncSimple
-- local type LuaVmFunc = VirtualMachine.LuaVmFunc
local type LuaUdata = VirtualMachine.LuaUdata
-- local type LuaTable = VirtualMachine.LuaTable
local type LuaValue = VirtualMachine.LuaValue

-- local type UpValue = VirtualMachine.UpValue
-- local type Closure = VirtualMachine.Closure

local LUA_FILEHANDLE <const> = "FILE*"

local record liolib
   open: function(vm: VirtualMachine)
end

-- local macroexp extfunc(fn: function(VirtualMachine, table.PackTable<LuaValue>): table.PackTable<LuaValue>): LuaExtFunc
--    return {
--       kind = 'ExtFunc',
--       run = fn,
--    }
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
   return {
      kind = 'ExtFuncSimple',
      run = fn,
   }
end

function liolib.openf(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local ret = table.pack((io.open as function)(table.unpack(args, 1, args.n)))
   if ret[1] then
      local ud = vm:simple_newuserdata()
      vm:simple_luaL_setmetatable(ud, LUA_FILEHANDLE) --vm.globalSetup.registry.values['IO_FILE'] as LuaTable)
      ud.data = ret[1]
      return {
         n = 1,
         ud
      }
   else
      return ret as table.PackTable<LuaValue>
   end
end

function liolib.file_read(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local file = args[1] as LuaUdata
   local realf = file.data as FILE

   local res = table.pack((realf.read as function)(realf, table.unpack(args, 2, args.n)))
   return res as table.PackTable<LuaValue>
end

function liolib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   local io2 = vm:simple_newtable()
   io2.values.open = extfuncsimple(liolib.openf)

   local meta_tbl = vm:simple_luaL_newmetatable(LUA_FILEHANDLE)
   local idxtbl = vm:simple_newtable()
   meta_tbl.values.__index = idxtbl

   idxtbl.values.read = extfuncsimple(liolib.file_read)

   globals.values.io = io2
   vm.globalSetup.packages.values.io = io2
end

return liolib
