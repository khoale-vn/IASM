lpeg = require "lpeg"
inspect = require "inspect/inspect"

P = lpeg.P
R = lpeg.R
C = lpeg.C
V = lpeg.V
S = lpeg.S
Ct = lpeg.Ct
Cmt = lpeg.Cmt



debug = false



function tonegnumber(number)
    return number | 0x80
end

function tonumber8bit(value)
    local number = tonumber(value)
    if number == nil then
        number = tonumber(value, 16)
        if number == nil and value:sub(-1,-1) == "h" then
            number = tonumber(value:sub(-1,-1), 16)
        end
    end
    
    if number > 0xFF then
        print("ERROR: value out of 8bit")
        os.exit()
    end
    
    return number
end

function convert_char(value, value_escape)
    value = value:gsub("\\n", "\n")
    value = value:gsub("\\t", "\t")
    value = value:gsub("\\r", "\r")
    value = value:gsub("\\a", "\a")
    value = value:gsub("\\b", "\b")
    value = value:gsub("\\\\", "\\")
    value = value:gsub("\\\"", "\"")
    value = value:gsub("\\\'", "\'")
    value = value:gsub("\\(%d%d?%d?)", function(x) return string.char(tonumber(x)) end)
    
    local number, escape = string.byte(value, 2, -2)
    
    if number > 0xFF then
        print("ERROR: unknown character")
        os.exit()
    end
    return number
end

function generate_ram(x)
    local zram = {}
    for i=0,x-1 do
        table.insert(zram, 0)
    end
    return zram
end

grammar = P({
    "start",
    start = (V("comment") + V("cmd") + V("EOL"))^0,
    cmd = (
          V("add")
        + V("mov")
        + V("sub")
        + V("mul")
        + V("muh") 
        + V("div") 
        + V("mod") 
        + V("cmp") 
        + V("jmp") 
        + V("jeq") 
        + V("jne") 
        + V("jgr") 
        + V("jls") 
        + V("jgn") 
        + V("jln") 
        + V("label") 
        + V("ldr") 
        + V("int") 
        + V("psh") 
        + V("pop")
        + V("define")
        + V("jsr")
        + V("ret")
        ) * V("EOL"),
    mov = C(P("mov")) * V("WS") * V("register") * P(", ") * V("value"),
    ldr = C(P("mov")) * V("WS") * V("address") * P(", ") * V("value"),
    add = C(P("add")) * V("WS") * V("register") * P(", ") * V("value"),
    sub = C(P("sub")) * V("WS") * V("register") * P(", ") * V("value"),
    mul = C(P("mul")) * V("WS") * V("register") * P(", ") * V("value"),
    muh = C(P("muh")) * V("WS") * V("register") * P(", ") * V("value"),
    div = C(P("div")) * V("WS") * V("register") * P(", ") * V("value"),
    mod = C(P("mod")) * V("WS") * V("register") * P(", ") * V("value"),
    
    jmp = C(P("jmp")) * V("WS") * C(V("name")),
    cmp = C(P("cmp")) * V("WS") * V("value") * P(", ") * V("value"),
    jeq = C(P("jeq")) * V("WS") * C(V("name")),
    jne = C(P("jne")) * V("WS") * C(V("name")),
    jgr = C(P("jgr")) * V("WS") * C(V("name")),
    jls = C(P("jls")) * V("WS") * C(V("name")),
    jgn = C(P("jgn")) * V("WS") * C(V("name")),
    jln = C(P("jgn")) * V("WS") * C(V("name")),
    
    jsr = C(P("jsr")) * V("WS") * C(V("name")),
    ret = C(P("ret")),
    
    psh = C(P("psh")) * V("WS") * V("value"),
    pop = C(P("pop")) * V("WS") * V("memory"),
    
    int = C(P("int")) * V("WS") * V("immediate"),
    
    label = C(V("name") * P(":")),
    define = C(V("name")) * V("WS") * C(P("db")) * V("WS") * V("value"),
    
    
    value = V("char") + V("hex") + V("number") + V("neg_number") + V("address") + V("register") + V("define_name"),
    immediate = V("hex") + V("number"),
    memory = V("address") + V("register"),
    define_name = C(V("name")) / function(x) return "<"..x..">" end - V("register") - V("char") - V("hex"),
    
    neg_number = P("-") * V("number") / tonegnumber,
    number = C(V("digit")^1) / tonumber8bit,
    digit = R("09"),
    hex = ((P("0x") * (C(V("hex_digit")^1))) + ((C(V("hex_digit")^1)) * P("h"))) / tonumber8bit,
    hex_digit = R("09") + R("AF") + R("af"),
    
    char = C(V("char_double") + V("char_single")) / convert_char,
    char_double = P("\"") * (V("char_escape") + R("\0\xFF")) * P("\""),
    char_single = P("\'") * (V("char_escape") + R("\0\xFF")) * P("\'"),
    char_escape = P("\\") * R("\0\xFF") / function(x) return x:sub(2,-1) end,
    
    
    register = C(V("regA") + V("regB") + V("regC") + V("regD")),
    regA = P("A"),
    regB = P("B"),
    regC = P("C"),
    regD = P("D"),
    
    name = (R("AZ") + R("az") + P("_") * (R("AZ") + R("az") + P("_") + R("09"))^0)^1,
    address = C(P("[") * ((P("0x") * (V("hex_digit")^1)) + (V("digit")^1)) * P("]")) + V("define_name"),
    
    
    comment = C(P(";")) * (P(1) - P("\n"))^0 * C(P("\n")) / function(x,y) return "[ID: comment]" end,

    
    WS = P(" "),
    EOL = C(P("\n")),
})


