local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local math = _tl_compat and _tl_compat.math or math; local pairs = _tl_compat and _tl_compat.pairs or pairs; local table = _tl_compat and _tl_compat.table or table; local _tl_table_pack = table.pack or function(...) return { n = select("#", ...), ... } end; local _tl_table_unpack = unpack or table.unpack; local type = type; local tlc = require('the-tiny-lua-compiler')







































local USE_CURRENT_TOP = 0


local VirtualMachine = {}





























































































































































VirtualMachine.__index = VirtualMachine

VirtualMachine._CONFIG = {

   FIELDS_PER_FLUSH = 50,
}


function VirtualMachine.is_table(v)
   if type(v) == "table" then
      return v.kind == 'Table'
   end
   return false
end

function VirtualMachine.is_udata(v)
   if type(v) == "table" then
      return v.kind == 'Udata'
   end
   return false
end

function VirtualMachine.is_extfunc(v)
   if type(v) == "table" then
      return v.kind == 'ExtFunc'
   end
   return false
end

function VirtualMachine.is_extfuncsimple(v)
   if type(v) == "table" then
      return v.kind == 'ExtFuncSimple'
   end
   return false
end

function VirtualMachine.is_vmfunc(v)
   if type(v) == "table" then
      return v.kind == 'VmFunc'
   end
   return false
end



function VirtualMachine.new()
   local self = setmetatable({}, VirtualMachine)

   self.closure = nil
   self.globalSetup = {
      metatables = {},
      packages = self:simple_newtable(),
      registry = self:simple_newtable(),
      _G = self:simple_newtable(),
   }

   return self
end










function VirtualMachine:setClosure(closure)
   if closure == nil then self.closure = closure; return nil end
   closure = {
      nupvalues = closure.nupvalues or 0,
      env = closure.env or self.globalSetup._G,
      proto = closure.proto,
      upvalues = closure.upvalues or {},
   }
   self.closure = closure

   return closure
end

function VirtualMachine:simple_getmetatable(tbl)

   if VirtualMachine.is_table(tbl) then
      return tbl.metatable
   elseif VirtualMachine.is_udata(tbl) then
      return tbl.metatable
   else
      return self.globalSetup.metatables[type(tbl)]
   end
end

function VirtualMachine:simple_setmetatable(tbl, meta)
   if VirtualMachine.is_table(tbl) then
      tbl.metatable = meta
   elseif VirtualMachine.is_udata(tbl) then
      tbl.metatable = meta
   else
      self.globalSetup.metatables[type(tbl)] = meta
   end
end

function VirtualMachine:simple_luaL_getmetafield(tbl, k)
   local meta = self:simple_getmetatable(tbl)
   if meta then
      return meta.values[k]
   end
end

function VirtualMachine:simple_luaL_newmetatable(name)
   local tbl = self:simple_newtable()
   self.globalSetup.registry.values[name] = tbl
   return tbl
end

function VirtualMachine:simple_luaL_setmetatable(ud, name)
   local tbl = assert(self.globalSetup.registry.values[name])
   return self:simple_setmetatable(ud, tbl)
end

function VirtualMachine:simple_gettable(tbl, k)
   local istbl = false
   if VirtualMachine.is_table(tbl) then
      local v = tbl.values[k]
      istbl = true
      if v ~= nil then
         return v
      end
   end
   local metaidx = self:simple_luaL_getmetafield(tbl, "__index")
   if metaidx then
      if VirtualMachine.is_vmfunc(metaidx) or VirtualMachine.is_extfunc(metaidx) then
         local res = self:simple_call(metaidx, { n = 2, tbl, k })
         return res[1]
      else
         return self:simple_gettable(metaidx, k)
      end
   end
   if not istbl then
      self:lua_error("attempt to index a non-table value: " .. tostring(tbl) .. ' with key ' .. tostring(k))
   end
end

function VirtualMachine:simple_settable(tbl, k, v)
   local istbl = false
   if VirtualMachine.is_table(tbl) then
      istbl = true
      local vold = tbl.values[k]
      if vold == nil then
         tbl.values[k] = v
         return
      end
   end
   local metaidx = self:simple_luaL_getmetafield(tbl, "__newindex")
   if metaidx then
      self:simple_call(metaidx, { n = 2, tbl, k })
   elseif istbl then
      (tbl).values[k] = v
   else
      self:lua_error("attempt to set-index a non-table value: " .. tostring(tbl) ..
      ' with key ' .. tostring(k) ..
      ' and value ' .. tostring(v))
   end
