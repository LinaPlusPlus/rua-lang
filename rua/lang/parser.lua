--BEGIN HEADER

local lexor_to_name = {
    ["_"] = "word",
    ["\""] = "string",
    ["}"] = "'}'",
    ["{"] = "'{'"
}

local function isCapitalized(str)
    local firstASCII = str:match("%a");
    if not firstASCII then return false end
    return firstASCII:match("%u") ~= nil
end


local function lexor_to_string(tok_type,tok_data)
    local out;
    if not tok_type then
        return "*EndOfFile*";
    end
    if tok_type == "_" then
        out = ("<word %q>"):format(tok_data)
    else
        out = lexor_to_name[tok_type] or ("<unknown token %q with %q>"):format(tostring(tok_type),tostring(tok_data));
    end
    return out
end

local function lexor_type_to_string(tok_type)
    local out;
    out = lexor_to_name[tok_type] or ("<unknown token %q>"):format(tok_type);
    return out;
end

--END HEADER

local function parse(fileName,iterFn,tok_type)

    --BEGIN HEADER

    local fail;
    local tok_data,tok_line,tok_col;
    local motive;
    local nxtok_type,nxtok_data,nxtok_line,nxtok_col;

    local function warn(class,header,msg,...)
        --TODO make this more complex
        header = header or "Warning: "
        local fmtstr = ("\27[1;33m%s: \27[0m%s\n\27[90m%s @%s,%s\27[0m\n"):format(header,msg,fileName or "*anonimous*",tok_line or "?",tok_col or "?");
        print(fmtstr:format(...));
    end

    local function pull()
        tok_type,tok_data,tok_line,tok_col =
        nxtok_type,nxtok_data,nxtok_line,nxtok_col;

        nxtok_type,nxtok_data,nxtok_line,nxtok_col = iterFn(tok_type);

        if tok_type == "!" then
            fail = tok_data;
        end

        print(tok_type,tok_data,tok_line,tok_col);
    end
    pull();
    pull();

    local unit_statement,unit_enum,unit_type;

    local function setup_statement(statement,type)
        statement.type = statement.type or type;
    end

    --END HEADER

    --BEGIN parts
    function part_static_accessor(path)
        path = path or {};

        if tok_type ~= "_" then
            --TODO better errors
            fail = ("Expected word, got `%s`"):format(lexor_to_string(tok_type,tok_data));
            return
        end
        table.insert(path,tok_data);
        pull();

        while tok_type == "." do
            pull();
            if tok_type ~= "_" then
                fail = ("Expected word afrter '.', got `%s`"):format(lexor_to_string(tok_type,tok_data));
                return
            end
            table.insert(path,tok_data);
            pull()
        end


        return path
    end

    function part_typedef(statement)
        statement.type = statement.type or "type"
        statement.static = true;
        local path = statement.path or {};
        statement.path = path;

        statement.lhs = part_static_accessor({});

        local args = {};
        statement.rhs = args;
        local comma;
        if tok_type == "<" then
           pull();
           while true do
                if comma == false and tok_type == "," then
                    pull();
                    comma = true;
                elseif not comma and tok_type == ">" then
                    pull()
                    break;
                else
                    table.insert(args,part_typedef({}));
                end
           end
        end

        return statement;
    end


    function part_struct(statement)

        setup_statement(statement,"structDef");

        local body = statement.body or {};
        statement.body = body;

        if tok_type ~= "{" then
            fail = ("Expected `%s { ... }` got `enum <word:name> %s `"):format(statement.type,lexor_to_string(tok_type,tok_data));
        end
        statement.line,statement.col = tok_line,tok_col;
        pull()

        local item = {};
        while true do
            if tok_type == "#" then
                pull();
                --TODO parse hash qualifiers
            elseif tok_type == "_" or tok_type == "\"" then
                item.name = tok_data;
                pull()
                if tok_type ~= ":" then
                    fail = ("In %s Expected `%s: <typeDefinition>` got `%s %s`"):format(statement.type,itemName,itemName,lexor_to_string(tok_type,tok_data));
                end
                pull();
                item.def = part_typedef({});

            elseif tok_type == "}" then
                pull();
                break;
            else
                fail = ("In %s, expected list of `<name>: <type>` ended by '}' got %s"):format(statement.type,lexor_to_string(tok_type,tok_data));
            end
            if fail then return end
        end
        return statement;
    end

    --END parts

    --BEGIN statements
    function statement_loop(statement,takeLast)
        setup_statement(statement,"loop")

        local oldMotive = motive;
        motive = "loop"
        local function takeLast(peek)
            if peek then
                return nil;
            end
            fail = ("Loop statement cannot be taken"):format()
        end

        local returned = statement_any({},takeLast);
        motive = oldMotive;

        statement.body = returned;
        return statement;
    end

    function statement_many(statement,takeLast)

        setup_statement(statement,"many")

        statement.body = {};
        local body = statement.body;

        local function giveLast(peek)
            local a = body[#body];
            if not peek then
                body[#body] = nil;
            end
            return a;
        end

        while true do
            if tok_type == "}" then
                pull();
                break;
            else
                local got = statement_any({},giveLast);
                table.insert(body,got);
            end
            if fail then return end
        end

        return statement;
    end

    function statement_call(statement,takeLast)
        local ender = statement.ender or ")";
        setup_statement(statement,"call")

        local body = statement.body or {};
        statement.body = body;

        local function giveLast(peek)
            local a = body[#body];
            if not peek then
                body[#body] = nil;
            end
            return a;
        end

        while true do
            if tok_type == ender then
                pull();
                break;
            else
                local got = statement_any({},giveLast);
                table.insert(body,got);
            end
            if fail then return end
        end

        return statement;
    end

    function statement_linkerRaw(statement,takeLast)

        setup_statement(statement,"linker_raw")

        local body = {};

        if tok_type ~= "{" then
            fail = ("Expected `linkerRaw { ... }` got `linkerRaw %s ...`"):format(lexor_to_string(tok_type,tok_data));
        end

         while true do
            local print = false;

            if tok_type == "}" then
                pull();
                break;
            elseif tok_type == "{" then

            end
            if print then
                table.insert(body,tok_type);
                table.insert(body,tok_data);
            end
            if fail then return end
        end

        statement.body = body;
        return statement;
    end

    function statement_any(statement,takeLast)
        if tok_type == "_" then
            if tok_data == "linkerRaw" then
                pull();
                statement_linkerRaw({type="linker_raw"})
            else
                local l = {
                    type="word",
                    id=tok_data,
                }
                pull();
                return l
            end
        elseif tok_type == "\"" then
            local l = {
                type="string",
                id=tok_data,
            }
            pull();
            return l
        elseif tok_type == "." then
            local p = takeLast(false);
            pull();
            if tok_type == "_" then
                local l = {
                    type="sub",
                    id=tok_data,
                    body=p,
                }
                pull();
                return l
            else
                fail = ("Expected word after '.', got `%s`"):format(lexor_to_string(tok_type,tok_data));
                pull()
                return
            end
        elseif tok_type == "{" then
            pull();
            local state = {type="brackets"};
            return statement_many(state);
        elseif tok_type == "(" then
            pull();
            local last = takeLast(true);
            if last then takeLast() end

            local state = {type="call",ender=")",lhs=last};
            return statement_call(state);
        else
            fail = ("In statement, Unexpected %s"):format(lexor_to_string(tok_type,tok_data));
            return {type="fail"}
        end
    end

    --END statements

    --BEGIN units

    function unit_struct(statement,takeLast)
        setup_statement(statement,"struct");

        if not statement.id then
            statement.id = part_static_accessor({});
        end
        pull();

        local function takeLast(peek)
            return nil;
        end
        statement = part_struct(statement,takeLast);
        return statement;
    end

    function unit_function(statement,parent)
        statement.lhs = part_static_accessor({});

        if tok_type ~= "(" then
            fail = ("In 'type' statement, Expected 'function <name>(...)' got 'function <name> %s'"):format(lexor_to_string(tok_type,tok_data));
        end
        pull();

        statement.argLabels = {};
        statement.argTypes = {};

        local comma;
        while true do
            if tok_type == "," then
                comma = true;
                pull();
            elseif not comma and tok_type == ")" then
                pull()
                break;
            elseif comma ~= false and tok_type == "_" then
                comma = false;
                table.insert(statement.argLabels,tok_data)
                pull();
                if tok_type == ":" then
                    pull();
                    local type = part_typedef({});
                    table.insert(statement.argTypes,type);
                else
                    -- type not specified
                    table.insert(statement.argTypes,false);
                end
            else
                fail = ("In 'function' statement, Unexpectedly got `%s`"):format(lexor_to_string(tok_type,tok_data));
                return
            end
        end

        local function giveLast(peek)
            local l = statement.body;
            if not peek then
                statement.body = nil;
            end
            return l;
        end

        statement.body = statement_any({},giveLast);

        table.insert(parent.body,statement)

    end

    function unit_type_alias(statement,parent)

        statement.line,statement.col = tok_line,tok_col;

        statement.lhs = part_static_accessor({});
        table.insert(parent.body,statement)


        if tok_type ~= "=" then
            fail = ("In 'type' statement, Expected '<path:alias> = <type>' got `%s`"):format(lexor_to_string(tok_type,tok_data));
        end
        pull();

        statement.rhs = part_typedef({});

        return statement;
    end

    function unit_statements(statement,parent)
        statement.type = statement.type or "statements"
        while tok_type and tok_type ~= "!" do
            print(tok_type,tok_data,tok_line,tok_col);
            pull()
        end
    end

    function unit_enum(statement,parent)
        local variants = statement.variants or {};
        statement.variants = variants;

        statement.lhs = part_static_accessor({});

        table.insert(parent.body,statement)


        if tok_type ~= "{" then
            fail = ("Expected `enum <word:name> { ... }` got `enum <word:name> %s `"):format(lexor_to_string(tok_type,tok_data));
        end
        statement.line,statement.col = tok_line,tok_col;
        pull()

        while true do
            if tok_type == "_" then
                pull()
                print("TODO: enum row",tok_data);
            elseif tok_type == "}" then
                pull();
                break;
            else
                fail = ("In enum, expected `<word:enumVariantName> ...` or '}' got %s"):format(lexor_to_string(tok_type,tok_data));
            end
            if fail then return end
        end
        return statement;
    end



    function unit_toplevel(statement)
        while tok_type and not fail do --BEGIN while
            print(tok_type,tok_data,tok_line,tok_col);
            if tok_type == "_" then
                if tok_data == "struct" then
                    unit_struct({type="struct"});
                elseif tok_data == "enum" then
                    pull();
                    unit_enum({type="enum",variants={}},statement);
                elseif tok_data == "function" then
                    pull()
                    unit_function({type="function"},statement);
                elseif tok_data == "type" then
                    pull();
                    unit_type_alias({type="type-alias"},statement);
                else
                    fail = ("unexpected word %q"):format(tok_data);
                end
            elseif false then
                --
            else
                fail = ("unexpected symbol in top level: %s"):format(lexor_to_string(tok_type,tok_data));
            end
        end --END wile
        --do not put code here, inconsistant execution
    end

    --END units

    local contain = {type="tld",label=fileName,body={}};
    unit_toplevel(contain,contain);
    if fail then
        return false,("\27[1;31mFailure:\27[0m %s\n\27[90mAt: %s @%s,%s\27[0m\n"):format(fail,fileName or "*anonimous*",tok_line or "?",tok_col or "?");
    end
    return contain
end

return parse