ram = generate_ram(2^8)

reg = {
    A = 0,
    B = 0,
    C = 0,
    D = 0,
    S = #ram - 1,
}

flags = {
    Z = 0,
    C = 0,
    N = 0,
    V = 0
}

--<< SYSTEM >>--

iot = {}
iot.output = {}
iot.input = {}
iot.output.char = function(a)
    io.write(string.char(a))
end
iot.input.char = function()
    return string.byte(io.read())
end


--<< PARSER >>--

function parser(tree)
    --<< init >>--
    
    jumptable = {}
    empty_stack = true
    
    definetable = {}
    data_section = 0
    
    --<< function >>--
    
    
    local function get_reg(name)
        if name=="A" then
            return 0
        elseif name=="B" then
            return 1
        elseif name=="C" then
            return 2
        elseif name=="D" then
            return 3
        else
            return nil
        end
    end
    local function is_reg(name)
        if name == "A" or name == "B" or name == "C" or name == "D" then
            return true
        else
            return false
        end
    end
    local function get_reg_value(name)
        if name=="A" then
            return reg.A
        elseif name=="B" then
            return reg.B
        elseif name=="C" then
            return reg.C
        elseif name=="D" then
            return reg.D
        else
            return nil
        end
    end
    local function valid_reg_value()
        reg.A = reg.A & 0xFF
        reg.B = reg.B & 0xFF
        reg.C = reg.C & 0xFF
        reg.D = reg.D & 0xFF
    end
    local function check_neg_flag(value)
        value = value & 0xFF
        if value > 127 then
            flags.N = 1
        elseif value <= 127 then
            flags.N = 0
        end
    end
    local function check_o_flag_add(a,b)
        local c = (a + b) & 0xFF
        if (a < 127 and b < 127 and c >= 127) or (a >= 127 and b >= 127 and c < 127) then
            flags.V = 1
        else
            flags.V = 0
        end
    end
    
    local function check_o_flag_sub(a,b)
        a = a & 0xFF
        b = b & 0xFF
        local c = (a + ((~b + 1) & 0xFF)) & 0xFF
        if (a < 127 and b >= 127 and c >= 127) or (a >= 127 and b < 127 and c < 127) then
            flags.V = 1
        else
            flags.V = 0
        end
    end
    
    local function check_carry_flag(value)
        if value > 0xFF then
            flags.C = 1
        else
            flags.C = 0
        end
    end
    
    local function check_zero_flag(value)
        value = value & 0xFF
        if value == 0 then
            flags.Z = 1
        else
            flags.Z = 0
        end
    end
    
    local function find_label()
        for i=1,#tree do
            if type(tree[i]) == "string" then
                if string.sub(tree[i], -1) == ":" then
                    local str = tree[i]:sub(1, -2)
                    table.insert(jumptable, {str, i})
                elseif tree[i] == "[ID: comment]" then
                    table.remove(tree, i)
                end
            end
        end
    end
    
    local function is_address(value)
        if type(value) == "string" then
            if value:sub(1,1) == "[" and value:sub(-1,-1) == "]" then
                return true
            end
        end
        return false
    end
    
    local function get_address(value)
        if is_address(value) then
            return tonumber(value:sub(2,-2))
        end
    end
    
    local function get_address_value(value)
        local address = get_address(value)
        local number = ram[address+1]
        return number
    end
    
    local function find_define()
        local is_data_section = false
        
        local ramp = 0
        local line = 1
        for i=1,#tree do
            if type(tree[i]) == "string" then
                if not is_data_section then
                    if tree[i] == "int" and (type(tree[i+1]) == "number" and tree[i+1] == 0) then
                        data_section = i
                        is_data_section = true
                    end
                else
                    if type(tree[i+1])=="string" and tree[i+1]=="db" then
                        local x = 1
                        if type(tree[i+2])=="number" then
                            x = tree[i+2]
                        else
                            print("ERROR: there's no value for define at line "..tostring(line))
                            break
                        end
                        local n = {tree[i], ramp}
                        table.insert(definetable, n)
                        ram[ramp+1] = x
                        
                        ramp = ramp + 1
                    end
                end
                if tree[i] == "\n" then
                    line = line + 1
                end
            end
        end
    end
    
    local function replace_define()
        local line = 1
        for i=1,#tree do
            if type(tree[i]) == "string" then
                if tree[i]:sub(1,1)=="<" and tree[i]:sub(-1,-1)==">" then
                    local name = tree[i]:sub(2,-2)
                    local unknown = true
                    for _,x in ipairs(definetable) do
                        if x[1] == name then
                            tree[i] = "["..x[2].."]"
                            unknown = false
                        end
                    end
                    if unknown then
                        print("ERROR: Unknown variable ".. name .." at line "..line)
                        os.exit()
                    end
                elseif tree[i] == "\n" then
                    line = line + 1
                end
            end
        end
    end
    
    local function is_define(value)
        for i,x in ipairs(definetable) do
            if x[1] == value then
                return true
            end
        end
        return false
    end
    
    local function get_define(value)
        for i,x in ipairs(definetable) do
            if x[1] == value then
                return x[2]
            end
        end
    end
    
    --<< MAIN >>--
    
    find_label()
    find_define()
    replace_define()
    
    local i = 1
    local line = 0
    while i <= #tree do
        if tree[i] == "add" then
            local x = 0
            if type(tree[i+2])=="number" then
                x = tree[i+2]
            elseif is_reg(tree[i+2]) then
                x = get_reg_value(tree[i+2])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for add at line "..tostring(line))
                break
            end
            
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    check_o_flag_add(reg.A, x)
                    
                    reg.A = reg.A + x
                    check_carry_flag(reg.A)
                    check_neg_flag(reg.A)
                    check_zero_flag(reg.A)
                elseif n==1 then
                    check_o_flag_add(reg.B, x)
                    
                    reg.B = reg.B + x
                    check_carry_flag(reg.B)
                    check_neg_flag(reg.B)
                    check_zero_flag(reg.B)
                elseif n==2 then
                    check_o_flag_add(reg.C, x)
                    
                    reg.C = reg.C + x
                    check_carry_flag(reg.C)
                    check_neg_flag(reg.C)
                    check_zero_flag(reg.C)
                elseif n==3 then
                    check_o_flag_add(reg.D, x)
                    
                    reg.D = reg.D + x
                    check_carry_flag(reg.D)
                    check_neg_flag(reg.D)
                    check_zero_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for add at line "..tostring(line))
                break
            end
            
            i = i + 2
        elseif tree[i] == "sub" then
            local x = 0
            if type(tree[i+2])=="number" then
                x = tree[i+2]
            elseif is_reg(tree[i+2]) then
                x = get_reg_value(tree[i+2])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for sub at line "..tostring(line))
                break
            end
            x = ((~x + 1) & 0xFF)
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    check_o_flag_sub(reg.A, x)
                    
                    reg.A = reg.A + x
                    check_carry_flag(reg.A)
                    flags.C = ~flags.C & 1
                    check_neg_flag(reg.A)
                    check_zero_flag(reg.A)
                elseif n==1 then
                    check_o_flag_sub(reg.B, x)
                    
                    reg.B = reg.B + x
                    check_carry_flag(reg.B)
                    flags.C = ~flags.C & 1
                    check_neg_flag(reg.B)
                    check_zero_flag(reg.B)
                elseif n==2 then
                    check_o_flag_sub(reg.C, x)
                    
                    reg.C = reg.C + x
                    check_carry_flag(reg.C)
                    flags.C = ~flags.C & 1
                    check_neg_flag(reg.C)
                    check_zero_flag(reg.C)
                elseif n==3 then
                    check_o_flag_sub(reg.D, x)
                    
                    reg.D = reg.D + x
                    check_carry_flag(reg.D)
                    flags.C = ~flags.C & 1
                    check_neg_flag(reg.D)
                    check_zero_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for sub at line "..tostring(line))
                break
            end
            i = i + 2
        elseif tree[i] == "mul" then
            local x = 0
            if type(tree[i+1])=="number" then
                x = tree[i+1]
            elseif is_reg(tree[i+1]) then
                x = get_reg_value(tree[i+1])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for mul at line "..tostring(line))
                break
            end
            
            local y = 0
            if type(tree[i+2])=="number" then
                y = tree[i+2]
            elseif is_reg(tree[i+2]) then
                y = get_reg_value(tree[i+2])
            else
                print("ERROR: there's no value for mul at line "..tostring(line))
                break
            end
            
            x = (x * y) & 0xFF
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    reg.A = x
                    check_neg_flag(reg.A)
                    check_zero_flag(reg.A)
                elseif n==1 then
                    reg.B = x
                    check_neg_flag(reg.B)
                    check_zero_flag(reg.B)
                elseif n==2 then
                    reg.C = x
                    check_neg_flag(reg.C)
                    check_zero_flag(reg.C)
                elseif n==3 then
                    reg.D = x
                    check_neg_flag(reg.D)
                    check_zero_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for mul at line "..tostring(line))
                break
            end
            
            i = i + 2
        elseif tree[i] == "muh" then
            local x = 0
            if type(tree[i+1])=="number" then
                x = tree[i+1]
            elseif is_reg(tree[i+1]) then
                x = get_reg_value(tree[i+1])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for muh at line "..tostring(line))
                break
            end
            
            local y = 0
            if type(tree[i+2])=="number" then
                y = tree[i+2]
            elseif is_reg(tree[i+2]) then
                y = get_reg_value(tree[i+2])
            else
                print("ERROR: there's no value for muh at line "..tostring(line))
                break
            end
            
            x = (x * y) >> 8
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    reg.A = x
                    check_neg_flag(reg.A)
                    check_zero_flag(reg.A)
                elseif n==1 then
                    reg.B = x
                    check_neg_flag(reg.B)
                    check_zero_flag(reg.B)
                elseif n==2 then
                    reg.C = x
                    check_neg_flag(reg.C)
                    check_zero_flag(reg.C)
                elseif n==3 then
                    reg.D = x
                    check_neg_flag(reg.D)
                    check_zero_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for muh at line "..tostring(line))
                break
            end
            
            i = i + 2
        elseif tree[i] == "div" then
            local x = 0
            if type(tree[i+1])=="number" then
                x = tree[i+1]
            elseif is_reg(tree[i+1]) then
                x = get_reg_value(tree[i+1])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for div at line "..tostring(line))
                break
            end
            
            local y = 0
            if type(tree[i+2])=="number" then
                y = tree[i+2]
            elseif is_reg(tree[i+2]) then
                y = get_reg_value(tree[i+2])
            else
                print("ERROR: there's no value for div at line "..tostring(line))
                break
            end
            if y == 0 then
                print("ERROR: cannot divide by 0 at line "..tostring(line))
                break
            end
            
            x = math.modf(x / y)
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    reg.A = x
                    check_neg_flag(reg.A)
                elseif n==1 then
                    reg.B = x
                    check_neg_flag(reg.B)
                elseif n==2 then
                    reg.C = x
                    check_neg_flag(reg.C)
                elseif n==3 then
                    reg.D = x
                    check_neg_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for div at line "..tostring(line))
                break
            end
            
            
            
            i = i + 2
        elseif tree[i] == "mod" then
            local x = 0
            if type(tree[i+1])=="number" then
                x = tree[i+1]
            elseif is_reg(tree[i+1]) then
                x = get_reg_value(tree[i+1])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for mod at line "..tostring(line))
                break
            end
            
            local y = 0
            if type(tree[i+2])=="number" then
                y = tree[i+2]
            elseif is_reg(tree[i+2]) then
                y = get_reg_value(tree[i+2])
            else
                print("ERROR: there's no value for mod at line "..tostring(line))
                break
            end
            if y == 0 then
                print("ERROR: cannot divide by 0 at line "..tostring(line))
                break
            end
            
            x = x % y
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    reg.A = x
                    check_neg_flag(reg.A)
                    check_zero_flag(reg.A)
                elseif n==1 then
                    reg.B = x
                    check_neg_flag(reg.B)
                    check_zero_flag(reg.B)
                elseif n==2 then
                    reg.C = x
                    check_neg_flag(reg.C)
                    check_zero_flag(reg.C)
                elseif n==3 then
                    reg.D = x
                    check_neg_flag(reg.D)
                    check_zero_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for mod at line "..tostring(line))
                break
            end
            
            i = i + 2
        elseif tree[i] == "mov" then
            local x = 0
            if type(tree[i+2])=="number" then
                x = tree[i+2]
            elseif is_reg(tree[i+2]) then
                x = get_reg_value(tree[i+2])
            elseif is_address(tree[i+2]) then
                x = get_address_value(tree[i+2])
            else
                print("ERROR: there's no value for mov at line "..tostring(line))
                break
            end
            
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    reg.A = x
                    check_neg_flag(reg.A)
                    check_zero_flag(reg.A)
                elseif n==1 then
                    reg.B = x
                    check_neg_flag(reg.B)
                    check_zero_flag(reg.B)
                elseif n==2 then
                    reg.C = x
                    check_neg_flag(reg.C)
                    check_zero_flag(reg.C)
                elseif n==3 then
                    reg.D = x
                    check_neg_flag(reg.D)
                    check_zero_flag(reg.D)
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for mov at line "..tostring(line))
                break
            end
            i = i + 2
        elseif tree[i] == "cmp" then
            local x = 0
            if type(tree[i+1])=="number" then
                x = tree[i+1]
            elseif is_reg(tree[i+1]) then
                x = get_reg_value(tree[i+1])
            else
                print("ERROR: there's no value for cmp at line "..tostring(line))
                break
            end
            local y = 0
            if type(tree[i+2])=="number" then
                y = tree[i+2]
            elseif is_reg(tree[i+2]) then
                y = get_reg_value(tree[i+2])
            else
                print("ERROR: there's no value for cmp at line "..tostring(line))
                break
            end
            
            y = ((~y + 1) & 0xFF)
            
            local z = x + y
            check_o_flag_sub(x, y)
            check_carry_flag(z)
            flags.C = ~flags.C & 1
            check_neg_flag(z)
            check_zero_flag(z)
            
            i = i + 1
        elseif tree[i] == "jmp" then
            local label = tree[i+1]
            for _,x in ipairs(jumptable) do
                if label == x[1] then
                    i = x[2]
                end
            end
        elseif tree[i] == "jeq" then
            if flags.Z == 1 then
                local label = tree[i+1]
                for _,x in ipairs(jumptable) do
                    if label == x[1] then
                        i = x[2]
                    end
                end
            end
        elseif tree[i] == "jne" then
            if flags.Z == 0 then
                local label = tree[i+1]
                for _,x in ipairs(jumptable) do
                    if label == x[1] then
                        i = x[2]
                    end
                end
            end
        elseif tree[i] == "jgr" then
            if flags.Z == 0 and flags.C == 0 then
                local label = tree[i+1]
                for _,x in ipairs(jumptable) do
                    if label == x[1] then
                        i = x[2]
                    end
                end
            end
        elseif tree[i] == "jls" then
            if flags.Z == 0 and flags.C == 1 then
                local label = tree[i+1]
                for _,x in ipairs(jumptable) do
                    if label == x[1] then
                        i = x[2]
                    end
                end
            end
        elseif tree[i] == "jgn" then
            if flags.Z == 0 and flags.N == flags.V then
                local label = tree[i+1]
                for _,x in ipairs(jumptable) do
                    if label == x[1] then
                        i = x[2]
                    end
                end
            end
        elseif tree[i] == "jln" then
            if flags.Z == 0 and flags.C ~= flags.V then
                local label = tree[i+1]
                for _,x in ipairs(jumptable) do
                    if label == x[1] then
                        i = x[2]
                    end
                end
            end
        elseif tree[i] == "psh" then
            local x = 0
            if type(tree[i+1])=="number" then
                x = tree[i+1]
            elseif is_reg(tree[i+1]) then
                x = get_reg_value(tree[i+1])
            elseif is_address(tree[i+1]) then
                x = get_address_value(tree[i+1])
            else
                print("ERROR: there's no value for mov at line "..tostring(line))
                break
            end
            
            if reg.S + 1 < #ram//1.58 then
                print("ERROR: stack overflow")
                break
            end
            ram[reg.S] = x

            reg.S = reg.S - 1
            
            i = i + 1
        elseif tree[i] == "pop" then
            local x = ram[reg.S + 1]
            if is_reg(tree[i+1]) then
                local n = get_reg(tree[i+1])
                if n==0 then
                    reg.A = x
                elseif n==1 then
                    reg.B = x
                elseif n==2 then
                    reg.C = x
                elseif n==3 then
                    reg.D = x
                end
            elseif is_address(tree[i+1]) then
                local n = get_address(tree[i+1])
                ram[n+1] = x
            else
                print("ERROR: there's no target for pop at line "..tostring(line))
                break
            end

            reg.S = reg.S + 1
            if reg.S > #ram - 1 then
                print("ERROR: Stack underflow")
                break
            end
            i = i + 1
        elseif tree[i] == "int" then
            local cmd = tree[i+1]
            if cmd == 0 then
                break
            elseif cmd == 1 then
                iot.output.char(reg.A)
            elseif cmd == 2 then
                reg.A = iot.input.char()
            end
        elseif tree[i] == "jsr" then
            if not tree[i+1] then
                print("ERROR: There's no label for jsr at col "..i)
                break
            end
            
            local label = tree[i+1]
            local addr = 0
            for _,x in ipairs(jumptable) do
                if label == x[1] then
                    addr = x[2]
                end
            end
            
            --<< push >>--
            local x = 0
            
            if reg.S + 1 < #ram//1.58 then
                print("ERROR: stack overflow")
                break
            end
            ram[reg.S] = i

            reg.S = reg.S - 1
            
            i = addr
        elseif tree[i] == "ret" then
            --<< pop >>--
            i = ram[reg.S + 1]
            reg.S = reg.S + 1
            if reg.S > #ram - 1 then
                print("ERROR: Stack underflow")
                break
            end
        elseif tree[i] == "\n" then
            line = line + 1
        end
        valid_reg_value()
        i = i + 1
    end
