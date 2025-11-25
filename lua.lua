local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local io = _tl_compat and _tl_compat.io or io; local os = _tl_compat and _tl_compat.os or os; local pcall = _tl_compat and _tl_compat.pcall or pcall; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local tlc = require('the-tiny-lua-compiler')
local VirtualMachine = require('new_vm')



local lualibs = require('lualibs')

local function print_usage()
   print(string.format([=[
usage: %s [options] [script [args]].
Available options are:
  -e stat  execute string  LUA_QL(stat)
  -l name  require library  LUA_QL(name)
  -i       enter interactive mode after executing  LUA_QL(script)
  -v       show version information
  --       stop handling options
  -        execute stdin and stop handling options]=], arg[0]))
   io.output():flush()
end

local function print_version()
   print('Lua X.X Copyright')
end

local function dostring(vm, s, _name)
   local tokens = tlc.Tokenizer.new(s):tokenize()
   local ast = tlc.Parser.new(tokens):parse()
   local proto = tlc.CodeGenerator.new(ast):generate()

   local _res = vm:execute(proto)


end

local function dolibrary(vm, name)
   local g = vm.globalSetup._G
   local req = g.values["require"]
   local res = vm:simple_call(req, { n = 1, name })
   if res.n >= 1 then
      g.values[name] = res[1]
   end
end

local function handle_script(vm, args, n)
   local args_pt = { n = #args - n }
   local argtbl = vm:simple_newtable()
   for i = 1, #args do
      argtbl.values[i - n] = args[i]
      if i > n then
         args_pt[i - n] = args[i]
      end
   end
   vm.globalSetup._G.values.arg = argtbl

   local fname = args[n]
   if fname == '-' and args[n - 1] ~= '--' then
      fname = nil
   end

   local contents
   if fname then
      contents = assert(assert(io.open(fname, "rb")):read("*a"))
   else
      contents = io.read("*a")
   end

   print(string.format("%q", contents))

   local tokens = tlc.Tokenizer.new(contents):tokenize()
   local ast = tlc.Parser.new(tokens):parse()
   local proto = tlc.CodeGenerator.new(ast):generate()

   local _res = vm:execute(proto, args_pt)
end

local function runf(vm, buf)
   local tokens = tlc.Tokenizer.new(buf):tokenize()
   local ast = tlc.Parser.new(tokens):parse()
   local proto = tlc.CodeGenerator.new(ast):generate()

   local res = vm:execute(proto)
   if res.n > 0 then
      local p = vm.globalSetup._G.values.print
      vm:simple_call(p, res)
   end
end

local function dotty(vm)


   while true do
      local buf = ''
      while true do
         io.write(buf == '' and '> ' or '>>')
         io.output():flush()
         local l = io.read()
         if buf == '' then
            if l:sub(1, 1) == '=' then
               buf = 'return ' .. l:sub(2)
            else
               buf = l
            end
         elseif l:match('^%s+$') then
            break
         else
            buf = buf .. '\n' .. l
         end
      end

      print(string.format('%q', buf))

      local worked, err = pcall(runf, vm, buf)
      if not worked then
         print("Error: " .. err)
      end
   end
end

local vm = VirtualMachine.new()
lualibs.open(vm)

local script = 0
local has_i
local has_v
local has_e

local i = 1
while i <= #arg do
   local s = arg[i]
   if s:sub(1, 1) ~= "-" then
      script = i
      break
   end

   local c = s:sub(2, 2)
   if c == "-" then
      script = arg[i + 1] and i + 1
      break
   elseif c == "" then
      script = i
      break
   elseif c == "i" then
      has_i = true
   elseif c == "v" then
      has_v = true
   elseif c == "e" or c == "l" then
      if c == "e" then has_e = true end
      if #s == 2 then
         i = i + 1
         if not arg[i] then
            script = nil
            break
         end
      end
   else
      script = nil
      break
   end

   i = i + 1
end

if not script then
   print_usage()
   os.exit(1)
end

if has_v then
   print_version()
end


i = 1
while i < #arg do
   local s = arg[i]
   assert(s:sub(1, 1) == "-")
   local c = s:sub(2, 2)
   if c == "e" then
      local rest = s:sub(3)
      if rest == "" then
         i = i + 1
         rest = arg[i]
      end
      if not dostring(vm, rest, "=(command line") then
         error("")
      end
   elseif c == "l" then
      local rest = s:sub(3)
      if rest == "" then
         i = i + 1
         rest = arg[i]
      end
      if not dolibrary(vm, rest) then
         error("")
      end
   end
   i = i + 1
end

if script and script ~= 0 then
   handle_script(vm, arg, script)
end

if has_i then
   dotty(vm)
elseif script == 0 and not has_e and not has_v then
   print_version()
   dotty(vm)



end
