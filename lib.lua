--ffi
local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        char pad[44];
        int chokedPackets;
    } NetworkChannel_t;

    struct CIncomingPacket {
        void* vtable;
        bool m_bReliable;
        int32_t m_nLength;
        uint8_t m_data[14];
        uint32_t m_nDataBytes;
        uint32_t m_nChoked;
    };

    void __cdecl Msg(const char* fmt, ...);
]]

--ffi helper
local ffi_helper = {
	kernel32 = ffi.load("kernel32"),
	user32 = ffi.load("user32"),
	tier0 = ffi.load("tier0.dll")
}

--callbacks
local opt_callback = {
	add = function(v, func)
		if v == "render" then
			return client.add_callback("on_paint", func)
		end

		if v == "createmove" then
			return client.add_callback("create_move", func)
		end

		if v == "aim" then
			return client.add_callback("on_shot", func)
		end

		return client.add_callback(v, func)
	end,

	event = function(v, func)
		return events.register_event(v, func)
	end
}

--animation
local animate = {
	lerp = function(a, b, t) return a + (b - a) * t end,
	clamp = function(value, min, max) return math.min(max, math.max(min, value)) end
}

local Color = function(r, g, b, a)
    return {r = r or 255, g = g or 255, b = b or 255, a = a or 255}
end

local color_ = {
	RGBtoHEX = function(clr)
    local rgb = {clr.r, clr.g, clr.b, clr.a}
    local hexadecimal = '#'

    for key, value in pairs(rgb) do
        local hex = ''

        while (value > 0) do
            local index = math.fmod(value, 16) + 1
            value = math.floor(value / 16)
            hex = string.sub('0123456789ABCDEF', index, index) .. hex
        end

        if (string.len(hex) == 0) then
            hex = '00'

        elseif (string.len(hex) == 1) then
            hex = '0' .. hex
        end

        hexadecimal = hexadecimal .. hex
    end

    return hexadecimal
end,

HEXtoRGB = function(hexs)
    if string.find(hexs, "#") then
        hex = hexs:gsub("#", "")
        return Color(tonumber("0x" .. hex:sub(1, 2)),
                     tonumber("0x" .. hex:sub(3, 4)),
                     tonumber("0x" .. hex:sub(5, 6)),
                     tonumber("0x" .. hex:sub(7, 8)))
    else
        error("Hex Not Found")
    end
end
}

local surface = {
	measure_text = function(font, text)
		return render.get_text_width(font, text)
	end,

	text = function(font, text, x, y, color)
		return render.draw_text(font, x, y, color, text)
	end,

	rect = function(x, y, x2, y2, r, g, b, a)
		return render.draw_rect_filled(x, y, x2, y2, color.new(r, g, b, a))
	end,

	w2s = function(vector)
		return render.world_to_screen(vector)
	end,

    print_c = function(...) local args = {...} local str = table.concat(args, " ") ffi_helper.tier0.Msg(str .. "\n") end
}

multicolor = function(data, x, y)
	local total_width = 0
	local width = 0

	for _, v in pairs(data) do
		local text_width = render.get_text_width(verdana12, v[1])
		total_width = total_width + text_width
	end
	for _, v in ipairs(data) do
		local text_width = render.get_text_width(verdana12, v[1])
		local x2 = (x - total_width / 2 + width)
		surface.text(verdana12, v[1], x2, y, v[2])
		width = width + text_width
	end
end

local player = {
	state = function()
		local localplayer = entitylist.get_local_player()
		local duck_amount = localplayer:get_prop_float("CBasePlayer", "m_flDuckAmount")
		local in_air = bit.band(localplayer:get_prop_int("CBasePlayer", "m_fFlags"), 1) == 0
		local in_duck = localplayer:get_prop_int("CBasePlayer", "m_fFlags") == 263
		local velocity = math.floor(localplayer:get_velocity():length_2d())
		if localplayer:get_health() > 0 then
			if not in_duck and velocity <= 1 then
				return "stand"
			end

			if not in_air and localplayer:get_prop_float("CBasePlayer", "m_flDuckAmount") > 0 then
				return "crouch"
			end

			if menu.get_key_bind_state("misc.slow_walk_key") then
				return "walk"
			end

			if menu.get_key_bind_state("anti_aim.fake_duck_key") then
				return "fakeduck"
			end

			if velocity > 0 and duck_amount <= 0 and not in_air then
				return "run"
			end

			if in_air and not bit.band(localplayer:get_prop_float("CBasePlayer", "m_fFlags"), bit.lshift(1,0)) ~= 0 and duck_amount == 0 then
				return "air"
			end

			if in_air and localplayer:get_prop_float("CBasePlayer", "m_flDuckAmount") > 0 then
				return "air-c"
			end
		else
			return "dead"
		end
	end,

	fakelag = function()
		local is_valid_ptr = function(ptr)
			local pointer = ffi.cast("void*", ptr)
			return pointer ~= nullptr and pointer
		end
		
		local ffi_interface = function(module, name)
		    local ptr = utils.create_interface(module .. ".dll", name)
		    return ffi.cast("void***", ptr)
	    end
	    local VClientEntityList = ffi_interface("client", "VClientEntityList003")
	    local VEngineClient = ffi_interface("engine", "VEngineClient014")
	    local GetNetworkChannel_Native = ffi.cast("NetworkChannel_t*(*)(void*)", VEngineClient[0][78])

	    local GetNetworkChannel = function()
	    	local netchan = GetNetworkChannel_Native(VEngineClient)
	    	if not is_valid_ptr(netchan) then
	    		return false
	    	end
	    	return netchan[0]
	    end

	    return GetNetworkChannel().chokedPackets
	end
}

--request
local response = http.get("https://backend.hysteria.one", "/shared/weather")
local cityStart, cityEnd = string.find(response, '"city":"(.-)"')
local city = string.sub(response, cityStart + 8, cityEnd - 1)
local msgStart, msgEnd = string.find(response, '"msg":"(.-)"')
local msg = string.sub(response, msgStart + 7, msgEnd - 1)
local start_pos, end_pos = string.find(response, '"temp_c":')
local temp_start_pos = end_pos + 1
local temp_end_pos = string.find(response, ',', temp_start_pos) - 1
local temp_c = tonumber(string.sub(response, temp_start_pos, temp_end_pos - 2))
