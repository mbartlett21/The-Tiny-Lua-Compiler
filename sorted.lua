-- sorted iterators

local math_min = math.min
local string_match = string.match
local string_sub = string.sub
local tonumber = tonumber
local type = type
local pairs = pairs

local Sorted = {}

local function ltop(l, r)
   return (l) < (r)
end

local is_digit = {
   ['0'] = true, ['1'] = true, ['2'] = true, ['3'] = true, ['4'] = true,
   ['5'] = true, ['6'] = true, ['7'] = true, ['8'] = true, ['9'] = true,
}
-- same signature as <
local function ltstr(left, right) -- returns true if left < right
   if left == right then return false end

   local pos = 1

   local minlen = math_min(#left, #right)

   while pos <= minlen do
      local cl, cr = string_sub(left, pos, pos), string_sub(right, pos, pos)

      local cld, crd = is_digit[cl], is_digit[cr]

      if cld and crd then -- parse the numbers and see
         local nl = string_match(left, '[0-9]+', pos)
         local nr = string_match(right, '[0-9]+', pos)
         if nl ~= nr then -- the numbers are different. we will do ordering based on them
            return tonumber(nl) < tonumber(nr)
         end
      elseif cl ~= cr then
         return cl < cr
      end

      pos = pos + 1
   end

   return left < right
end

local function lt2(l, r)
   local tl, tr = type(l), type(r)
   if tl ~= tr then
      return tl < tr -- sort by types
   elseif l == r then
      return false -- equal
   elseif tl == 'string' then
      return ltstr(l, r)
   elseif tl == 'number' then
      return (l) < (r)
   elseif tl == 'boolean' then
      return r -- false < true
   end
   -- table | function | userdata
   local worked, res = pcall(ltop, l, r)
   if worked then
      return res
   else
      -- failed to compare. assume equal
      return false
   end
end

Sorted.lessthan = lt2

function Sorted.pairs(tbl)
   local keys = {}
   for k in pairs(tbl) do
      table.insert(keys, k)
   end
   table.sort(keys, lt2)

   local n = 0
   return function()
      n = n + 1
      local k = keys[n]
      return k, tbl[k]
   end
end

return Sorted
