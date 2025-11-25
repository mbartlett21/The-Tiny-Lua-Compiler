local record Tokenizer
	code: string
	curCharPos: integer
	curChar: string

	interface Token
		kind: string
		value: any
	end

	new: function(string): Tokenizer
	getNextToken: function(self): Token
	tokenize: function(self): {Token}
end

local record Parser
	tokens: {Tokenizer.Token}
	currentTokenIndex: integer
	currentToken: Tokenizer.Token

	scopeStack: {any}
	currentScope: any

	interface Ast
		kind: string
		body: any
	end

	new: function({Tokenizer.Token}): Parser
	parse: function(self): Ast
end

local record CodeGenerator
	ast: Parser.Ast
	proto: any
	scopes: {any}
	currentScope: any
	stackSize: integer
	breakJumpPCs: any

	type Instr = {string,integer,integer,integer}

	interface Prototype
		code: {Instr}
		constants: {number|string}
		upvalues: {string}
		protos: {Prototype}
		numParams: integer
		maxStackSize: integer
		isVararg: boolean
		functionName: string

		-- note these don't represent the indices
		-- in the tables above directly
		constantLookup: {(number|string):integer}
		upvalueLookup: {string:integer}
	end

	new: function(Parser.Ast): CodeGenerator
	generate: function(self): Prototype
end

local record BytecodeEmitter
	new: function(CodeGenerator.Prototype): BytecodeEmitter
	emit: function(self): string
end

local record VirtualMachine
	new: function(CodeGenerator.Prototype): VirtualMachine
	execute: function(self): any
end

local record CompRet
	Tokenizer: Tokenizer
	Parser: Parser
	CodeGenerator: CodeGenerator
	BytecodeEmitter: BytecodeEmitter
	VirtualMachine: VirtualMachine

	fullCompile: function(string): string
	compileAndRun: function(string): any
end

return CompRet