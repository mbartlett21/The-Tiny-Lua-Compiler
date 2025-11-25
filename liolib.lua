local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local io = _tl_compat and _tl_compat.io or io; local table = _tl_compat and _tl_compat.table or table; local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end; local _tl_table_unpack = unpack or table.unpack; local VirtualMachine = require('new_vm')











local LUA_FILEHANDLE = "FILE*"

local liolib = {}
































function liolib.openf(vm, args)
   local ret = _tl_table_pack((io.open)(_tl_table_unpack(args, 1, args.n)))
   if ret[1] then
      local ud = vm:simple_newuserdata()
      vm:simple_luaL_setmetatable(ud, LUA_FILEHANDLE)
      ud.data = ret[1]
      return {
         n = 1,
         ud,
      }
   else
      return ret
   end
end

function liolib.file_read(_vm, args)
   local file = args[1]
   local realf = file.data

   local res = _tl_table_pack((realf.read)(realf, _tl_table_unpack(args, 2, args.n)))
   return res
end

function liolib.open(vm)
   local globals = vm.globalSetup._G

   local io2 = vm:simple_newtable()
   io2.values.open = { kind = 'ExtFuncSimple', run = liolib.openf,


   }; local meta_tbl = vm:simple_luaL_newmetatable(LUA_FILEHANDLE); local idxtbl = vm:simple_newtable()
   meta_tbl.values.__index = idxtbl

   idxtbl.values.read = { kind = 'ExtFuncSimple', run = liolib.file_read,


   }; globals.values.io = io2; vm.globalSetup.packages.values.io = io2
end

return liolib
