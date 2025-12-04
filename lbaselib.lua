local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local math = _tl_compat and _tl_compat.math or math; local table = _tl_compat and _tl_compat.table or table; local type = type; local VirtualMachine = require('new_vm')










local lbaselib = {}


























function lbaselib.ipairsaux(vm, args)
   local int = assert(math.tointeger(args[2]))
   local v2 = int + 1
   local tbl = args[1]
   local val = vm:simple_gettable(tbl, v2)

   if val then
      return {
         n = 2,
         v2,
         val,
      }
   else
      return { n = 1 }
   end
end

function lbaselib.ipairs(_vm, args)
   return {
      n = 3,
      { kind = 'ExtFuncSimple', run = lbaselib.ipairsaux },
      args[1],
      0,
   }
end

function lbaselib.next(vm, args)
   local tbl = args[1]
   local key = args[2]

   if VirtualMachine.is_table(tbl) then
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

function lbaselib.pairs(vm, args)
   local meta = vm:simple_luaL_getmetafield(args[1], "__pairs")
   if meta then
      return vm:simple_call(meta, { n = 1, args[1] })
   else
      return {
         n = 3,
         { kind = 'ExtFuncSimple', run = lbaselib.next },
         args[1],
      }
   end
end

function lbaselib.assert(vm, args)
   if args[1] then
      return args
   elseif args.n >= 2 then
      vm:lua_error(args[2])
   else
      vm:lua_error("assertion failed!")
   end
end

function lbaselib.print(_vm, args)
   for i = 1, args.n do
      if i > 1 then
         io.write('\t')
      end
      io.write(tostring(args[i]))
   end
   io.write('\n')
   return { n = 0 }
end

function lbaselib.tonumber(_vm, args)
   if args.n == 1 then
      return { n = 1, tonumber(args[1]) }
   else
      return { n = 1, tonumber(args[1], tonumber(args[2])) }
   end
end

function lbaselib.error(vm, args)
   if args[1] then
      vm:lua_error(args[1])
   else
      vm:lua_error("Error!")
   end
end

function lbaselib.select(vm, args)
   local first = tonumber(args[1]) or args[1]
   if first == "#" then
      return {
         n = 1,
         args.n - 1,
      }
   elseif math.type(first) == "integer" then
      local a = first
      if a < 0 then
         a = args.n + a
      elseif a > args.n then
         a = args.n
      end
      if a < 1 then error("index out of range") end
      local res = {
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

function lbaselib.loadstring(vm, args)
   local str = tostring(args[1])
   local name = args[2] and tostring(args[2]) or "?"

   local fn = assert(vm:simple_loadbuffer(str, name))

   return { n = 1, fn }
end

function lbaselib.setmetatable(vm, args)
   local tbl = args[1]
   local metat = args[2]
   if VirtualMachine.is_table(tbl) and VirtualMachine.is_table(metat) and not vm:simple_luaL_getmetafield(tbl, "__metatable") then
      vm:simple_setmetatable(tbl, metat)
   else
      vm:lua_error("cannot set metatable")
   end
   return { n = 1, tbl }
end

function lbaselib.unpack(vm, args)
   local tbl = args[1]
   local i = math.tointeger(args[2] or 1)
   if VirtualMachine.is_table(tbl) then
      local e = math.tointeger(args[3] or #(tbl.values))
      local stack = { n = e - i + 1 }
      for n = i, e do
         stack[n - i + 1] = tbl.values[n]
      end
      return stack
   end
   vm:lua_error("cannot unpack non-table value")
end

function lbaselib.type(_vm, args)
   local v = args[1]
   if VirtualMachine.is_table(v) then
      return { n = 1, "table" }
   elseif VirtualMachine.is_vmfunc(v) or VirtualMachine.is_extfunc(v) or VirtualMachine.is_extfuncsimple(v) then
      return { n = 1, "function" }
   elseif type(v) == "number" then
      return { n = 1, "number" }
   elseif type(v) == "boolean" then
      return { n = 1, "boolean" }
   elseif type(v) == "string" then
      return { n = 1, "string" }
   elseif v == nil then
      return { n = 1, "nil" }
   else
      error("invalid value: " .. tostring(v))
   end
end

function lbaselib.tostring(_vm, args)
   local v = args[1]
   if VirtualMachine.is_table(v) then
      return { n = 1, "table <?>" }
   elseif VirtualMachine.is_vmfunc(v) or VirtualMachine.is_extfunc(v) or VirtualMachine.is_extfuncsimple(v) then
      return { n = 1, "function <?>" }
   elseif type(v) == "number" then
      return { n = 1, tostring(v) }
   elseif type(v) == "boolean" then
      return { n = 1, v and "true" or "false" }
   elseif type(v) == "string" then
      return { n = 1, v }
   elseif v == nil then
      return { n = 1, "nil" }
   else
      error("invalid value: " .. tostring(v))
   end
end








function lbaselib.open(vm)
   local globals = vm.globalSetup._G

   globals.values.assert = { kind = 'ExtFuncSimple', run = lbaselib.assert }
   globals.values.ipairs = { kind = 'ExtFuncSimple', run = lbaselib.ipairs }
   globals.values.pairs = { kind = 'ExtFuncSimple', run = lbaselib.pairs }
   globals.values.next = { kind = 'ExtFuncSimple', run = lbaselib.next }
   globals.values.print = { kind = 'ExtFuncSimple', run = lbaselib.print }
   globals.values.tonumber = { kind = 'ExtFuncSimple', run = lbaselib.tonumber }
   globals.values.error = { kind = 'ExtFuncSimple', run = lbaselib.error }
   globals.values.select = { kind = 'ExtFuncSimple', run = lbaselib.select }
   globals.values.loadstring = { kind = 'ExtFuncSimple', run = lbaselib.loadstring }
   globals.values.setmetatable = { kind = 'ExtFuncSimple', run = lbaselib.setmetatable }
   globals.values.unpack = { kind = 'ExtFuncSimple', run = lbaselib.unpack }
   globals.values.type = { kind = 'ExtFuncSimple', run = lbaselib.type }
   globals.values.tostring = { kind = 'ExtFuncSimple', run = lbaselib.tostring }
   globals.values._G = globals

   vm.globalSetup.packages.values._G = globals


end

return lbaselib
