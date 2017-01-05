if not luadev then
	print"You fool"
	return
end

local ok, why
if #file.Find("lua/bin/gmcl_luasocket*.dll", "GAME") > 0 or file.Exists("includes/modules/luasocket.lua", "LCL") then
	ok, why = pcall(require, "luasocket")
else
	why = "File not found"
end

if not ok then
	if GetConVarNumber'developer'>0 then
		Msg"[LuaDev] " print(("Unable to load luasocket module (%s), LuaDev socket API will be unavailable."):format(tostring(why)))
	end
	return
end


hook.Add("Think", "LuaDev-Socket",function() end)
hook.Remove("Think", "LuaDev-Socket") -- upvalues will be lost
if IsValid(SOCKETDEV) then
	SOCKETDEV:Remove()
	SOCKETDEV = nil
end

-- this is probably not needed. You could just close the socket.
collectgarbage()
collectgarbage() -- finalizers will be scheduled for execution in the first pass, but will only execute in the second pass


local sock = socket.tcp()
assert(sock:bind("127.0.0.1", 27099))
sock:settimeout(0)
sock:setoption("reuseaddr", true)
assert(sock:listen(0))

local methods = {
	self = function( sock )
		local who = sock:receive( "*l" )
		luadev.RunOnSelf( sock:receive( "*a" ), who )
		system.FlashWindow()
	end,
	sv = function( sock )
		local who = sock:receive( "*l" )
		luadev.RunOnServer( sock:receive( "*a" ), who )
		system.FlashWindow()
	end,
	sh = function( sock )
		local who = sock:receive( "*l" )
		luadev.RunOnShared( sock:receive( "*a" ), who )
		system.FlashWindow()
	end,
	cl = function( sock )
		local who = sock:receive( "*l" )
		luadev.RunOnClients( sock:receive( "*a" ), who )
		system.FlashWindow()
	end,
	ent = function( sock )
		local who = sock:receive( "*l" )
		local contents = "ENT = {}; local ENT=ENT; "
			.. sock:receive( "*a" )
			.. "; scripted_ents.Register(ENT, '"
			.. who:sub( 0, -5 )
			.. "')"
		luadev.RunOnShared( contents, who )
		system.FlashWindow()
	end,
	client = function( sock )
		local who = sock:receive( "*l" )
		local to = sock:receive( "*l" )
			to = easylua
				and easylua.FindEntity( to )
				or player.GetByID( tonumber( to ) )
			to = { to }
		luadev.RunOnClient( sock:receive( "*a" ), to, who )
		system.FlashWindow()
	end,
	requestPlayers = function( sock )
		local plys = {}
		for _, ply in next, player.GetAll() do
			table.insert( plys, ply:Nick() )
		end

		sock:send( table.concat( plys, "\n" ) )
	end
}

-- todo: there might be a problem with textmode gmod
SOCKETDEV = vgui.Create("Panel")
SOCKETDEV:SetMouseInputEnabled(false)
SOCKETDEV:SetKeyBoardInputEnabled(false)
SOCKETDEV:SetSize(0, 0)
SOCKETDEV.Think = function()
	local cl, a, b, c = sock:accept()
	if cl then
		if cl:getpeername() ~= "127.0.0.1" then
			print("Refused", cl:getpeername())
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
			methods[ method ]( cl )
		end

		cl:shutdown()
	end
end
