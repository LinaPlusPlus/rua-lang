local parser = require "rua-lang.parser";
local dump  = require "rua-cli.kooldump";
local lexor = require "rua-lang.lexor";

local mainfilePath = ...;
local mainFile = assert(io.open(mainfilePath,"r"));

local ok,err = parser(mainfilePath,lexor(mainFile));
if ok then
    print(dump(ok));
else
    print(err);
end
