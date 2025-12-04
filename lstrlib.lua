local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local math = _tl_compat and _tl_compat.math or math; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end; local _tl_table_unpack = unpack or table.unpack; local VirtualMachine = require('new_vm')

local lpats = require('mjb_lpatterns')














local lstrlib = {}


























function lstrlib.gmatch(_vm, args)

   local str = tostring(args[1])
   local pat = tostring(args[2])
   local init = args.n >= 3 and math.tointeger(args[3]) or 1
   local fn = lpats.gmatch(str, pat, init)
   return {
      n = 1,
      { kind = 'ExtFuncSimple', run = function(_vm, _inner)
         return _tl_table_pack(fn())
      end },
   }
end

function lstrlib.match(_vm, args)
   local str = tostring(args[1])
   local pat = tostring(args[2])
   local init = args.n >= 3 and math.tointeger(args[3]) or 1
   return _tl_table_pack(lpats.match(str, pat, init))
end

function lstrlib.find(_vm, args)
   local str = tostring(args[1])
   local pat = tostring(args[2])
   local init = args.n >= 3 and math.tointeger(args[3]) or 1
   local plain = args[4] and true or false
   return _tl_table_pack(lpats.find(str, pat, init, plain))
end

function lstrlib.sub(_vm, args)
   local str = tostring(args[1])
   local st = math.tointeger(args[2] or 1)
   local ed = math.tointeger(args[3] or -1)
   return _tl_table_pack(string.sub(str, st, ed))
end

function lstrlib.rep(_vm, args)
   local str = tostring(args[1])
   local n = assert(math.tointeger(args[2]))
   return { n = 1, string.rep(str, n) }
end

function lstrlib.char(_vm, args)
   local ints = { n = args.n }
   for i = 1, args.n do
      ints[i] = math.tointeger(args[i])
   end
   return { n = 1, string.char(_tl_table_unpack(ints, 1, ints.n)) }
end

function lstrlib.open(vm)
   local globals = vm.globalSetup._G

   local string2 = vm:simple_newtable()
   string2.values.gmatch = { kind = 'ExtFuncSimple', run = lstrlib.gmatch }
   string2.values.match = { kind = 'ExtFuncSimple', run = lstrlib.match }
   string2.values.char = { kind = 'ExtFuncSimple', run = lstrlib.char }
   string2.values.sub = { kind = 'ExtFuncSimple', run = lstrlib.sub }
   string2.values.find = { kind = 'ExtFuncSimple', run = lstrlib.find }
   string2.values.rep = { kind = 'ExtFuncSimple', run = lstrlib.rep }

   local meta_tbl = vm:simple_newtable()
   meta_tbl.values.__index = string2

   globals.values.string = string2
   vm.globalSetup.packages.values.string = string2
   vm.globalSetup.metatables.string = meta_tbl
end

return lstrlib
