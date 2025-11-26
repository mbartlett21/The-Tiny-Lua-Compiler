local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local VirtualMachine = require('new_vm')

local lbaselib = require('lbaselib')
local lstrlib = require('lstrlib')
local liolib = require('liolib')
local ltablib = require('ltablib')

local lualibs = {}



function lualibs.open(vm)
   lbaselib.open(vm)
   lstrlib.open(vm)
   liolib.open(vm)
   ltablib.open(vm)

   vm:simple_call(assert(vm:simple_loadbuffer([[
for _, item in ipairs { 'table', 'string', 'io', '_G' } do
	local saved = item
	setmetatable(_G[item], {
		__index = function(self, idx)
			error("unexpected " .. saved .. " index: " .. tostring(idx))
		end,
	})
end
   ]])), { n = 0 })
end

return lualibs
