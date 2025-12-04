local record lpats
    _DEBUG: integer

    enum CharTy 'char' end
    interface CharInstr where self.ty == 'char'
        ty: CharTy
        c: string
    end

    enum FrontierTy 'frontier' end
    interface FrontierInstr where self.ty == 'frontier'
        ty: FrontierTy
        pat: string
    end

    enum SplitTy 'split' end
    interface SplitInstr where self.ty == 'split'
        ty: SplitTy
        x: integer
        y: integer
    end

    enum PatTy 'pat' end
    interface PatInstr where self.ty == 'pat'
        ty: PatTy
        pat: string
    end

    enum JmpTy 'jmp' end
    interface JmpInstr where self.ty == 'jmp'
        ty: JmpTy
        pc: integer
    end

    enum JmpneTy 'jmpne' end
    interface JmpneInstr where self.ty == 'jmpne'
        ty: JmpneTy
        pc: integer
    end

    enum IncTy 'inc' end
    interface IncInstr where self.ty == 'inc'
        ty: IncTy
        c: string
    end

    enum DecTy 'dec' end
    interface DecInstr where self.ty == 'dec'
        ty: DecTy
        c: string
    end

    enum SetcapTy 'setcap' end
    interface SetcapInstr where self.ty == 'setcap'
        ty: SetcapTy
        cap: integer
    end

    enum DeccapTy 'deccap' end
    interface DeccapInstr where self.ty == 'deccap'
        ty: DeccapTy
        cap: integer
    end

    enum SaveTy 'save' end
    interface SaveInstr where self.ty == 'save'
        ty: SaveTy
        index: integer
    end

    enum MatchTy 'match' end
    interface MatchInstr where self.ty == 'match'
        ty: MatchTy
    end

    type Instr = CharInstr | FrontierInstr | SplitInstr | PatInstr | JmpInstr | JmpneInstr | IncInstr | DecInstr | SetcapInstr | DeccapInstr | SaveInstr | MatchInstr

    interface Instrs
        is {Instr}

        has_backreference: boolean
    end

    compile_pat: function(string): Instrs
    matchestv: function(str: string, pat: string | Instrs, start: integer): {integer:integer}

    match:  function(s: string, pat: string, init ?: integer): ((string|integer)...)
    find:   function(s: string, pat: string, init ?: integer, plain ?: boolean): integer, integer, (string|integer)...
    gmatch: function(s: string, pat: string, init ?: integer): function(): (string|integer)...
    gsub:   function(s: string, pat: string,
        repl: string | {(string|integer):string} | function((string|integer)...): ((string | integer | number)...) | number,
        n ?: integer): string, integer
end

lpats._DEBUG = nil

local type Instrs = lpats.Instrs

local type CharInstr     = lpats.CharInstr
local type FrontierInstr = lpats.FrontierInstr
local type SplitInstr    = lpats.SplitInstr
local type PatInstr      = lpats.PatInstr
local type JmpInstr      = lpats.JmpInstr
local type JmpneInstr    = lpats.JmpneInstr
local type IncInstr      = lpats.IncInstr
local type DecInstr      = lpats.DecInstr
local type SetcapInstr   = lpats.SetcapInstr
local type DeccapInstr   = lpats.DeccapInstr
local type SaveInstr     = lpats.SaveInstr
local type MatchInstr    = lpats.MatchInstr

-- only used for strstr and matching classes against single characters
local string_find = string.find

local pairs = pairs
local string_sub = string.sub
local table_insert = table.insert
local table_concat = table.concat
local table_unpack = table.unpack

local isop: {string:boolean} = {
    ['-'] = true,
    ['?'] = true,
    ['*'] = true,
    ['+'] = true,
}

local isspecial: {string:boolean} = {
    ['-'] = true,
    ['%'] = true,
    ['['] = true,
    [']'] = true,
    ['('] = true,
    [')'] = true,
    ['^'] = true,
}

local function esc(c: string): string
    if isspecial[c] then
        return '%' .. c
    else
        return c
    end
end

