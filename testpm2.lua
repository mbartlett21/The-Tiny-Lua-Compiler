lpats = require'mjb_lpatterns'

lpats._DEBUG=2

local function teq(l, r)
	if l ~= r then
		print(string.format("l ~= r, %q ~= %q", l, r))
		error(string.format("l ~= r, %q ~= %q", l, r))
	end
end
teq(lpats.match('aaa', '.*a'), 'aaa')
teq(lpats.match('aaa', '.+a'), 'aaa')
teq(lpats.match('aba', 'ab*a'), 'aba')
teq(lpats.match('aaab', 'a+'), 'aaa')
teq(lpats.match('abcdefgh', 'b'), 'b')
