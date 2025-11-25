default: clean build test

build:
	./build.sh

clean:
	echo cleaning

test:
	tests/test.lua
