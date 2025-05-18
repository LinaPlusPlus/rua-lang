local lexor = require "rua-lang.lexor";

for kind,data,line,col in lexor(io.stdin) do
    if kind == "!" then
        print(("\r\t\tFAIL: %q "):format(data));
        return
    end
    print(("[%s,%s]\r\t\t'%s': %q "):format(line,col,kind,data));
end