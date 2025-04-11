--!strict
local function Proxy(original: any): (any, any)
	local proxy = {}
	local metatable = {}

	function metatable:__index(key)
		return proxy[key] or original[key]
	end

	function metatable:__newindex(key, value)
		local target = if proxy[key] then proxy else original

		target[key] = value
	end

	return proxy, setmetatable({}, metatable)
end



return Proxy