end

function VirtualMachine:simple_add(a, b)
   if type(a) == "number" and type(b) == "number" then
      return a + b
   else
      local meta = self:simple_luaL_getmetafield(a, "__add") or self:simple_luaL_getmetafield(b, "__add")
      if not meta then
         self:lua_error("attempt to add invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_sub(a, b)
   if type(a) == "number" and type(b) == "number" then
      return a - b
   else
      local meta = self:simple_luaL_getmetafield(a, "__sub") or self:simple_luaL_getmetafield(b, "__sub")
      if not meta then
         self:lua_error("attempt to subtract invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_div(a, b)
   if type(a) == "number" and type(b) == "number" then
      return a / b
   else
      local meta = self:simple_luaL_getmetafield(a, "__div") or self:simple_luaL_getmetafield(b, "__div")
      if not meta then
         self:lua_error("attempt to divide invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_mul(a, b)
   if type(a) == "number" and type(b) == "number" then
      return a * b
   else
      local meta = self:simple_luaL_getmetafield(a, "__mul") or self:simple_luaL_getmetafield(b, "__mul")
      if not meta then
         self:lua_error("attempt to mul invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_mod(a, b)
   if type(a) == "number" and type(b) == "number" then
      return a % b
   else
      local meta = self:simple_luaL_getmetafield(a, "__mod") or self:simple_luaL_getmetafield(b, "__mod")
      if not meta then
         self:lua_error("attempt to mod invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_pow(a, b)
   if type(a) == "number" and type(b) == "number" then
      return a ^ b
   else
      local meta = self:simple_luaL_getmetafield(a, "__pow") or self:simple_luaL_getmetafield(b, "__pow")
      if not meta then
         self:lua_error("attempt to pow invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_unm(a)
   if type(a) == "number" then
      return -a
   else
      local meta = self:simple_luaL_getmetafield(a, "__unm")
      if not meta then
         self:lua_error("attempt to unm invalid value")
      end
      local res = self:simple_call(meta, { n = 2, a, a })
      return res[1]
   end
end

function VirtualMachine:simple_len(a)
   if type(a) == "string" then
      return #a
   end
   local meta = self:simple_luaL_getmetafield(a, "__len")
   if meta then
      return math.tointeger(tostring(self:simple_call(meta, { n = 2, a, a })[1]))
   elseif VirtualMachine.is_table(a) then
      return #(a.values)
   else
      self:lua_error("attempt to get length of invalid value")
   end
end

function VirtualMachine:simple_concat(a, b)
   if (type(a) == "string" or type(a) == "number") and (type(b) == "string" or type(b) == "number") then
      return (a) .. (b)
   else
      local meta = self:simple_luaL_getmetafield(a, "__concat") or self:simple_luaL_getmetafield(b, "__concat")
      if not meta then
         self:lua_error("attempt to concat invalid values: " .. tostring(a) .. ", " .. tostring(b))
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return res[1]
   end
end

function VirtualMachine:simple_eq(a, b)
   if a == b then return true end
   if VirtualMachine.is_table(a) and VirtualMachine.is_table(b) then
      local meta = self:simple_luaL_getmetafield(a, "__eq") or self:simple_luaL_getmetafield(b, "__eq")
      if not meta then
         return false
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return not not res[1]
   elseif VirtualMachine.is_udata(a) and VirtualMachine.is_udata(b) then
      local meta = self:simple_luaL_getmetafield(a, "__eq") or self:simple_luaL_getmetafield(b, "__eq")
      if not meta then
         return false
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return not not res[1]
   else
      return false
   end
end

function VirtualMachine:simple_lt(a, b)
   if type(a) == "string" and type(b) == "string" then
      return a < b
   elseif type(a) == "number" and type(b) == "number" then
      return a < b
   else
      local meta = self:simple_luaL_getmetafield(a, "__lt") or self:simple_luaL_getmetafield(b, "__lt")
      if not meta then
         self:lua_error("attempt to lt invalid values")
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return not not res[1]
   end
end

function VirtualMachine:simple_le(a, b)
   if type(a) == "string" and type(b) == "string" then
      return a <= b
   elseif type(a) == "number" and type(b) == "number" then
      return a <= b
   else
      local meta = self:simple_luaL_getmetafield(a, "__le") or self:simple_luaL_getmetafield(b, "__le")
      if not meta then
         return not self:simple_lt(b, a)
      end
      local res = self:simple_call(meta, { n = 2, a, b })
      return not not res[1]
   end
end

function VirtualMachine:simple_call(a, b)
   if VirtualMachine.is_vmfunc(a) then

      local currclosure = self.closure
      assert(a.closure)
      self:setClosure(a.closure)
      local rets = self:executeClosure(b)
      self:setClosure(currclosure)
      return rets
   elseif VirtualMachine.is_extfuncsimple(a) then
      return a.run(self, b)
   else
      local meta = self:simple_luaL_getmetafield(a, "__call")
      if meta then
         return self:simple_call(meta, _tl_table_pack(a, _tl_table_unpack(b, 1, b.n)))
      end
      self:lua_error("attempt to call a non-function value: " .. tostring(a))
   end
end


function VirtualMachine:internal_tailcall(a, b)
   if VirtualMachine.is_vmfunc(a) then

      self:setClosure(a.closure)
      return self:executeClosure(b)
   elseif VirtualMachine.is_extfuncsimple(a) then
      return a.run(self, b)
   else
      local meta = self:simple_luaL_getmetafield(a, "__call")
      if meta then
         return self:internal_tailcall(meta, _tl_table_pack(a, _tl_table_unpack(b, 1, b.n)))
      end
      self:lua_error("attempt to tailcall a non-function value: " .. tostring(a))
   end
end

function VirtualMachine:simple_newtable()
   return {
      kind = 'Table',
      values = {},
   }
end

function VirtualMachine:simple_newuserdata()
   return {
      kind = 'Udata',
      data = nil,
      value = nil,
   }
end

function VirtualMachine:simple_loadbuffer(buf, _name)
   local tokens = assert(tlc.Tokenizer.new(buf):tokenize())
   local ast = assert(tlc.Parser.new(tokens):parse())
   local proto = assert(tlc.CodeGenerator.new(ast):generate())
   local tClosure = {
      nupvalues = 0,
      env = self.globalSetup._G,
      proto = proto,
      upvalues = {},
   }

   return {
      kind = 'VmFunc',
      closure = tClosure,
   }
end

function VirtualMachine:lua_error(err)


   error("lualua error: " .. tostring(err), 2)
end

local function do_number(v)
   if type(v) == "string" then
      v = tonumber(v)
   end
   if type(v) == "number" then
      return v
   end
   error("Expected number")
end

local function unpacklvalue(v)
   if v == nil or type(v) == "boolean" or type(v) == "number" or type(v) == "string" then
      return v
   elseif VirtualMachine.is_vmfunc(v) then
      error("Functions can't be unpacked")
   elseif VirtualMachine.is_extfuncsimple(v) then
      return v.run
   elseif VirtualMachine.is_extfunc(v) then
      return v.run
   elseif VirtualMachine.is_table(v) then
      local newtbl = {}
      for k, v2 in pairs(v.values) do
         newtbl[unpacklvalue(k)] = unpacklvalue(v2)
      end
      return newtbl
   end
end

function VirtualMachine:unpack_tables(items)
   local new = { n = items.n }

   for i = 1, items.n do
      new[i] = unpacklvalue(items[i])
   end

   return new
end


function VirtualMachine:executeClosure(params)


   local closure = self.closure
   local stack = {}
   local env = closure.env
   local proto = closure.proto
   local upvalues = closure.upvalues
   local code = proto.code
   local constants = proto.constants
   local numparams = proto.numParams
   local isVararg = proto.isVararg

   local maxStackSize = proto.maxStackSize
   local top = maxStackSize
   local upvalueStack = {}
   local maxUpvalue = -1





   local function rk(index)
      if index < 0 then return constants[-index] end
      return stack[index]
   end


   local vararg

   for paramIdx = 1, numparams do
      stack[paramIdx - 1] = params[paramIdx]
   end
   if isVararg then
      vararg = params
      stack[numparams] = { kind = 'Table', values = params }
   end


   local pc = 1
   while true do
      local instruction = code[pc]
      if not instruction then
         break
      end

      local opcode, a, b, c = instruction[1], instruction[2], instruction[3], instruction[4]










      if opcode == "MOVE" then
         stack[a] = stack[b]



      elseif opcode == "LOADK" then
         stack[a] = constants[-b]



      elseif opcode == "LOADBOOL" then
         stack[a] = (b == 1)
         if c == 1 then
            pc = pc + 1
         end



      elseif opcode == "LOADNIL" then
         local reg = b
         repeat
            stack[reg] = nil
            reg = reg - 1
         until reg < a



      elseif opcode == "GETUPVAL" then
         local upvalue = upvalues[b + 1]
         stack[a] = upvalue.stack[upvalue.index]



      elseif opcode == "GETGLOBAL" then
         stack[a] = self:simple_gettable(env, constants[-b])



      elseif opcode == "GETTABLE" then
         stack[a] = self:simple_gettable(stack[b], rk(c))



      elseif opcode == "SETGLOBAL" then
         self:simple_settable(env, rk(b), stack[a])



      elseif opcode == "SETUPVAL" then
         local upvalue = upvalues[b + 1]
         upvalue.stack[upvalue.index] = stack[a]



      elseif opcode == "SETTABLE" then
         self:simple_settable(stack[a], rk(b), rk(c))




      elseif opcode == "NEWTABLE" then
         stack[a] = self:simple_newtable()



      elseif opcode == "SELF" then
         local rb = stack[b]
         stack[a + 1] = rb
         stack[a] = self:simple_gettable(rb, rk(c))



      elseif opcode == "ADD" then
         stack[a] = self:simple_add(rk(b), rk(c))



      elseif opcode == "SUB" then
         stack[a] = self:simple_sub(rk(b), rk(c))



      elseif opcode == "MUL" then
         stack[a] = self:simple_mul(rk(b), rk(c))



      elseif opcode == "DIV" then
         stack[a] = self:simple_div(rk(b), rk(c))



      elseif opcode == "MOD" then
         stack[a] = self:simple_mod(rk(b), rk(c))



      elseif opcode == "POW" then
         stack[a] = self:simple_pow(rk(b), rk(c))



      elseif opcode == "UNM" then
         stack[a] = self:simple_unm(stack[b])



      elseif opcode == "NOT" then
         stack[a] = not stack[b]



      elseif opcode == "LEN" then
         stack[a] = self:simple_len(stack[b])



      elseif opcode == "CONCAT" then
         for reg = c - 1, b, -1 do
            stack[reg] = self:simple_concat(stack[reg], stack[reg + 1])
         end
         stack[a] = stack[b]



      elseif opcode == "JMP" then
         pc = pc + b



      elseif opcode == "EQ" then
         local bv, cv = rk(b), rk(c)
         local isEqual = bv == cv or self:simple_eq(bv, cv)
         local bool = (a == 1)
         if isEqual ~= bool then
            pc = pc + 1
         end



      elseif opcode == "LT" then
         local isLessThan = self:simple_lt(rk(b), rk(c))
         local bool = (a == 1)
         if isLessThan ~= bool then
            pc = pc + 1
         end



      elseif opcode == "LE" then
         local isLessThanOrEqual = self:simple_le(rk(b), rk(c))
         local bool = (a == 1)
         if isLessThanOrEqual ~= bool then
            pc = pc + 1
         end




      elseif opcode == "TEST" then
         local bool = (c == 1)
         if (not stack[a]) == bool then
            pc = pc + 1
         else





            local nextInstruction = code[pc + 1]
            local jumpDistance = nextInstruction[3]
            pc = pc + 1 + jumpDistance
         end




      elseif opcode == "TESTSET" then
         local bool = (c == 1)
         if (not stack[a]) == bool then
            stack[a] = stack[b]






            local nextInstruction = code[pc + 1]
            local jumpDistance = nextInstruction[3]
            pc = pc + 1 + jumpDistance
         else
            pc = pc + 1
         end



      elseif opcode == "CALL" then
         local func = stack[a]
         if b ~= USE_CURRENT_TOP then
            top = a + b
         end

         local subParams = { n = top - 1 - a }
         for i = a + 1, top - 1 do
            subParams[i - a] = stack[i]
         end
         local returns = self:simple_call(func, subParams)


         if c ~= USE_CURRENT_TOP then
            returns.n = c - 1
         else

            top = a + returns.n
         end
         for index = 1, returns.n do
            stack[a + index - 1] = returns[index]
         end



      elseif opcode == "TAILCALL" then
         local func = stack[a]
         if b ~= USE_CURRENT_TOP then
            top = a + b
         end














         local subParams = { n = top - 1 - a }
         for i = a + 1, top - 1 do
            subParams[i - a] = stack[i]
         end
         return self:internal_tailcall(func, subParams)




      elseif opcode == "RETURN" then
         if b ~= USE_CURRENT_TOP then
            top = a + b - 1
         end

         local rett = { n = top - a }
         for i = a, top - 1 do
            rett[i - a + 1] = stack[i]
         end

         return rett






      elseif opcode == "FORLOOP" then
         local step = do_number(stack[a + 2])
         local idx = do_number(stack[a]) + step
         local limit = do_number(stack[a + 1])

         local shouldContinue = false
         if step >= 0 then
            shouldContinue = (idx <= limit)
         else
            shouldContinue = (idx >= limit)
         end

         if shouldContinue then
            pc = pc + b
            stack[a] = idx
            stack[a + 3] = idx
         end



      elseif opcode == "FORPREP" then
         local init = do_number(stack[a])

         local pstep = do_number(stack[a + 2])








         stack[a] = init - pstep
         pc = pc + b





      elseif opcode == "TFORLOOP" then
         local cb = a + 3


         stack[cb + 2] = stack[a + 2]
         stack[cb + 1] = stack[a + 1]
         stack[cb] = stack[a]


         local iteratorFunc = stack[cb]
         local returns = self:simple_call(iteratorFunc, {
            n = 2,
            stack[cb + 1],
            stack[cb + 2],
         })



         for i = 1, c do
            stack[cb + i - 1] = returns[i]
         end


         if stack[cb] ~= nil then

            stack[cb - 1] = stack[cb]






            local nextInstruction = code[pc + 1]
            local jumpDistance = nextInstruction[3]
            pc = pc + 1 + jumpDistance
         else


            pc = pc + 1
         end



      elseif opcode == "SETLIST" then
         local targetTable = stack[a]
         if VirtualMachine.is_table(targetTable) then
            local len = b
            if len == USE_CURRENT_TOP then
               len = top - a - 1
            end



            if c == 0 then
               error("SETLIST with C=0 is not supported in this VM implementation")
            end

            local offset = (c - 1) * self._CONFIG.FIELDS_PER_FLUSH
            for i = 1, len do
               targetTable.values[offset + i] = stack[a + i]
            end
         else
            error("SETLIST target is not a table")
         end


      elseif opcode == "CLOSE" then
         for i = a, maxUpvalue do
            local uv = upvalueStack[i]
            if uv then
               uv.stack = { stack[uv.index] }
               uv.index = 1
               upvalueStack[i] = nil
            end
         end
         maxUpvalue = a - 1



      elseif opcode == "CLOSURE" then
         local tProto = proto.protos[b + 1]
         local tProtoUpvalues = {}




         for _ = 1, #tProto.upvalues do
            pc = pc + 1

            local pseudoInstruction = code[pc]
            local opname = pseudoInstruction[1]
            local index = pseudoInstruction[3]
            if opname == "MOVE" then
               local upvalue = upvalueStack[index] or {
                  index = index,
                  stack = stack,
               }
               upvalueStack[index] = upvalue
               if index > maxUpvalue then maxUpvalue = index end
               table.insert(tProtoUpvalues, upvalue)
            elseif opname == "GETUPVAL" then
               local upvalue = upvalues[index + 1]
               table.insert(tProtoUpvalues, upvalue)
            else
               error("Unexpected instruction while capturing upvalues: " .. tostring(opname))
            end
         end

         local tClosure = {
            nupvalues = #tProtoUpvalues,
            env = nil,
            proto = tProto,
            upvalues = tProtoUpvalues,
         }




















         stack[a] = {
            kind = 'VmFunc',
            closure = tClosure,
         }



      elseif opcode == "VARARG" then
         if b == USE_CURRENT_TOP then
            top = a + vararg.n
            for i = 1, vararg.n do
               stack[a + i - 1] = vararg[i]
            end
         else
            for i = 1, b - 1 do
               stack[a + i - 1] = vararg[i]
            end
         end
      else
         error("Unimplemented instruction: " .. tostring(opcode))
      end


      pc = pc + 1
   end
end

function VirtualMachine:execute(proto, args)

   self:setClosure({
      nupvalues = 0,
      env = self.globalSetup._G,
      proto = proto,
      upvalues = {},
   })

   return self:executeClosure(args or { n = 0 })
end

return VirtualMachine
