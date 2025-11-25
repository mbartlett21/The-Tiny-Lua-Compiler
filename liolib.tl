local VirtualMachine = require'new_vm'

local type LuaExtFunc = VirtualMachine.LuaExtFunc
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

local macroexp extfunc(fn: function(VirtualMachine, table.PackTable<LuaValue>): table.PackTable<LuaValue>): LuaExtFunc
   return {
      kind = 'ExtFunc',
      run = fn,
   }
end

function liolib.openf(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local ret = table.pack((io.open as function)(table.unpack(args, 1, args.n)))
   if ret[1] then
      local ud = vm:lua_newuserdata()
      vm:luaL_setmetatable(ud, LUA_FILEHANDLE) --vm.globalSetup.registry.values['IO_FILE'] as LuaTable)
      ud.data = ret[1]
      return {
         n = 1,
         ud
      }
   else
      return ret as table.PackTable<LuaValue>
   end
end

function liolib.file_read(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local file = args[1] as LuaUdata
   local realf = file.data as FILE

   local res = table.pack((realf.read as function)(realf, table.unpack(args, 2, args.n)))
   return res as table.PackTable<LuaValue>
end

function liolib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   local io2 = vm:lua_newtable()
   io2.values.open = extfunc(liolib.openf)

   local meta_tbl = vm:luaL_newmetatable(LUA_FILEHANDLE)
   local idxtbl = vm:lua_newtable()
   meta_tbl.values.__index = idxtbl

   idxtbl.values.read = extfunc(liolib.file_read)

   globals.values.io = io2
   vm.globalSetup.packages.values.io = io2
end

return liolib
