default: clean build test

build:
	./build.sh

clean:
	echo cleaning

run:
	tl run ./lua.tl

test:
	tests/test.lua
