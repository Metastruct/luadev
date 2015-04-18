if not luadev then
	print"nah"
	return
end

hook.Remove("Think", "LuaDev-Socket") -- upvalues will be lost

collectgarbage()
collectgarbage() -- finalizers will be scheduled for execution in the first pass, but will only execute in the second pass

local ok, why = pcall(require, "luasocket")

if not ok then
	print(("\n\n\n\nUnable to load luasocket module (%s), LuaDev socket API will be unavailable\n\n\n\n"):format(tostring(why)))
	return
end

local sock = socket.tcp()
assert(sock:bind("127.0.0.1", 27099))
sock:settimeout(0)
assert(sock:listen(0))
	
local methods = {
	self = luadev.RunOnSelf,
	sv = luadev.RunOnServer,
	sh = luadev.RunOnShared,
	cl = luadev.RunOnClients,
	ent = function(contents, who)
		contents = "ENT = {}; local ENT=ENT; " .. contents .. "; scripted_ents.Register(ENT, '" .. who:sub(0, -5) .. "')"
		luadev.RunOnShared(contents, who)
	end
}

hook.Add("Think", "LuaDev-Socket", function()
	local cl, a, b, c = sock:accept()
	if cl then
		system.FlashWindow()

		if cl:getpeername() ~= "127.0.0.1" then
			print("Refused", cl:getpeername())
			cl:shutdown()
			return
		end

		cl:settimeout(0)

		local method = cl:receive("*l")
		local who = cl:receive("*l")
		local contents = cl:receive("*a")

		if method and methods[method] then
			methods[method](contents, who)
		end
		cl:shutdown()
	end
end)