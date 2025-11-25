#!/usr/bin/lua

local tlc = require'the-tiny-lua-compiler'
local VirtualMachine = require'new_vm'
local baselib = require'lbaselib'

local source = [[
print(5 + 7)
]]


-- Tokenize: Raw text -> Stream of tokens
local tokens = tlc.Tokenizer.new(source):tokenize()

-- Parse: Stream of tokens -> Abstract Syntax Tree (AST)
local ast = tlc.Parser.new(tokens):parse()

-- Generate Code: AST -> Function Prototype (Intermediate Representation)
local proto = tlc.CodeGenerator.new(ast):generate()

local vm = VirtualMachine.new()

baselib.open(vm)

vm:execute(proto)

-- -- 3. Execution
-- -- Run the prototype in the Virtual Machine
-- tlc.VirtualMachine.new(proto):execute()

