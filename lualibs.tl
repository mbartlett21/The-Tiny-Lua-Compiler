local VirtualMachine = require'new_vm'

local lbaselib = require'lbaselib'
local lstrlib = require'lstrlib'
local liolib = require'liolib'
local ltablib = require'ltablib'

local record lualibs
	open: function(vm: VirtualMachine)
end

function lualibs.open(vm: VirtualMachine)
	lbaselib.open(vm)
	lstrlib.open(vm)
	liolib.open(vm)
	ltablib.open(vm)

   vm:simple_call(assert(vm:simple_loadbuffer [[
for _, item in ipairs { 'table', 'string', 'io', '_G' } do
	local saved = item
	setmetatable(_G[item], {
		__index = function(self, idx)
			error("unexpected " .. saved .. " index: " .. tostring(idx))
		end,
	})
end
   ]]), { n = 0 })
end

return lualibs
