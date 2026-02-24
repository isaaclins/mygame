local Verbose = {}

local enabled = false

local function toString(v)
	if type(v) == "table" then
		local out = {}
		local n = 0
		for k, val in pairs(v) do
			n = n + 1
			if n > 24 then
				out[#out + 1] = "..."
				break
			end
			out[#out + 1] = tostring(k) .. "=" .. tostring(val)
		end
		table.sort(out)
		return "{" .. table.concat(out, ", ") .. "}"
	end
	return tostring(v)
end

function Verbose.init(args)
	for _, a in ipairs(args or {}) do
		if a == "--verbose" or a == "-v" then
			enabled = true
			break
		end
	end
	if enabled then
		print("[verbose] enabled")
	end
end

function Verbose.setEnabled(value)
	enabled = value and true or false
end

function Verbose.isEnabled()
	return enabled
end

function Verbose.log(tag, msg)
	if not enabled then
		return
	end
	print("[verbose][" .. tostring(tag) .. "] " .. tostring(msg))
end

function Verbose.logf(tag, fmt, ...)
	if not enabled then
		return
	end
	print("[verbose][" .. tostring(tag) .. "] " .. string.format(fmt, ...))
end

function Verbose.dump(tag, label, value)
	if not enabled then
		return
	end
	print("[verbose][" .. tostring(tag) .. "] " .. tostring(label) .. ": " .. toString(value))
end

return Verbose
