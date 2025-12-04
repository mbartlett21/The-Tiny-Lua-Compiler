local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local math = _tl_compat and _tl_compat.math or math; local _tl_math_maxinteger = math.maxinteger or math.pow(2, 53); local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type; local lpats = {}



































































































lpats._DEBUG = nil


















local string_find = string.find

local pairs = pairs
local assert = assert
local string_sub = string.sub
local table_insert = table.insert
local table_concat = table.concat
local table_unpack = _tl_table_unpack

local isop = {
   ['-'] = true,
   ['?'] = true,
   ['*'] = true,
   ['+'] = true,
}

local isspecial = {
   ['-'] = true,
   ['%'] = true,
   ['['] = true,
   [']'] = true,
   ['('] = true,
   [')'] = true,
   ['^'] = true,
}

local function esc(c)
   if isspecial[c] then
      return '%' .. c
   else
      return c
   end
end

local function encode_char(instrs, c)
   local cs = string_sub(c, 1, 2)
   if c == '.' then
      table.insert(instrs, { ty = 'any' })
   elseif c ~= '.' and #c == 1 then
      table_insert(instrs, { ty = 'char', c = c })
   elseif cs == '%f' then
      local pat = '^' .. string_sub(c, 3) .. '$'
      table_insert(instrs, { ty = 'frontier', pat = pat })
   elseif cs == '%b' then
      local open = string_sub(c, 3, 3)
      local close = string_sub(c, 4, 4)

      if open == close then

















         local pat = '^[^' .. esc(open) .. ']$'

         local spl = #instrs + 2
         local anyth = spl + 1
         local final = spl + 3


         table_insert(instrs, { ty = 'char', c = open })


         table_insert(instrs, { ty = 'split', x = anyth, y = final })
         assert(#instrs == spl)


         table_insert(instrs, { ty = 'pat', pat = pat })
         assert(#instrs == anyth)


         table_insert(instrs, { ty = 'jmp', pc = spl })


         table_insert(instrs, { ty = 'char', c = close })
         assert(#instrs == final)
      else


















         local pat = '^[^' .. esc(open) .. esc(close) .. ']$'

         local openb = #instrs + 1
         local lp = openb + 1
         local split2 = openb + 2
         local anyth = openb + 3
         local closeb = openb + 5


         table_insert(instrs, { ty = 'inc', c = open })
         assert(#instrs == openb)


         table_insert(instrs, { ty = 'split', x = split2, y = anyth })
         assert(#instrs == lp)


         table_insert(instrs, { ty = 'split', x = openb, y = closeb })
         assert(#instrs == split2)


         table_insert(instrs, { ty = 'pat', pat = pat })
         assert(#instrs == anyth)


         table_insert(instrs, { ty = 'jmp', pc = lp })


         table_insert(instrs, { ty = 'dec', c = close })
         assert(#instrs == closeb)


         table_insert(instrs, { ty = 'jmpne', pc = lp })
      end
   elseif cs == '%B' then




      local open = string_sub(c, 3, 3)
      local close = string_sub(c, 4, 4)

      if open == close then
































         local pat = '^[^' .. esc(open) .. ']$'

         local start = #instrs + 1
         local spl1 = start + 1
         local anyo = start + 2
         local openb = start + 4
         local spl2 = start + 5
         local anyth = start + 6
         local final = start + 8
         local endc = start + 10


         table_insert(instrs, { ty = 'split', x = endc, y = spl1 })
         assert(#instrs == start)


         table_insert(instrs, { ty = 'split', x = anyo, y = openb })
         assert(#instrs == spl1)


         table_insert(instrs, { ty = 'pat', pat = pat })
         assert(#instrs == anyo)


         table_insert(instrs, { ty = 'jmp', pc = start })


         table_insert(instrs, { ty = 'char', c = open })
         assert(#instrs == openb)


         table_insert(instrs, { ty = 'split', x = anyth, y = final })
         assert(#instrs == spl2)


         table_insert(instrs, { ty = 'pat', pat = pat })
         assert(#instrs == anyth)


         table_insert(instrs, { ty = 'jmp', pc = spl2 })


         table_insert(instrs, { ty = 'char', c = close })
         assert(#instrs == final)


         table_insert(instrs, { ty = 'jmp', pc = start })


         assert(#instrs + 1 == endc)
      else


































         local pat = '^[^' .. esc(open) .. esc(close) .. ']$'

         local start = #instrs + 1
         local spl1 = start + 1
         local anyo = start + 2
         local openb = start + 4
         local lp = start + 5
         local split2 = start + 6
         local anyth = start + 7
         local closeb = start + 9
         local endc = start + 12


         table_insert(instrs, { ty = 'split', x = endc, y = spl1 })
         assert(#instrs == start)


         table_insert(instrs, { ty = 'split', x = anyo, y = openb })
         assert(#instrs == spl1)


         table_insert(instrs, { ty = 'pat', pat = pat })
         assert(#instrs == anyo)


         table_insert(instrs, { ty = 'jmp', pc = start })


         table_insert(instrs, { ty = 'inc', c = open })
         assert(#instrs == openb)


         table_insert(instrs, { ty = 'split', x = split2, y = anyth })
         assert(#instrs == lp)


         table_insert(instrs, { ty = 'split', x = openb, y = closeb })
         assert(#instrs == split2)


         table_insert(instrs, { ty = 'pat', pat = pat })
         assert(#instrs == anyth)


         table_insert(instrs, { ty = 'jmp', pc = lp })


         table_insert(instrs, { ty = 'dec', c = close })
         assert(#instrs == closeb)


         table_insert(instrs, { ty = 'jmpne', pc = lp })


         table_insert(instrs, { ty = 'jmp', pc = start })


         assert(#instrs + 1 == endc)
      end
   elseif string_sub(c, 1, 1) == '%' and math.tointeger(string_sub(c, 2)) then

      local n = math.tointeger(string_sub(c, 2))
      if n == 0 then error('invalid capture index %0') end



      instrs.has_backreference = true



















      local mc = #instrs + 3
      local lp = mc + 1



      table_insert(instrs, { ty = 'setcap', cap = n })


      table_insert(instrs, { ty = 'jmp', pc = lp })


      table_insert(instrs, { ty = 'deccap', cap = n })
      assert(#instrs == mc)


      table_insert(instrs, { ty = 'jmpne', pc = mc })
      assert(#instrs == lp)
   else
      table_insert(instrs, { ty = 'pat', pat = '^' .. c .. '$' })
   end
end


local function findclassend(pat, i)
   local c = string_sub(pat, i, i)
   if c == '%' then
      local peek = string_sub(pat, i + 1, i + 1)
      if peek == 'f' then

         assert(string_sub(pat, i + 2, i + 2) == '[', 'malformed pattern: missing `[` after %f')
         return findclassend(pat, i + 2), false
      elseif peek == 'b' or peek == 'B' then


         assert(string_sub(pat, i + 3, i + 3) ~= '', 'malformed pattern: need balanced characters')
         return i + 3, false
      elseif peek == '' then
         error('malformed pattern: expected class')
      end
      return i + 1, true
   elseif c == '[' then

      if string_sub(pat, i + 1, i + 1) == '^' then
         i = i + 2
      else
         i = i + 1
      end

      repeat
         local c2 = string_sub(pat, i, i)
         if c2 == '' then
            error('malformed pattern: missing `]`')
         elseif c2 == '%' then
            i = i + 1
         end
         i = i + 1
      until string_sub(pat, i, i) == ']'

      return i, true
   else
      return i, true
   end
end














































local function compile_pat(pat)

   local groups = {}
   local groupn = 3

   local instrs = {}

   local i = 1


   if string_sub(pat, 1, 1) == '^' then

      i = i + 1
   else





      local l1idx = #instrs + 1
      local l2idx = l1idx + 1
      local l3idx = l2idx + 2
      table_insert(instrs, { ty = 'split', x = l3idx, y = l2idx })
      table_insert(instrs, { ty = 'any' })
      table_insert(instrs, { ty = 'jmp', pc = l1idx })
   end


   table_insert(instrs, { ty = 'save', index = 1 })

   while i <= #pat do
      local c = string_sub(pat, i, i)

      if i == #pat and c == '$' then
         break
      end


      local classend, can_have_mul = findclassend(pat, i)

      local str = string_sub(pat, i, classend)

      local peek = string_sub(pat, classend + 1, classend + 1)

      if c == '(' and peek == ')' then

         local n = groupn
         groupn = groupn + 2

         table_insert(instrs, { ty = 'save', index = n })
         i = i + 2
      elseif c == '(' then
         local n = groupn
         table_insert(groups, n + 1)
         groupn = groupn + 2
         table_insert(instrs, { ty = 'save', index = n })
         i = i + 1
      elseif c == ')' then
         local n = assert(table.remove(groups), 'invalid pattern capture')
         table_insert(instrs, { ty = 'save', index = n })
         i = i + 1
      elseif isop[c] then
         error('malformed pattern: character was an op')
      elseif isop[peek] then
         if not can_have_mul then
            error('malformed pattern: item cannot be multiple')
         end

         if peek == '?' then








            local l1idx = #instrs + 2


            table_insert(instrs, {})

            assert(#instrs + 1 == l1idx)

            encode_char(instrs, str)


            local l2idx = #instrs + 1
            instrs[l1idx - 1] = { ty = 'split', x = l1idx, y = l2idx }
         elseif peek == '+' then








            local l1idx = #instrs + 1


            encode_char(instrs, str)


            local l3idx = #instrs + 2
            table_insert(instrs, { ty = 'split', x = l1idx, y = l3idx })
         elseif peek == '*' then











            local l1idx = #instrs + 1
            local l2idx = l1idx + 1


            table_insert(instrs, {})
            assert(#instrs == l1idx)


            encode_char(instrs, str)


            table_insert(instrs, { ty = 'jmp', pc = l1idx })


            local l3idx = #instrs + 1
            instrs[l1idx] = { ty = 'split', x = l2idx, y = l3idx }
         elseif peek == '-' then











            local l1idx = #instrs + 1
            local l2idx = l1idx + 1


            table_insert(instrs, {})
            assert(#instrs == l1idx)


            encode_char(instrs, str)


            table_insert(instrs, { ty = 'jmp', pc = l1idx })


            local l3idx = #instrs + 1
            instrs[l1idx] = { ty = 'split', x = l3idx, y = l2idx }
         else
            error('unreachable')
         end
         i = classend + 2
      else
         encode_char(instrs, str)
         i = classend + 1
      end
   end

   assert(not groups[1], 'unfinished capture')


   table_insert(instrs, { ty = 'save', index = 2 })

   if i == #pat then
      assert(string_sub(pat, i, i) == '$')
      table_insert(instrs, { ty = 'match' })
   else




      local l1idx = #instrs + 1
      local l2idx = l1idx + 1
      local l3idx = l2idx + 2
      table_insert(instrs, { ty = 'split', x = l3idx, y = l2idx })
      table_insert(instrs, { ty = 'any' })
      table_insert(instrs, { ty = 'jmp', pc = l1idx })








      table_insert(instrs, { ty = 'match', anywhere = true })
   end


   return instrs
end

lpats.compile_pat = compile_pat

























































































































local function matchestv(str, pat, start)
   local instrs
   if type(pat) == "string" then
      instrs = compile_pat(pat)
   else
      instrs = pat
   end

   if lpats._DEBUG then
      print(string.format('matchestv: %q, %q', (#str > 1000 and (str:sub(1, 500) .. "..." .. str:sub(-500)) or str), tostring(pat)))

      require('pprint')(instrs)
   end













   local clist = { n = 0, sp = start or 1 }
   local nlist = {}

   local function addthread(list, sp, pc, sc, saved)

      ::start::
      for i = 1, list.n do
         local li = list[i]
         if li.pc == pc and li.sc == sc then
            if not instrs.has_backreference then
               return
            end

            for k, v in pairs(li.saved) do
               if saved[k] ~= v and k > 2 then
                  goto nomatch
               end
            end


            for k in pairs(saved) do
               if not li.saved[k] and k > 2 then
                  goto nomatch
               end
            end

            return
         end
         ::nomatch::
      end

      local inst = instrs[pc]

      if inst.ty == 'jmp' then
         pc = inst.pc
         goto start
      elseif inst.ty == 'split' then
         addthread(list, sp, inst.x, sc, saved)
         pc = inst.y
         goto start
      elseif inst.ty == 'save' then
         local idx = inst.index
         local saved2 = {}
         for k, v in pairs(saved) do
            saved2[k] = v
         end
         saved2[idx] = sp
         pc = pc + 1
         saved = saved2
         goto start
      elseif inst.ty == 'frontier' then
         local c = string_sub(str, sp, sp)
         local prev = string_sub(str, sp - 1, sp - 1)
         if prev == '' then prev = '\0' end
         if c == '' then c = '\0' end
         local fpat = inst.pat
         if string_find(c, fpat) and not string_find(prev, fpat) then
            pc = pc + 1
            goto start
         end
      elseif inst.ty == 'jmpne' then
         if sc ~= 0 then
            pc = inst.pc
         else
            pc = pc + 1
         end
         goto start
      elseif inst.ty == 'setcap' then

         assert(sc == 0)
         local cap = inst.cap

         local saved1 = saved[cap * 2 + 1]
         local saved2 = saved[cap * 2 + 2]
         if saved1 and saved2 then
            pc = pc + 1
            sc = saved2 - saved1
            goto start
         else
            error('invalid capture index %' .. cap)
         end
      else
         local n = list.n + 1
         list.n = n
         local th = list[n]
         if th then
            th.pc = pc
            th.sc = sc
            th.saved = saved
         else
            list[n] = { pc = pc, sc = sc, saved = saved }
         end
      end
   end

   addthread(clist, clist.sp, 1, 0, {})

   for sp = start or 1, #str + 1 do
      nlist.sp = clist.sp + 1
      nlist.n = 0

      if lpats._DEBUG then
         print('sp = ' .. sp)
         print('#threads = ' .. clist.n)
         if lpats._DEBUG >= 2 then
            for i = 1, clist.n do
               print(clist[i].pc .. ' = ' .. tostring((instrs[clist[i].pc]).ty))
            end
         end
         print()
      end
      local c = string_sub(str, sp, sp)


      for i = 1, clist.n do
         local th = clist[i]
         local pc = th.pc
         local inst = assert(instrs[pc])

















         if inst.ty == 'char' then
            if c == inst.c then
               addthread(nlist, sp + 1, pc + 1, th.sc, th.saved)
            end
         elseif inst.ty == 'pat' then
            if string_find(c, inst.pat) then
               addthread(nlist, sp + 1, pc + 1, th.sc, th.saved)
            end
         elseif inst.ty == 'any' then
            if c ~= '' then
               addthread(nlist, sp + 1, pc + 1, th.sc, th.saved)
            end
         elseif inst.ty == 'match' then

            if c == '' then
               return th.saved
            elseif inst.anywhere then

               if i == 1 then
                  return th.saved
               end
            end
         elseif inst.ty == 'inc' then
            if c == inst.c then
               addthread(nlist, sp + 1, pc + 1, th.sc + 1, th.saved)
            end
         elseif inst.ty == 'dec' then
            if c == inst.c and th.sc > 0 then
               addthread(nlist, sp + 1, pc + 1, th.sc - 1, th.saved)
            end
         elseif inst.ty == 'deccap' then
            assert(th.sc ~= 0)
            local idx = th.saved[inst.cap * 2 + 2] - th.sc
            local capc = string_sub(str, idx, idx)
            assert(capc ~= '')
            if c == capc then

               addthread(nlist, sp + 1, pc + 1, th.sc - 1, th.saved)
            end
         else

            error('unsupported instruction: ' .. tostring((inst).ty))
         end
         i = i + 1
      end

      if clist.n == 0 then break end

      clist, nlist = nlist, clist
   end

   return
end

lpats.matchestv = matchestv



local function process_matches(s, results, include_full)
   if results[3] then
      local strs = {}
      local i = 3
      while results[i] do
         local start = results[i]
         local e = results[i + 1]
         if not e then
            strs[math.floor(i / 2)] = start
         else
            strs[math.floor(i / 2)] = string_sub(s, start, e - 1)
         end
         i = i + 2
      end
      return table_unpack(strs)
   elseif include_full then
      return string_sub(s, results[1], results[2] - 1)
   end
end

lpats.match = function(s, pat, init)
   init = init or 1
   if init < 0 then init = #s + init + 1 end

   local results = matchestv(s, pat, init)

   if not results then
      return nil
   else
      return process_matches(s, results, true)
   end
end

lpats.find = function(s, pat, init, plain)
   if plain then return string_find(s, pat, init, plain) end
   init = init or 1
   if init < 0 then init = #s + init + 1 end

   local results = matchestv(s, pat, init)

   if not results then
      return nil
   else
      return results[1], results[2] - 1, process_matches(s, results, false)
   end
end

lpats.gmatch = function(s, pat, init)
   init = init or 1
   if init < 0 then init = #s + init + 1 end

   local olen = #s

   local patc = compile_pat(pat)

   local emptyallowed = true
   local function iter()
      if init > olen + 1 then return nil end
      local results = matchestv(s, patc, init)

      if not results then
         return nil
      else


         if results[2] == init and not emptyallowed then
            init = init + 1
            emptyallowed = true
            return iter()
         end
         init = results[2]
         emptyallowed = false

         return process_matches(s, results, true)
      end
   end

   return iter
end

lpats.gsub = function(s, pat,
   repl,
   n)
   n = n or _tl_math_maxinteger
   local hadsub = false

   local repl2

   if type(repl) == "string" then
      local srepl = repl
      repl2 = function(m0, m1, m2, m3, m4, m5, m6, m7, m8, m9)
         hadsub = true
         local replacement = {}
         local i = 1

         ::loop::
         local loc = string_find(srepl, '%', i, true)
         if not loc then
            table_insert(replacement, string_sub(srepl, i))
            return table_concat(replacement)
         else
            table_insert(replacement, string_sub(srepl, i, loc - 1))
            local nex = string_sub(srepl, loc + 1, loc + 1)
            if nex == '%' then
               table_insert(replacement, '%')
            elseif nex == '0' then
               table_insert(replacement, m0)
            elseif nex == '1' then
               table_insert(replacement, (m1 or m0))
            elseif nex == '2' then
               table_insert(replacement, (assert(m2, 'invalid capture index %2')))
            elseif nex == '3' then
               table_insert(replacement, (assert(m3, 'invalid capture index %3')))
            elseif nex == '4' then
               table_insert(replacement, (assert(m4, 'invalid capture index %4')))
            elseif nex == '5' then
               table_insert(replacement, (assert(m5, 'invalid capture index %5')))
            elseif nex == '6' then
               table_insert(replacement, (assert(m6, 'invalid capture index %6')))
            elseif nex == '7' then
               table_insert(replacement, (assert(m7, 'invalid capture index %7')))
            elseif nex == '8' then
               table_insert(replacement, (assert(m8, 'invalid capture index %8')))
            elseif nex == '9' then
               table_insert(replacement, (assert(m9, 'invalid capture index %9')))
            else
               error('invalid use of \'%\' in replacement string')
            end

            i = loc + 2
            goto loop
         end
      end
   elseif type(repl) == "number" then
      local num = repl
      repl2 = function() hadsub = true; return num end
   elseif type(repl) == "table" then
      local t = repl
      repl2 = function(m0, m1)
         local tex = t[m1 or m0]
         if tex then hadsub = true end
         return tex or m0
      end
   elseif type(repl) == "function" then
      local f = repl
      repl2 = function(m0, m1, ...)
         local result
         if m1 then
            result = f(m1, ...)
         else
            result = f(m0)
         end
         if not result then
            return m0
         else
            hadsub = true
            return result
         end
      end
   end

   local final = {}
   local emptyallowed = true
   local init = 1
   local olen = #s

   local numdone = 0

   local patc = compile_pat(pat)

   while init <= olen + 1 do
      local results

      if n > numdone then
         results = matchestv(s, patc, init)
      end

      if not results then

         table_insert(final, string_sub(s, init))
         break
      else


         if results[2] == init and not emptyallowed then
            table_insert(final, string_sub(s, init, init))
            init = init + 1
            emptyallowed = true
            goto next
         end
         emptyallowed = false

         table_insert(final, string_sub(s, init, results[1] - 1))
         table_insert(final, repl2(string_sub(s, results[1], results[2] - 1), process_matches(s, results, false)))
         init = results[2]
         numdone = numdone + 1
      end
      ::next::
   end

   if not hadsub then return s, numdone end

   return table_concat(final), numdone
end







































































return lpats
