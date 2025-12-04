lpats = require'mjb_lpatterns'


local function teq(l, r)
	if l ~= r then
		print(string.format("l ~= r, %q ~= %q", l, r))
		error(string.format("l ~= r, %q ~= %q", l, r))
	end
end
lpats._DEBUG=1
teq(lpats.match('aaa', '.*a'), 'aaa')
teq(lpats.match('aaa', '.+a'), 'aaa')
teq(lpats.match('aba', 'ab*a'), 'aba')
teq(lpats.match('abcdefgh', 'b'), 'b')
teq(lpats.match('aaab', 'a+'), 'aaa')
teq(lpats.match('abbb', 'bb-'), 'b')
