local VirtualMachine = require'new_vm'

local type LuaExtFunc = VirtualMachine.LuaExtFunc
-- local type LuaVmFunc = VirtualMachine.LuaVmFunc
-- local type LuaTable = VirtualMachine.LuaTable
local type LuaValue = VirtualMachine.LuaValue

-- local type UpValue = VirtualMachine.UpValue
-- local type Closure = VirtualMachine.Closure

local record lbaselib
   open: function(vm: VirtualMachine)
end

local macroexp extfunc(fn: function(VirtualMachine, table.PackTable<LuaValue>): table.PackTable<LuaValue>): LuaExtFunc
   return {
      kind = 'ExtFunc',
      run = fn,
   }
end

function lbaselib.ipairsaux(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local int = assert(math.tointeger(args[2]))
   local v2 = int + 1
   local tbl = args[1]
   local val = vm:lua_gettable(tbl, v2)

   if val then
      return {
         n = 2,
         v2,
         val
      }
   else
      return { n = 1 }
   end
end

function lbaselib.ipairs(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   return {
      n = 3,
      extfunc(lbaselib.ipairsaux),
      args[1],
      0
   }
end

function lbaselib.next(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local tbl = args[1]
   local key = args[2]

   if tbl is LuaTable then
      local k, v = next(tbl.values, key)
      if not k then
         return { n = 1 }
      else
         return { n = 2, k, v }
      end
   else
      vm:lua_error("calling next on a non-table value")
   end
end

function lbaselib.pairs(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local meta = vm:luaL_getmetafield(args[1], "__pairs")
   if meta then
      return vm:lua_call(meta, { n = 1, args[1] })
   else
      return {
         n = 3,
         extfunc(lbaselib.next),
         args[1],
      }
   end
end

function lbaselib.assert(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   if args[1] then
      return args
   elseif args.n >= 2 then
      vm:lua_error(args[2])
   else
      vm:lua_error("assertion failed!")
   end
end

function lbaselib.print(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   for i = 1, args.n do
      if i > 1 then
         io.write('\t')
      end
      io.write(tostring(args[i]))
   end
   io.write('\n')
   return { n = 0 }
end

function lbaselib.tonumber(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   if args.n == 1 then
      return { n = 1, tonumber(args[1]) }
   else
      return { n = 1, tonumber(args[1], tonumber(args[2]) as integer) }
   end
end

function lbaselib.error(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   if args[1] then
      vm:lua_error(args[1])
   else
      vm:lua_error("Error!")
   end
end

function lbaselib.select(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local first = tonumber(args[1]) as integer or args[1]
   if first == "#" then
      return {
         n = 1,
         args.n - 1,
      }
   elseif first is integer then
      local a = first
      if a < 0 then
         a = args.n + a
      elseif a > args.n then
         a = args.n
      end
      if a < 1 then error("index out of range") end
      local res: table.PackTable<LuaValue> = {
         n = args.n - a,
      }
      for i = a, args.n do
         res[i - a + 1] = args[i]
      end
      return res
   else
      vm:lua_error("invalid index")
   end
end

function lbaselib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   globals.values.assert = extfunc(lbaselib.assert)
   globals.values.ipairs = extfunc(lbaselib.ipairs)
   globals.values.pairs = extfunc(lbaselib.pairs)
   globals.values.next = extfunc(lbaselib.next)
   globals.values.print = extfunc(lbaselib.print)
   globals.values.tonumber = extfunc(lbaselib.tonumber)
   globals.values.error = extfunc(lbaselib.error)
   globals.values.select = extfunc(lbaselib.select)
end

return lbaselib