end

example = [[
mov A, "H"
int 1h
mov A, "e"
int 1h
mov A, "l"
int 1h
mov A, "l"
int 1h
mov A, "o"
int 1h
mov A, ","
int 1h
mov A, " "
int 1h
mov A, "w"
int 1h
mov A, "o"
int 1h
mov A, "r"
int 1h
mov A, "l"
int 1h
mov A, "d"
int 1h
mov A, "!"
int 1h
mov A, 10
int 1h
mov A, "t"
int 1h
mov A, "r"
int 1h
mov A, "y"
int 1h
mov A, " "
int 1h
mov A, "'"
int 1h
mov A, "-"
int 1h
int 1h
mov A, "d"
int 1h
mov A, "e"
int 1h
mov A, "b"
int 1h
mov A, "u"
int 1h
mov A, "g"
int 1h
mov A, "'"
int 1h
mov A, " "
int 1h
mov A, "t"
int 1h
mov A, "o"
int 1h
mov A, " "
int 1h
mov A, "d"
int 1h
mov A, "e"
int 1h
mov A, "b"
int 1h
mov A, "u"
int 1h
mov A, "g"
int 1h
mov A, " "
int 1h
mov A, "t"
int 1h
mov A, "h"
int 1h
mov A, "i"
int 1h
mov A, "s"
int 1h
mov A, "\n"
int 1h
int 0h
]]

