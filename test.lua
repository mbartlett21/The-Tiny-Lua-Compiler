

local tlc = require('the-tiny-lua-compiler')
local VirtualMachine = require('new_vm')
local baselib = require('lbaselib')

local source = [[
print(5 + 7)
]]



local tokens = tlc.Tokenizer.new(source):tokenize()


local ast = tlc.Parser.new(tokens):parse()


local proto = tlc.CodeGenerator.new(ast):generate()

local vm = VirtualMachine.new()

baselib.open(vm)

vm:execute(proto)
