local Sorted = require'sorted'

local function pprint(t, spaces, done)
   local tt = type(t)
   if tt ~= 'table' then
      if tt == 'string' then
         return string.format('%q', t)
      else
         return tostring(t)
      end
   end

   if not next(t) then
      return '{}'
   end

   if done[t] then
      return string.format('\'circular reference: %p\'', t)
   end

   done[t] = true

   local sspaces = spaces .. '  '

   local s = string.format('{ -- %p\n', t)
   local i = 1
   for k, v in Sorted.pairs(t) do
      if k == i then
         i = i + 1
         s = s .. sspaces .. pprint(v, sspaces, done) .. ',\n'
      else
         s = s .. sspaces ..
            '[' .. pprint(k, sspaces, done) .. '] = ' ..
            pprint(v, sspaces, done) .. ',\n'
      end
   end
   return s .. spaces .. '}'
end


return function(v, skip, file, mode)
   local s = pprint(v, '', skip or {})
   if file then
      local f
      if type(file) == 'string' then
         f = io.open(file, mode or 'wb')
      else
         f = file
      end
      f:write('return ', s)
      if f ~= file then
         f:close()
      end
   else
      print(s)
   end
   return s
end