local function encode_char(instrs: Instrs, c: string)
    local cs = string_sub(c, 1, 2)
    if c ~= '.' and #c == 1 then
        table_insert(instrs, { ty = 'char', c = c })
    elseif cs == '%f' then
        local pat = '^' .. string_sub(c, 3) .. '$' --> ^[whatever]$
        table_insert(instrs, { ty = 'frontier', pat = pat })
    elseif cs == '%b' then
        local open = string_sub(c, 3, 3)
        local close = string_sub(c, 4, 4)

        if open == close then
            -- Balanced pattern example: %b""
            -- equivalent to "[^"]*"

            --                +-----+
            --                v     |
            -- START -> ["] ->S-> [^"]
            --                |
            --                +-> ["] -> END

            --         char    '"'
            --    spl: split   anyth  final
            --  anyth: pat     ^[^"]$
            --         jmp spl
            --  final: char    '"'

            -- note that the splits don't need priority since the patterns are exclusive

            local pat = '^[^' .. esc(open) .. ']$'

            local spl   = #instrs + 2
            local anyth = spl + 1
            local final = spl + 3

            --         char    '"'
            table_insert(instrs, { ty = 'char', c = open })

            --    spl: split   anyth  final
            table_insert(instrs, { ty = 'split', x = anyth, y = final })
            assert(#instrs == spl)

            --  anyth: pat     ^[^"]$ -- anything but quote
            table_insert(instrs, { ty = 'pat', pat = pat })
            assert(#instrs == anyth)

            --         jmp spl
            table_insert(instrs, { ty = 'jmp', pc = spl })

            --  final: char    '"'
            table_insert(instrs, { ty = 'char', c = close })
            assert(#instrs == final)
        else
            -- Balanced pattern example: %b()

            --                   +-----+---------+
            --                   v     |         |
            -- START -> inc[(] ->S-> [^()]       n
            --            ^      |               |
            --            +------+-> dec[)] -> empty? -y-> END

            --  openb: inc     '('
            --     lp: split   split2  anyth
            -- split2: split   openb   closeb
            --  anyth: pat     ^[^()]$ -- match anything but brackets
            --         jmp     lp
            -- closeb: dec     ')'
            --         jmpne   lp

            -- note that the splits don't need priority since the patterns are exclusive

            local pat = '^[^' .. esc(open) .. esc(close) .. ']$'

            local openb  = #instrs + 1
            local lp     = openb + 1
            local split2 = openb + 2
            local anyth  = openb + 3
            local closeb = openb + 5

            --  openb: inc     '('
            table_insert(instrs, { ty = 'inc', c = open })
            assert(#instrs == openb)

            --     lp: split   split2  anyth
            table_insert(instrs, { ty = 'split', x = split2, y = anyth })
            assert(#instrs == lp)

            -- split2: split   openb   closeb
            table_insert(instrs, { ty = 'split', x = openb, y = closeb })
            assert(#instrs == split2)

            --  anyth: pat     ^[^()]$ -- match anything but brackets
            table_insert(instrs, { ty = 'pat', pat = pat })
            assert(#instrs == anyth)

            --         jmp     lp
            table_insert(instrs, { ty = 'jmp', pc = lp })

            -- closeb: dec     ')'
            table_insert(instrs, { ty = 'dec', c = close })
            assert(#instrs == closeb)

            --         jmpne   lp
            table_insert(instrs, { ty = 'jmpne', pc = lp })
        end
    elseif cs == '%B' then
        -- extension to Lua patterns
        --
        -- essentially equivalent to ([^CD]|%bCD)-

        local open = string_sub(c, 3, 3)
        local close = string_sub(c, 4, 4)

        if open == close then
            -- example for %B""
            -- equivalent to ([^"]|%b"")-
            -- =             ([^"]|"[^"]*")-

            --         +-----+-----------------+
            --         v     |                 |
            -- START ->S-p1- | -> END          |
            --         |     |                 |
            --         +-> [^"]   * * * * * *  |
            --         |         *           * |
            --         |  * * * *  +-----+   * |
            --         | *         v     |   * |
            --         +--> ["] --->S-> [^"] * |
            --           *         |         * |
            --            * * * *  +-> ["] ----+
            --                   *           *
            --                    * * * * * * Encoded %b""

            --  start: split   endc   spl1
            --   spl1: split   anyo    openb
            --   anyo: pat     ^[^"]$
            --         jmp start
            --  openb: char    '"'
            --   spl2: split   anyth  final
            --  anyth: pat     ^[^"]$
            --         jmp spl2
            --  final: char    '"'
            --         jmp start
            --   endc:

            -- note that the balanced split doesn't need priority since the patterns are exclusive

            local pat = '^[^' .. esc(open) .. ']$'

            local start = #instrs + 1
            local spl1  = start + 1
            local anyo  = start + 2
            local openb = start + 4
            local spl2  = start + 5
            local anyth = start + 6
            local final = start + 8
            local endc  = start + 10

            --  start: split   endc   spl1
            table_insert(instrs, { ty = 'split', x = endc, y = spl1 })
            assert(#instrs == start)

            --   spl1: split   anyo    openb
            table_insert(instrs, { ty = 'split', x = anyo, y = openb })
            assert(#instrs == spl1)

            --   anyo: pat     ^[^"]$
            table_insert(instrs, { ty = 'pat', pat = pat })
            assert(#instrs == anyo)

            --         jmp start
            table_insert(instrs, { ty = 'jmp', pc = start })

            --  openb: char    '"'
            table_insert(instrs, { ty = 'char', c = open })
            assert(#instrs == openb)

            --   spl2: split   anyth  final
            table_insert(instrs, { ty = 'split', x = anyth, y = final })
            assert(#instrs == spl2)

            --  anyth: pat     ^[^"]$
            table_insert(instrs, { ty = 'pat', pat = pat })
            assert(#instrs == anyth)

            --         jmp spl2
            table_insert(instrs, { ty = 'jmp', pc = spl2 })

            --  final: char    '"'
            table_insert(instrs, { ty = 'char', c = close })
            assert(#instrs == final)

            --         jmp start
            table_insert(instrs, { ty = 'jmp', pc = start })

            --   endc:
            assert(#instrs + 1 == endc)
        else
            -- example for %B{}
            -- equivalent to ([^{}]|%b{})-

            --         +-----+-------------------------------+
            --         v     |                               |
            -- START ->S-p1- | -> END                        |
            --         |     |                               |
            --         +-> [^{}]    * * * * * * * * * * * *  |
            --         |           *                       * |
            --         |  * * * * *  +-----+---------+     * |
            --         | *           v     |         |     * |
            --         +--> inc[{] ->S-> [^{}]       n     * |
            --           *     ^     |               |     * |
            --            * *  +-----+-> dec[}] -> empty -y--+
            --               *                             *
            --                * * * * * * * * * * * * * * *
            --                          Encoded %b{}

            --  start: split   endc    spl1
            --   spl1: split   anyo    openb
            --   anyo: pat     ^[^{}]$
            --         jmp start
            --  openb: inc     '{'
            --     lp: split   split2  anyth
            -- split2: split   openb   closeb
            --  anyth: pat     ^[^{}]$ -- match anything but brackets
            --         jmp     lp
            -- closeb: dec     '}'
            --         jmpne   lp
            --         jmp     start
            --   endc:

            -- note that the balanced split doesn't need priority since the patterns are exclusive

            local pat = '^[^' .. esc(open) .. esc(close) .. ']$'

            local start  = #instrs + 1
            local spl1   = start + 1
            local anyo   = start + 2
            local openb  = start + 4
            local lp     = start + 5
            local split2 = start + 6
            local anyth  = start + 7
            local closeb = start + 9
            local endc   = start + 12

            --  start: split   endc    spl1
            table_insert(instrs, { ty = 'split', x = endc, y = spl1 })
            assert(#instrs == start)

            --   spl1: split   anyo    openb
            table_insert(instrs, { ty = 'split', x = anyo, y = openb })
            assert(#instrs == spl1)

            --   anyo: pat     ^[^()]$
            table_insert(instrs, { ty = 'pat', pat = pat })
            assert(#instrs == anyo)

            --         jmp start
            table_insert(instrs, { ty = 'jmp', pc = start })

            --  openb: inc     '('
            table_insert(instrs, { ty = 'inc', c = open })
            assert(#instrs == openb)

            --     lp: split   split2  anyth
            table_insert(instrs, { ty = 'split', x = split2, y = anyth })
            assert(#instrs == lp)

            -- split2: split   openb   closeb
            table_insert(instrs, { ty = 'split', x = openb, y = closeb })
            assert(#instrs == split2)

            --  anyth: pat     ^[^()]$
            table_insert(instrs, { ty = 'pat', pat = pat })
            assert(#instrs == anyth)

            --         jmp     lp
            table_insert(instrs, { ty = 'jmp', pc = lp })

            -- closeb: dec     ')'
            table_insert(instrs, { ty = 'dec', c = close })
            assert(#instrs == closeb)

            --         jmpne   lp
            table_insert(instrs, { ty = 'jmpne', pc = lp })

            --         jmp     start
            table_insert(instrs, { ty = 'jmp', pc = start })

            --   endc:
            assert(#instrs + 1 == endc)
        end
    elseif string_sub(c, 1, 1) == '%' and math.tointeger(string_sub(c, 2)) then
        -- we have a backreference
        local n = math.tointeger(string_sub(c, 2))
        if n == 0 then error'invalid capture index %0' end

        -- we need this so that we look at captures when deduplicating
        -- we don't always check the captures for time complexity.
        instrs.has_backreference = true

        -- we aren't inside a balanced setup, so the accumulator will currently be 0
        -- the instruction can assert that as well.

        -- todo: check that the capture exists at this point
        -- we also can't use in-progress captures or position captures

        -- note: captures can be zero-length, so adds an extra instr

        --                    deccap[2] <-+
        --                       |        n
        --                       |        |
        -- START -> setcap[2] ---+---> empty? -y-> END

        --      setcap    2
        --      jmp       lp
        --  mc: deccap    2
        --  lp: jmpne     mc

        local mc = #instrs + 3
        local lp = mc + 1

        -- we can use the accumulator to match previous patterns.
        --      setcap    2
        table_insert(instrs, { ty = 'setcap', cap = n })

        --      jmp       lp
        table_insert(instrs, { ty = 'jmp', pc = lp })

        --  mc: deccap    2
        table_insert(instrs, { ty = 'deccap', cap = n })
        assert(#instrs == mc)

        --  lp: jmpne     mc
        table_insert(instrs, { ty = 'jmpne', pc = mc })
        assert(#instrs == lp)
    else
        table_insert(instrs, { ty = 'pat', pat = '^' .. c .. '$' })
    end
end

-- second result indicates if it can be repeated
local function findclassend(pat: string, i: integer): integer, boolean
    local c = string_sub(pat, i, i)
    if c == '%' then
        local peek = string_sub(pat, i + 1, i + 1)
        if peek == 'f' then
            -- frontier pattern
            assert(string_sub(pat, i + 2, i + 2) == '[', 'malformed pattern: missing `[` after %f')
            return findclassend(pat, i + 2), false
        elseif peek == 'b' or peek == 'B' then
            -- balanced pattern
            -- next characters are opening and closing
            assert(string_sub(pat, i + 3, i + 3) ~= '', 'malformed pattern: need balanced characters')
            return i + 3, false
        elseif peek == '' then
            error('malformed pattern: expected class')
        end
        return i + 1, true
    elseif c == '[' then
        -- find a closing bracket that isn't escaped
        if string_sub(pat, i + 1, i + 1) == '^' then
            i = i + 2 -- skip the ^
        else
            i = i + 1
        end

        repeat
            local c2 = string_sub(pat, i, i)
            if c2 == '' then
                error('malformed pattern: missing `]`')
            elseif c2 == '%' then
                i = i + 1
            end
            i = i + 1
        until string_sub(pat, i, i) == ']'

        return i, true
    else
        return i, true
    end
end

--[[

We compile the pattern to a list of instructions. (the compile also takes account of anchored patterns)

For example, the pattern '^.-(%w+).*$' (extracting the first word) compiles to

-- start
    save    1
p1: split   m1  p2
p2: pat     ^.$     -- single character patterns we delegate to Lua's matching
    jmp     p1

-- pattern
m1: save    3
m2: pat     ^%w$
    split   m2  m3
m3: save    4

-- end
s1: split   s2  s3
s2: pat     ^.$
    jmp     s1
s3: save    2
    match
--]]

-- instructions:
-- { ty = 'char', c = char }            -- assert(curr == inst.c); pc ++; sp ++
-- { ty = 'frontier', pat = str }       -- assert(string.match(curr, inst.pat) and not string.match(prev, inst.pat)); pc ++; sp ++; start and end are treated as '\0'
-- { ty = 'pat', pat = str }            -- assert(string.match(curr, inst.pat)); pc ++; sp ++
-- { ty = 'match' }                     -- stop this thread. we have a match.
-- { ty = 'jmp', pc = int }             -- pc = inst.pc
-- { ty = 'split', x = int, y = int }   -- split execution to PC x and PC y (with the same string pointer). Prefer x
-- { ty = 'save', index = int }         -- save the current location; pc ++
-- { ty = 'inc', c = char }             -- assert(curr == inst.c); pc ++; depth += 1; sp ++
-- { ty = 'dec', c = char }             -- assert(depth > 0) assert(curr == inst.c); pc ++; depth -= 1; sp ++
-- { ty = 'jmpne', pc = int }           -- if depth != 0 then pc = inst.pc else pc ++ end

-- these also have instrs.has_backreference = true
-- { ty = 'setcap', cap = int }         -- bugif(depth != 0) depth = #captures[cap]; pc ++
-- { ty = 'deccap', cap = int }         -- bugif(depth == 0) assert(captures[cap]:sub(#cap-depth) = char); depth -= 1; sp ++

-- takes normal pattern syntax
local function compile_pat(pat: string): Instrs
    local groups = {}
    local groupn = 3 -- current group index. unrelated to #groups

    local instrs: Instrs = {}

    local i = 1

    -- check if the start is anchored
    if string_sub(pat, 1, 1) == '^' then
        -- nothing special
        i = i + 1
    else
        -- not anchored. Add equivalent of .-
        -- L1: split L3, L2
        -- L2: char c
        --     jmp L1
        -- L3:
        local l1idx = #instrs + 1
        local l2idx = l1idx + 1
        local l3idx = l2idx + 2
        table_insert(instrs, { ty = 'split', x = l3idx, y = l2idx })
        table_insert(instrs, { ty = 'pat', pat = '^.$' }) -- match any
        table_insert(instrs, { ty = 'jmp', pc = l1idx })
    end

    -- save the start location
    table_insert(instrs, { ty = 'save', index = 1 })

    while i <= #pat do
        local c = string_sub(pat, i, i)

        if i == #pat and c == '$' then -- anchored to the end
            break
        end

        -- find the class length
        local classend, can_have_mul = findclassend(pat, i)

        local str = string_sub(pat, i, classend)

        local peek = string_sub(pat, classend + 1, classend + 1)

        if c == '(' and peek == ')' then
            -- position only match
            local n = groupn
            groupn = groupn + 2
            -- we specify it by leaving the tail blank
            table_insert(instrs, { ty = 'save', index = n })
            i = i + 2
        elseif c == '(' then
            local n = groupn
            table_insert(groups, n + 1)
            groupn = groupn + 2
            table_insert(instrs, { ty = 'save', index = n })
            i = i + 1
        elseif c == ')' then
            local n = assert(table.remove(groups), 'invalid pattern capture')
            table_insert(instrs, { ty = 'save', index = n })
            i = i + 1
        elseif isop[c] then
            error'malformed pattern: character was an op'
        elseif isop[peek] then
            if not can_have_mul then
                error'malformed pattern: item cannot be multiple'
            end

            if peek == '?' then
                -- START ->S-p1-> char -+
                --         |            v
                --         +-p2------> END

                --     split L1, L2
                -- L1: ENCODE
                -- L2:

                local l1idx = #instrs + 2

                --     split L1, L2
                table_insert(instrs, {})

                assert(#instrs + 1 == l1idx)
                -- L1: ENCODE
                encode_char(instrs, str)

                -- fixup
                local l2idx = #instrs + 1
                instrs[l1idx - 1] = { ty = 'split', x = l1idx, y = l2idx }
            elseif peek == '+' then
                -- START -> char -> S-p2-> END
                --           ^      |
                --           +---p1-+

                -- L1: ENCODE
                --     split L1, L3
                -- L3:

                local l1idx = #instrs + 1

                -- L1: ENCODE
                encode_char(instrs, str)

                --     split L1, L3
                local l3idx = #instrs + 2
                table_insert(instrs, { ty = 'split', x = l1idx, y = l3idx })
            elseif peek == '*' then
                --         +------------+
                --         v            |
                -- START ->S-p1-> char -+
                --         |
                --         +-p2-> END

                -- L1: split L2, L3
                -- L2: ENCODE
                --     jmp L1
                -- L3:

                local l1idx = #instrs + 1
                local l2idx = l1idx + 1

                -- l1: split L2, L3
                table_insert(instrs, {}) -- filled out once we know the location
                assert(#instrs == l1idx)

                -- L2: ENCODE
                encode_char(instrs, str)

                --     jmp L1
                table_insert(instrs, { ty = 'jmp', pc = l1idx })

                -- fixup
                local l3idx = #instrs + 1
                instrs[l1idx] = { ty = 'split', x = l2idx, y = l3idx }
            elseif peek == '-' then -- nongreedy
                --         +------------+
                --         v            |
                -- START ->S-p2-> char -+
                --         |
                --         +-p1-> END

                -- L1: split L3, L2
                -- L2: ENCODE
                --     jmp L1
                -- L3:

                local l1idx = #instrs + 1
                local l2idx = l1idx + 1

                -- l1: split L3, L2
                table_insert(instrs, {}) -- filled out once we know the location
                assert(#instrs == l1idx)

                -- L2: ENCODE
                encode_char(instrs, str)

                --     jmp L1
                table_insert(instrs, { ty = 'jmp', pc = l1idx })

                -- fixup
                local l3idx = #instrs + 1
                instrs[l1idx] = { ty = 'split', x = l3idx, y = l2idx }
            else
                error'unreachable'
            end
            i = classend + 2
        else
            encode_char(instrs, str)
            i = classend + 1
        end
    end

    assert(not groups[1], 'unfinished capture')

    -- save the end location
    table_insert(instrs, { ty = 'save', index = 2 })

    if i == #pat then -- end was $
        assert(string_sub(pat, i, i) == '$')
    else -- end wasn't that. we add the equivalent of .* on the end
        -- L1: split L2, L3
        -- L2: char c
        --     jmp L1
        -- L3:
        local l1idx = #instrs + 1
        local l2idx = l1idx + 1
        local l3idx = l2idx + 2
        table_insert(instrs, { ty = 'split', x = l2idx, y = l3idx })
        table_insert(instrs, { ty = 'pat', pat = '^.$' }) -- match any
        table_insert(instrs, { ty = 'jmp', pc = l1idx })
    end

    table_insert(instrs, { ty = 'match' })

    return instrs
end

lpats.compile_pat = compile_pat

--[[

local function matchesrb(str: string, pat: string | Instrs, start: integer): {integer:integer}
    local instrs: Instrs
    if pat is string then
        instrs = compile_pat(pat)
    else
        instrs = pat
    end

    local saved: {integer:integer} = {}

    -- recursive backtracking

    local function recursive(pc: integer, sp: integer, sc: integer): boolean
        local c = string_sub(str, sp, sp)

        local inst = assert(instrs[pc])

        -- instructions:
        -- { ty = 'char', c = char }            -- assert(curr == inst.c); pc ++; sp ++
        -- { ty = 'frontier', pat = str }       -- assert(string.match(curr, inst.pat) and not string.match(prev, inst.pat)); pc ++; sp ++; start and end are treated as '\0'
        -- { ty = 'pat', pat = str }            -- assert(string.match(curr, inst.pat)); pc ++; sp ++
        -- { ty = 'match' }                     -- stop this thread. we have a match.
        -- { ty = 'jmp', pc = int }             -- pc = inst.pc
        -- { ty = 'split', x = int, y = int }   -- split execution to PC x and PC y (with the same string pointer). Prefer x
        -- { ty = 'save', index = int }         -- save the current location; pc ++
        -- { ty = 'inc', c = char }             -- assert(curr == inst.c); pc ++; depth += 1; sp ++
        -- { ty = 'dec', c = char }             -- assert(depth > 0) assert(curr == inst.c); pc ++; depth -= 1; sp ++
        -- { ty = 'jmpne', pc = int }           -- if depth != 0 then pc = inst.pc else pc ++ end

        -- these also have instrs.has_backreference = true
        -- { ty = 'setcap', cap = int }         -- bugif(depth != 0) depth = #captures[cap]; pc ++
        -- { ty = 'deccap', cap = int }         -- bugif(depth == 0) assert(captures[cap]:sub(#cap-depth) = char); depth -= 1; sp ++
        if inst is CharInstr then
            if inst.c ~= c then return false end
            return recursive(pc + 1, sp + 1, sc)
        elseif inst is PatInstr then
            if not string_find(c, inst.pat) then return false end
            return recursive(pc + 1, sp + 1, sc)
        elseif inst is FrontierInstr then
            local prev = string_sub(str, sp - 1, sp - 1)
            if prev == '' then prev = '\0' end
            if c == '' then c = '\0' end
            local fpat = inst.pat
            if string_find(c, fpat) and not string_find(prev, fpat) then
                return recursive(pc + 1, sp, sc)
            else
                return false
            end
        elseif inst is MatchInstr then
            -- assert that we are at the end
            return c == ''
        elseif inst is JmpInstr then
            return recursive(inst.pc, sp, sc)
        elseif inst is SplitInstr then
            if recursive(inst.x, sp, sc) then
                return true
            end
            return recursive(inst.y, sp, sc)
        elseif inst is SaveInstr then
            local idx = inst.index
            local old = saved[idx]
            saved[idx] = sp
            if recursive(pc + 1, sp, sc) then
                return true
            end
            saved[idx] = old
            return false
        elseif inst is IncInstr then
            if inst.c ~= c then return false end
            return recursive(pc + 1, sp + 1, sc + 1)
        elseif inst is DecInstr then
            if inst.c ~= c or sc <= 0 then return false end
            return recursive(pc + 1, sp + 1, sc - 1)
        elseif inst is JmpneInstr then
            if sc ~= 0 then
                return recursive(inst.pc, sp, sc)
            else
                return recursive(pc + 1, sp, sc)
            end
        elseif inst is SetcapInstr then
            -- set the depth to that capture
            assert(sc == 0)
            local cap = inst.cap
            -- check that we have saved data
            local saved1 = saved[cap * 2 + 1]
            local saved2 = saved[cap * 2 + 2]
            if saved1 and saved2 then
                return recursive(pc + 1, sp, saved2 - saved1)
            end
        elseif inst is DeccapInstr then
            assert(sc ~= 0)
            local idx = saved[inst.cap * 2 + 2] - sc
            local capc = string_sub(str, idx, idx)
            assert(capc ~= '')
            if c == capc then
                -- continue
                return recursive(pc + 1, sp + 1, sc - 1)
            end
        else
            error('unsupported instruction: ' .. tostring((inst as table).ty))
        end
    end

    if recursive(1, start or 1, 0) then
        -- extract matches
        return saved
    end
    return
end

]]

-- thompson/pike vm implementation
local function matchestv(str: string, pat: string | Instrs, start: integer): {integer:integer}
    local instrs: Instrs
    if pat is string then
        instrs = compile_pat(pat)
    else
        instrs = pat
    end

    if lpats._DEBUG then
        print('matchestv', str, pat)

        require'pprint'(instrs)
    end

    local interface ListV
        pc: integer
        sc: integer
        saved: {integer:integer}
    end

    local interface List
        is {ListV}
        n: integer
    end

    local clist: List = { n = 0 }
    local nlist: List = { n = 0 }

    local function addthread(list: List, sp: integer, pc: integer, sc: integer, saved: {integer:integer})
        ::start::
        for i = 1, list.n do
            local li = list[i]
            if li.pc == pc and li.sc == sc then
                if not instrs.has_backreference then
                    return
                end
                -- check that the captures are the same
                for k, v in pairs(li.saved) do
                    if saved[k] ~= v and k > 2 then
                        goto nomatch
                    end
                end

                -- check for keys in th.saved that don't match with li.saved
                for k in pairs(saved) do
                    if not li.saved[k] and k > 2 then -- the start of the pattern doesn't matter since it can't be referenced
                        goto nomatch
                    end
                end

                return
            end
            ::nomatch::
        end

        local inst = instrs[pc]

        if inst is JmpInstr then
            pc = inst.pc
            goto start
        elseif inst is SplitInstr then
            addthread(list, sp, inst.x, sc, saved) -- add to the current list
            pc = inst.y
            goto start
        elseif inst is SaveInstr then
            local idx = inst.index
            local saved2 = {}
            for k, v in pairs(saved) do
                saved2[k] = v
            end
            saved2[idx] = sp
            pc = pc + 1
            saved = saved2
            goto start
        elseif inst is FrontierInstr then
            local c = string_sub(str, sp, sp)
            local prev = string_sub(str, sp - 1, sp - 1)
            if prev == '' then prev = '\0' end
            if c == '' then c = '\0' end
            local fpat = inst.pat
            if string_find(c, fpat) and not string_find(prev, fpat) then
                pc = pc + 1
                goto start
            end
        elseif inst is JmpneInstr then
            if sc ~= 0 then
                pc = inst.pc
            else
                pc = pc + 1
            end
            goto start
        elseif inst is SetcapInstr then
            -- set the depth to that capture
            assert(sc == 0)
            local cap = inst.cap
            -- check that we have saved data
            local saved1 = saved[cap * 2 + 1]
            local saved2 = saved[cap * 2 + 2]
            if saved1 and saved2 then
                pc = pc + 1
                sc = saved2 - saved1
                goto start
            else
                error('invalid capture index %' .. cap) -- should actually error in the compile
            end
        else
            local n = list.n + 1
            list.n = n
            local th = list[n]
            if th then
                th.pc = pc
                th.sc = sc
                th.saved = saved
            else
                list[n] = { pc = pc, sc = sc, saved = saved }
            end
        end
    end

    addthread(clist, start or 1, 1, 0, {})

    for sp = start or 1, #str + 1 do
        if lpats._DEBUG then
            print('sp = ' .. sp)
            print('#threads = ' .. clist.n)
            if lpats._DEBUG >= 2 then
                for i = 1, clist.n do
                    print(clist[i].pc .. ' = ' .. tostring((instrs[clist[i].pc] as table).ty))
                end
            end
            print()
        end
        local c = string_sub(str, sp, sp)

        -- run current list
        for i = 1, clist.n do
            local th = clist[i]
            local pc = th.pc
            local inst = assert(instrs[pc])

            -- instructions:
            -- { ty = 'char', c = char }            -- assert(curr == inst.c); pc ++; sp ++
            -- { ty = 'frontier', pat = str }       -- assert(string.match(curr, inst.pat) and not string.match(prev, inst.pat)); pc ++; sp ++; start and end are treated as '\0'
            -- { ty = 'pat', pat = str }            -- assert(string.match(curr, inst.pat)); pc ++; sp ++
            -- { ty = 'match' }                     -- stop this thread. we have a match.
            -- { ty = 'jmp', pc = int }             -- pc = inst.pc
            -- { ty = 'split', x = int, y = int }   -- split execution to PC x and PC y (with the same string pointer). Prefer x
            -- { ty = 'save', index = int }         -- save the current location; pc ++
            -- { ty = 'inc', c = char }             -- assert(curr == inst.c); pc ++; depth += 1; sp ++
            -- { ty = 'dec', c = char }             -- assert(depth > 0) assert(curr == inst.c); pc ++; depth -= 1; sp ++
            -- { ty = 'jmpne', pc = int }           -- if depth != 0 then pc = inst.pc else pc ++ end

            -- these also have instrs.has_backreference = true
            -- { ty = 'setcap', cap = int }         -- bugif(depth != 0) depth = #captures[cap]; pc ++
            -- { ty = 'deccap', cap = int }         -- bugif(depth == 0) assert(captures[cap]:sub(#cap-depth) = char); depth -= 1; sp ++
            if inst is CharInstr then
                if c == inst.c then -- keep going in the next iter
                    addthread(nlist, sp + 1, pc + 1, th.sc, th.saved) -- do what the sp will be in the next iter
                end
            elseif inst is PatInstr then
                if string_find(c, inst.pat) then
                    addthread(nlist, sp + 1, pc + 1, th.sc, th.saved) -- do what the sp will be in the next iter
                end
            elseif inst is MatchInstr then
                -- assert that we are at the end of the string
                if c == '' then
                    return th.saved
                end
            elseif inst is IncInstr then
                if c == inst.c then
                    addthread(nlist, sp + 1, pc + 1, th.sc + 1, th.saved)
                end
            elseif inst is DecInstr then
                if c == inst.c and th.sc > 0 then
                    addthread(nlist, sp + 1, pc + 1, th.sc - 1, th.saved)
                end
            elseif inst is DeccapInstr then
                assert(th.sc ~= 0)
                local idx = th.saved[inst.cap * 2 + 2] - th.sc
                local capc = string_sub(str, idx, idx)
                assert(capc ~= '')
                if c == capc then
                    -- continue
                    addthread(nlist, sp + 1, pc + 1, th.sc - 1, th.saved)
                end
            else
                -- jmp, save and split are handled by addthread
                error('unsupported instruction: ' .. tostring((inst as table).ty))
            end
            i = i + 1
        end

        clist, nlist = nlist, clist
        nlist.n = 0
    end

    return
end

lpats.matchestv = matchestv

-- assert(matchestv('[[qwerqwer]]qwe[rqwer]qwer[qwerqwe[]reqwr[r[r[r]]]]', '^%B[]$'))

local function process_matches(s: string, results: {integer:integer}, include_full: boolean): ((string|integer)...)
    if results[3] then
        local strs: {string|integer} = {}
        local i = 3
        while results[i] do
            local start = results[i]
            local e = results[i + 1]
            if not e then -- position only match
                strs[i // 2] = start
            else
                strs[i // 2] = string_sub(s, start, e - 1)
            end
            i = i + 2
        end
        return table_unpack(strs)
    elseif include_full then
        return string_sub(s, results[1], results[2] - 1)
    end
end

lpats.match = function(s: string, pat: string, init ?: integer): ((string|integer)...)
    init = init or 1
    if init < 0 then init = #s + init + 1 end

    local results = matchestv(s, pat, init)

    if not results then
        return nil
    else
        return process_matches(s, results, true)
    end
end

lpats.find = function(s: string, pat: string, init ?: integer, plain ?: boolean): integer, integer, (string|integer)...
    if plain then return string_find(s, pat, init, plain) end
    init = init or 1
    if init < 0 then init = #s + init + 1 end

    local results = matchestv(s, pat, init)

    if not results then
        return nil
    else
        return results[1], results[2] - 1, process_matches(s, results, false)
    end
end

lpats.gmatch = function(s: string, pat: string, init ?: integer): function(): (string|integer)...
    init = init or 1
    if init < 0 then init = #s + init + 1 end

    local olen = #s

    local emptyallowed = true
    local function iter(): ((string|integer)...)
        if init > olen + 1 then return nil end
        local results = matchestv(s, pat, init)

        if not results then
            return nil
        else
            -- length of the match is 0 and we are immediately after the previous match
            -- note that results[1] is always <= results[2]
            if results[2] == init and not emptyallowed then
                init = init + 1
                emptyallowed = true
                return iter()
            end
            init = results[2]
            emptyallowed = false

            return process_matches(s, results, true)
        end
    end

    return iter
end

lpats.gsub = function(s: string, pat: string,
        repl: string | {(string|integer):string} | function((string|integer)...): ((string | integer | number)...) | number,
        n ?: integer): string, integer
    n = n or math.maxinteger
    local hadsub = false

    local repl2: function(string, (string|integer)...): string|number

    if repl is string then
        local srepl = repl
        repl2 = function(m0: string, m1: string|integer, m2: string|integer, m3: string|integer, m4: string|integer, m5: string|integer, m6: string|integer, m7: string|integer, m8: string|integer, m9: string|integer): string
            hadsub = true
            local replacement: {(string|integer)} = {}
            local i = 1
            -- using string.find for memchr
            ::loop::
            local loc = string_find(srepl, '%', i, true) -- plaintext
            if not loc then
                table_insert(replacement, string_sub(srepl, i))
                return table_concat(replacement)
            else
                table_insert(replacement, string_sub(srepl, i, loc - 1))
                local nex = string_sub(srepl, loc + 1, loc + 1)
                if nex == '%' then
                    table_insert(replacement, '%')
                elseif nex == '0' then
                    table_insert(replacement, m0)
                elseif nex == '1' then
                    table_insert(replacement, (m1 or m0))
                elseif nex == '2' then
                    table_insert(replacement, (assert(m2, 'invalid capture index %2')))
                elseif nex == '3' then
                    table_insert(replacement, (assert(m3, 'invalid capture index %3')))
                elseif nex == '4' then
                    table_insert(replacement, (assert(m4, 'invalid capture index %4')))
                elseif nex == '5' then
                    table_insert(replacement, (assert(m5, 'invalid capture index %5')))
                elseif nex == '6' then
                    table_insert(replacement, (assert(m6, 'invalid capture index %6')))
                elseif nex == '7' then
                    table_insert(replacement, (assert(m7, 'invalid capture index %7')))
                elseif nex == '8' then
                    table_insert(replacement, (assert(m8, 'invalid capture index %8')))
                elseif nex == '9' then
                    table_insert(replacement, (assert(m9, 'invalid capture index %9')))
                else
                    error 'invalid use of \'%\' in replacement string'
                end

                i = loc + 2
                goto loop
            end
        end
    elseif repl is number then
        local num = repl
        repl2 = function(): number hadsub = true return num end
    elseif repl is {string|integer:string} then
        local t = repl
        repl2 = function(m0: string, m1: string|integer): string|number
            local tex = t[m1 or m0] as string|number
            if tex then hadsub = true end
            return tex or m0
        end
    elseif repl is function then
        local f = repl as function(...: any): string|number|boolean
        repl2 = function(m0: string, m1: string|integer, ...: string|integer): string|number
            local result: string|number|boolean
            if m1 then
                result = f(m1, ...)
            else
                result = f(m0)
            end
            if not result then -- nil or false
                return m0
            else
                hadsub = true
                return result as string|number
            end
        end
    end

    local final: {(string|number)} = {}
    local emptyallowed = true
    local init = 1
    local olen = #s

    local numdone = 0

    while init <= olen + 1 do
        local results: {integer:integer}

        if n > numdone then
            results = matchestv(s, pat, init)
        end

        if not results then
            -- finished
            table_insert(final, string_sub(s, init))
            break
        else
            -- length of the match is 0 and we are immediately after the previous match
            -- note that results[1] is always <= results[2]
            if results[2] == init and not emptyallowed then
                table_insert(final, string_sub(s, init, init))
                init = init + 1
                emptyallowed = true
                goto next
            end
            emptyallowed = false

            table_insert(final, string_sub(s, init, results[1] - 1))
            table_insert(final, repl2(string_sub(s, results[1], results[2] - 1), process_matches(s, results, false)))
            init = results[2]
            numdone = numdone + 1
        end
        ::next::
    end

    if not hadsub then return s, numdone end

    return table_concat(final), numdone
end

--[[
do -- tests
    local matches = matchesrb
    local matches = matchestv
    assert(matches('test', 'test'))
    assert(not matches('test', 'tes'))
    assert(not matches('test', 'tested'))

    assert(matches('test     ', 'test +'))
    assert(matches('test', 'test ?'))
    assert(matches('test ', 'test ?'))
    assert(matches('test     ', 'test *'))
    assert(matches('test     ', 'test -'))
    assert(matches('___test___', '_*test_*'))

    local function assert_eq(l, r, err)
        if l ~= r then
            local err = string.format('%q ~= %q', l, r) .. (err and (': ' .. err) or '')
            error(err, 2)
        end
    end

    assert_eq(matches('_testion1234_', '_(%w*)%w%w%w%d..._'), 'test')

    assert_eq(matches('<testing><testing>', '(<.->).*'), '<testing>')
    assert_eq(matches('<testing><testing>', '(<.*>).*'), '<testing><testing>')

    -- this example requires the parser to have correct ordering
    assert_eq(matches('<><testing><testing>', '(<>*.->).*'), '<><testing>')
    assert(matches('_testion1234_', '_%w*%w%w%w%d..._'))

    local r1, r2, r3 = matches('test', '((t)e(st))')
    assert_eq(r1, 'test',   'submatch 1 did not work')
    assert_eq(r2, 't',      'submatch 2 did not work')
    assert_eq(r3, 'st',     'submatch 3 did not work')

    local r1, r2, r3 = matches('teeest', '((t?)te-(e*st))')
    assert_eq(r1, 'teeest',   'submatch 1 did not work')
    assert_eq(r2, '',      'submatch 2 did not work')
    assert_eq(r3, 'eeest',     'submatch 3 did not work')

    -- test timing

    local function tt(name, f, ...)
        local start = os.clock()
        assert(f(...))
        local e = os.clock()
        print(name, e - start)
    end

    for i = 1, 20 do
        print(i)
        local str = string.rep('a', i)
        local pat = string.rep('a?', i) .. string.rep('a', i)
        tt('string.match', string.match, str, pat)
        tt('new matchfun', matches, str, pat)
    end

    for i = 30, 100, 10 do
        print(i)
        local str = string.rep('a', i)
        local pat = string.rep('a?', i) .. string.rep('a', i)

        -- tt('string.match', string.match, str, pat)
        tt('new matchfun', matches, str, pat)
    end

end
--]]

return lpats
