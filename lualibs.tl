local VirtualMachine = require'new_vm'

local lbaselib = require'lbaselib'
local lstrlib = require'lstrlib'
local liolib = require'liolib'

local record lualibs
	open: function(vm: VirtualMachine)
end

function lualibs.open(vm: VirtualMachine)
	lbaselib.open(vm)
	lstrlib.open(vm)
	liolib.open(vm)
end

return lualibs
