local VirtualMachine = require('new_vm')

local lbaselib = require('lbaselib')
local lstrlib = require('lstrlib')
local liolib = require('liolib')

local lualibs = {}



function lualibs.open(vm)
   lbaselib.open(vm)
   lstrlib.open(vm)
   liolib.open(vm)
end

return lualibs
