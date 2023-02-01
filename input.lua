--[[
    <meta name="author" content="giperfast">
    <meta name="links" content="https://github.com/giperfast">
    shit code prod.
]]--
local ffi = require 'ffi'
ffi.cdef[[
    typedef struct tagPOINT {
        unsigned long x;
        unsigned long y;
    } POINT, *PPOINT;
    typedef bool (__thiscall *IsButtonDown_t)(void*, int);
    bool GetCursorPos(PPOINT);
]]
local inputsystem = ffi.cast(ffi.typeof('void***'), utils.create_interface('inputsystem.dll', 'InputSystemVersion001'));
local IsButtonDown = ffi.cast('IsButtonDown_t', inputsystem[0][15]);
local _vars = {
    buttonToggled   = false,
}
local vars = {
    buttonPressed   = false,
    buttonToggled   = false,
    buttonReleased  = false,
    buttonDown      = false,
}
local _inputHandler = {
    ButtonIsToggled = function(code)
        if IsButtonDown(inputsystem, code) and not _vars.buttonToggled then
            _vars.buttonToggled = true;
            return true;
        elseif not IsButtonDown(inputsystem, code) and _vars.buttonToggled then
            _vars.buttonToggled = false;
            return false;
        end;
    end,
}
input =  {
    IsButtonPressed = function(code)
        if IsButtonDown(inputsystem, code) then
            return true;
        else
            return false;
        end;
    end,
    IsButtonToggled = function(code)
        if _inputHandler.ButtonIsToggled(code) then
            if vars.buttonToggled then
                vars.buttonToggled = false;
            else
                vars.buttonToggled = true;
            end;
        end;
        return vars.buttonToggled;
    end,
    IsButtonDown = function(code)
        if IsButtonDown(inputsystem, code) and not vars.buttonDown then
            vars.buttonDown = true;
            return true;
        elseif not IsButtonDown(inputsystem, code) then
            vars.buttonDown = false;
        end;
        return false;
    end,
    IsButtonReleased = function(code)
        if IsButtonDown(inputsystem, code) then
            vars.buttonReleased = true;
        elseif not IsButtonDown(inputsystem, code) and vars.buttonReleased then
            vars.buttonReleased = false;
            return true;
        end;
        return false;
    end,
    GetCursorPos = function()
        POINT = ffi.new('POINT');
        ffi.C.GetCursorPos(POINT);
        return POINT.x, POINT.y;
    end,
}
return input;