code = example

for i=1,#arg do
    if arg[i] == "--debug" then
        debug = true
    elseif arg[i]:sub(-5,-1) == ".iasm" or arg[i]:sub(-4,-1) == ".asm" then
        file = io.open(arg[i], r)
        code = file:read("*all")
        file:close()
        code = code.."\n"
    end
end

parse = lpeg.match(Ct(grammar), code)
parser(parse)
if debug then
    print("\n--<< DEBUGGER >>--")
    print(inspect(parse))
    print()
    do
        local n = math.log(#ram, 2)
        local mramy = 2^(n/2)
        local mramx = 2^(n/2)
        
        for y = 1,mramy do
            io.write(string.format("%X", (y-1)*mramx))
            for i=1,3 - string.len(string.format("%X", (y-1)*mramx)) do io.write(" ") end
            io.write("| ")
            for x = 1,mramx do
                local z = (y - 1) * mramx + x
                for i=1,3 - string.len(tostring(ram[z])) do io.write(" ") end
--                if reg.S + 1 == z then
--                    io.write(">")
--                end
                io.write(ram[z]..", ")
            end
            print("|")
        end
    end


    io.write("A:"..reg.A)
    for i=1,4 - string.len(tostring(reg.A)) do io.write(" ") end
    io.write("B:"..reg.B)
    for i=1,4 - string.len(tostring(reg.B)) do io.write(" ") end
    io.write("C:"..reg.C)
    for i=1,4 - string.len(tostring(reg.C)) do io.write(" ") end
    io.write("D:"..reg.D)
    for i=1,4 - string.len(tostring(reg.D)) do io.write(" ") end
    io.write("S:"..reg.S)
    for i=1,4 - string.len(tostring(reg.S)) do io.write(" ") end
    print()
    io.write("Z:"..flags.Z)
    for i=1,4 - string.len(tostring(flags.Z)) do io.write(" ") end
    io.write("C:"..flags.C)
    for i=1,4 - string.len(tostring(flags.C)) do io.write(" ") end
    io.write("N:"..flags.N)
    for i=1,4 - string.len(tostring(flags.N)) do io.write(" ") end
    io.write("V:"..flags.V)
    for i=1,4 - string.len(tostring(flags.V)) do io.write(" ") end
    print()
end