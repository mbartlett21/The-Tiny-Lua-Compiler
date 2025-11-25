local VirtualMachine = require'new_vm'

-- local type LuaExtFunc = VirtualMachine.LuaExtFunc
local type LuaExtFuncSimple = VirtualMachine.LuaExtFuncSimple
-- local type LuaVmFunc = VirtualMachine.LuaVmFunc
local type LuaTable = VirtualMachine.LuaTable
local type LuaValue = VirtualMachine.LuaValue

-- local type UpValue = VirtualMachine.UpValue
-- local type Closure = VirtualMachine.Closure

local record lbaselib
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

function lbaselib.ipairsaux(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   local int = assert(math.tointeger(args[2]))
   local v2 = int + 1
   local tbl = args[1]
   local val = vm:simple_gettable(tbl, v2)

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

function lbaselib.ipairs(_vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
   return {
      n = 3,
      extfuncsimple(lbaselib.ipairsaux),
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
   local meta = vm:simple_luaL_getmetafield(args[1], "__pairs")
   if meta then
      return vm:simple_call(meta, { n = 1, args[1] })
   else
      return {
         n = 3,
         extfuncsimple(lbaselib.next),
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

-- function lbaselib.loadfile(vm: VirtualMachine, args: table.PackTable<LuaValue>): table.PackTable<LuaValue>
--    local s = vm:luaL_checklstring(1)
--    local chunkname = vm:luaL_optstring(2)

--    return loadaux(vm, vm:luaL_loadbuffer(s, chunkname))
-- end

function lbaselib.open(vm: VirtualMachine)
   local globals = vm.globalSetup._G

   globals.values.assert = extfuncsimple(lbaselib.assert)
   globals.values.ipairs = extfuncsimple(lbaselib.ipairs)
   globals.values.pairs = extfuncsimple(lbaselib.pairs)
   globals.values.next = extfuncsimple(lbaselib.next)
   globals.values.print = extfuncsimple(lbaselib.print)
   globals.values.tonumber = extfuncsimple(lbaselib.tonumber)
   globals.values.error = extfuncsimple(lbaselib.error)
   globals.values.select = extfuncsimple(lbaselib.select)
   globals.values._G = globals
   -- globals.values.loadfile = extfuncsimple(lbaselib.loadfile)
end

return lbaselib
