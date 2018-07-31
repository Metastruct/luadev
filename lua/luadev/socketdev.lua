-- luacheck: globals luadev socket easylua chatbox

local function requireExists(moduleName)
	local osSuffix = assert(
		(system.IsWindows() and "win32")
		or (system.IsLinux() and "linux")
		or (system.IsOSX() and "osx"),
		"couldn't determine system type?"
	)
	local dllFiles = file.Find(string.format("lua/bin/gmcl_%s_%s.dll", moduleName, osSuffix), "GAME")
	local luaFileExists = file.Exists(string.format("includes/modules/%s.lua", moduleName), "LCL")

	return #dllFiles > 0 or luaFileExists
end

local function luadevPrint(...)
	Msg"[LuaDev] "
	print(...)
end

local moduleLoaded = false
for _, moduleName in ipairs({ "socket", "luasocket" }) do
	if requireExists(moduleName) then
		local ok, err = pcall(require, moduleName)
		if not ok then
			luadevPrint(
				string.format("Unable to load module %s: %s", moduleName, err)
			)
		else
			if not socket then
				luadevPrint(string.format("_G.socket not found, but module %s loaded?", moduleName))
			else
				moduleLoaded = true
				break
			end
		end
	end
end

if not moduleLoaded then
	luadevPrint("No socket module found")
	return
end


local methods = {
	self = function(sock)
		local who = sock:receive("*l")
		luadev.RunOnSelf(sock:receive("*a"), who)
		system.FlashWindow()
	end,
	sv = function(sock)
		local who = sock:receive("*l")
		luadev.RunOnServer(sock:receive("*a"), who)
		system.FlashWindow()
	end,
	sh = function(sock)
		local who = sock:receive("*l")
		luadev.RunOnShared(sock:receive("*a"), who)
		system.FlashWindow()
	end,
	cl = function(sock)
		local who = sock:receive("*l")
		luadev.RunOnClients(sock:receive("*a"), who)
		system.FlashWindow()
	end,
	ent = function(sock)
		local who = sock:receive("*l")
		local contents = string.format("ENT = {}; local ENT=ENT; %s; scripted_ents.Register(ENT, '%s')", sock:receive("*a"), who:sub(0, -5))
		luadev.RunOnShared(contents, who)
		system.FlashWindow()
	end,
	wep = function(sock)
		local who = sock:receive("*l")
		local contents = string.format("SWEP = {}; local SWEP=SWEP; %s; weapons.Register(SWEP, '%s')", sock:receive("*a"), who:sub(0, -5))
		luadev.RunOnShared(contents, who)
		system.FlashWindow()
	end,
	client = function(sock)
		local who = sock:receive("*l")
		local to = sock:receive("*l")
		to = easylua and easylua.FindEntity(to) or player.GetByID(tonumber(to))
		to = { to }
		luadev.RunOnClient(sock:receive("*a"), to, who)
		system.FlashWindow()
	end,
	chatTextChanged = function(sock)
		local contents = sock:receive("*a")
		if not contents then return end

		if chatbox then
			chatbox.StartChat_override = true
		end
		hook.Run("StartChat")
		if chatbox then
			chatbox.StartChat_override = false
		end

		hook.Run("ChatTextChanged", contents, true)
	end,
	finishChat = function(sock)
		hook.Run("FinishChat")
	end,
	requestPlayers = function(sock)
		local plys = {}
		for _, ply in next, player.GetAll() do
			table.insert(plys, ply:Nick())
		end

		sock:send(table.concat(plys, "\n"))
	end
}

local sock = assert(socket.tcp())
assert(sock:bind("127.0.0.1", 27099))
sock:settimeout(0)
sock:setoption("reuseaddr", true)
assert(sock:listen(0))

hook.Add("Think", "LuaDev-Socket", function()
	local cl = sock:accept()
	if not cl then return end

	if cl:getpeername() ~= "127.0.0.1" then
		luadevPrint("Refused", cl:getpeername())
		cl:shutdown()
		return
	end

	cl:settimeout(0)

	local protocol = cl:receive("*l")
	local method

	if protocol == "extension" then
		method = cl:receive("*l")
	else
		method = protocol
	end

	if method and methods[method] then
		methods[method](cl)
	end

	cl:shutdown()
end)
