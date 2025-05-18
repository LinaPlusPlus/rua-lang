local arbitrary_passthru = "()[]*&;:,.<>={}";
local word_chars = {
    -- allow these chars inside words
    ["_"]=true,
}
local ignore_chars = {
    --ingore these unless contextual like inside a string
    ["\n"] = true,
    [" "] = true,
    ["\r"] = true,
    ["\t"] = true,
}

local arbitrary_passthru_map = {} -- these symbols are passed to the output literally


local function lexInvoke(in_stream,allow_unknown_chars)
    local lex_body,lex_string,lex_word,lex_num;
    local emit = coroutine.yield;
    local lineNo,colNo = 1,1;
    local failed = false

    local char = in_stream:read(1);
    local function pull()
        char = in_stream:read(1);
        if char == "\n" then
            lineNo = lineNo +1
            colNo = 1
        else
            colNo = colNo +1;
        end
    end

    function lex_string(end_char,type_char,esc_char,fail_incomplete)
        if not esc_char then esc_char = "\\" end
        local escape_mode = false;
        local bld = {};
        while true do --TODO add \n\t\r etc...
            if not char then break end
            if escape_mode then
                table.insert(bld,char);
                pull();
                escape_mode = false;
            else
                if char == end_char then break end
                if char == esc_char then
                    escape_mode = true;
                    pull();
                else
                    table.insert(bld,char);
                    pull();
                end
            end
        end
        if not char then
            emit("!",fail_incomplete or "incomplete_string",lineNo,colNo);
            failed = true;
        end
        local data = table.concat(bld);
        emit(type_char or "\"",data,lineNo,colNo);
    end

    function lex_word(type_char)
        local bld = {};
        while true do
            local byte = char and char:byte() or 0;
            local isLetter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122);
            if isLetter or word_chars[char] then -- is a letter
                table.insert(bld,char);
                pull();
            else
                emit(type_char or "_",table.concat(bld),lineNo,colNo);
                return;
            end
        end
        if not char then
            emit("!",fail_incomplete or "incomplete_string",lineNo,colNo);
            failed = true;
        end
        local data = table.concat(bld);
        emit(type_char or "\"",data,lineNo,colNo);
    end

    function lex_comment(eof_char)
        while true do
            if char == eof_char or not char then
                return
            else
                pull();
            end
        end
    end

    function lex_body() -- do not forget This is the LEXOR! NOT the parser
        while true do
            local byte = char and char:byte() or 0;
            local isLetter = (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122);
            if not char then
                -- reached EOF
                return;
            elseif isLetter then
                lex_word();
            elseif ignore_chars[char] then
                --noop
                pull()
            elseif char == "\"" then
                pull();
                lex_string("\"");
                pull();
            elseif char == "'" then
                pull();
                lex_string("'");
                pull();
            --elseif char == "." then -- DEPRECATED
              --  pull();
                --lex_word(".");

            elseif char == "/" then
                pull();
                if char == "/" then
                    --is comment
                    pull();
                    lex_comment("\n");
                else
                    --oops! not comment, emit normally
                    emit("-","",lineNo,colNo);
                end
            elseif arbitrary_passthru_map[char] then
                emit(char,"",lineNo,colNo);
                pull();
            else
                emit("?",char,lineNo,colNo);
                pull();
            end
            if failed then
                return;
            end
        end
    end

    local co = coroutine.create(function()
        lex_body();
        --emit("!","OVER");
        emit(nil);
    end)

    local function iterator ()
        local ok,type,data,line,col = assert(coroutine.resume(co));
        return type,data,line,col;
    end
    return iterator
end

if true then
    for i = 1, #arbitrary_passthru do
        arbitrary_passthru_map[arbitrary_passthru:sub(i, i)] = true;
    end
    arbitrary_passthru = nil;
end

-- iterator signature: ok, type, detail, line, col
return lexInvoke;
