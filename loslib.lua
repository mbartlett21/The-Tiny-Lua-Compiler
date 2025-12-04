local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local VirtualMachine = require('new_vm')











local loslib = {}


























function loslib.clock(_vm, _args)
   return { n = 1, os.clock() }
end

function loslib.char(_vm, args)
   local ints = { n = args.n }
   for i = 1, args.n do
      ints[i] = math.tointeger(args[i])
   end
   return { n = 1, string.char(_tl_table_unpack(ints, 1, ints.n)) }
end

function loslib.open(vm)
   local globals = vm.globalSetup._G

   local os2 = vm:simple_newtable()
   os2.values.clock = { kind = 'ExtFuncSimple', run = loslib.clock }

   globals.values.os = os2
   vm.globalSetup.packages.values.os = os2
end

return loslib
