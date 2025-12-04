local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local math = _tl_compat and _tl_compat.math or math; local table = _tl_compat and _tl_compat.table or table; local VirtualMachine = require('new_vm')











local ltablib = {}































function ltablib.insert(vm, args)
   local tbl = args[1]
   if VirtualMachine.is_table(tbl) then
      local num = #(tbl.values) + 1
      local pos
      if args.n == 2 then

         pos = num
      elseif args.n == 3 then
         pos = math.tointeger(args[2])
         if pos > num then
            num = pos
         end

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

function ltablib.remove(vm, args)
   local tbl = args[1]
   if VirtualMachine.is_table(tbl) then
      local num = #(tbl.values)
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








































function ltablib.open(vm)
   local globals = vm.globalSetup._G

   local table2 = vm:simple_newtable()
   table2.values.insert = { kind = 'ExtFuncSimple', run = ltablib.insert }
   table2.values.remove = { kind = 'ExtFuncSimple', run = ltablib.remove }




   globals.values.table = table2
   vm.globalSetup.packages.values.table = table2
end

return ltablib
