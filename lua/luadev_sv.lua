module("luadev",package.seeall)

AddCSLuaFile'autorun/luadev.lua'

/*
CLIENT_TO_CLIENTS="LUADEVC2CS"

CLIENT_TO_CLIENT="LUADEVC2C"

CLIENT_TO_SERVER="LUADEVC2S"

SERVER_TO_CLIENT="LUADEVS2C"
*/

function Access(pl)
	if !pl:IsValid() then return "Console" end
	if !pl:IsPlayer() or pl:IsSuperAdmin() then
		return pl:Name()
	else
		return false
	end
end

function S2C(cl,msg)
	if cl and cl:IsValid() and cl:IsPlayer() then
		cl:PrintMessage(HUD_PRINTCONSOLE,"LuaDev:\tNo access")
	end
	
	-- Console?
	if !cl or cl:IsValid() then
		MsgN("LuaDev:\t"..tostring(msg))
	end
end

datastream.Hook(CLIENT_TO_SERVER, function(ply, handler, id, encoded, decoded)
		local acl=Access(ply,CLIENT_TO_SERVER)
		if !acl then
			S2C(ply,"Error: No Access to LuaDev!")
			return	end
		
		
		if !decoded then
			S2C(ply,"Error: Decoding failure!")
			return	end
		
		A2CON("Running script from "..tostring(acl))
		if IsOneLiner(decoded) then
			print("   Script:\t'"..tostring(decoded).."'")
		end
		Run(decoded,ply)
end)
		

datastream.Hook(CLIENT_TO_CLIENTS, function(ply, handler, id, encoded, decoded)
		local acl=Access(ply,CLIENT_TO_CLIENTS)
		if !acl then
			S2C(ply,"Error: No Access to LuaDev!")
			return	end

		if !decoded then
			S2C(ply,"Error: Decoding failure!")
			return	end
		
		
		A2CON("Running script on clients from "..tostring(acl))
			if IsOneLiner(decoded) then
				print("   Script:\t'"..tostring(decoded).."'")
			end
		RunOnClients(decoded)

end)


datastream.Hook(CLIENT_TO_CLIENT, function(ply, handler, id, encoded, decoded)
		local acl=Access(ply,CLIENT_TO_CLIENT)
		if !acl then
			S2C(ply,"Error: No Access to LuaDev!")
			return	end

		if !decoded or !decoded.script or type(decoded.script)!="string" then
			S2C(ply,"Error: Decoding failure!")
			return	end
		
		local target=decoded.player
		if !target or !target:IsValid() then
			S2C(ply,"Error: Player invalid ("..tostring(target)..")!")
			return	end
		
		
		A2CON("Running script on client '"..tostring(target and target:Name()).."' from "..tostring(acl))
			if IsOneLiner(decoded.script) then
				print("   Script:\t'"..tostring(decoded.script).."'")
			end
			
		RunOnClient(decoded.script,target)
end)

hook.Add("AcceptStream", "LuaDev", function(ply, handler, id)
		if handler!=CLIENT_TO_CLIENTS and handler!=CLIENT_TO_CLIENT  and handler!=CLIENT_TO_SERVER then
			return -- not ours
		end
		
		local acl=Access(ply,handler)
		if !acl then
			S2C(ply,"Error: No Access to LuaDev!")
			return end
		
		
end)

function RunOnClients(script)
	datastream.StreamToClients(player.GetAll(),SERVER_TO_CLIENT,script)
end

function RunOnClient(script,pl)
	datastream.StreamToClients(pl,SERVER_TO_CLIENT,script)
end

function RunOnServer(script)
	Run(script)
end



-- Serverside commands for same stuff

concommand.Add('lua_run_sv',function(ply,_,tbl)
	
	-- Other way to block clients from running?
	if ply:IsValid() then return end

	local cmd=TableToString(tbl)
		A2CON("Running script from server console")
		print("   Script:\t'"..tostring(cmd).."'")

	
	RunOnServer(cmd)
end)

concommand.Add('lua_run_sh',function(ply,_,tbl)

	if ply:IsValid() then return end

	local cmd=TableToString(tbl)
		A2CON("Running script on clients from console")
		print("   Script:\t'"..tostring(cmd).."'")
	RunOnClients(cmd)
end)

concommand.Add('lua_run_self',function(ply,_,tbl)

	if ply:IsValid() then return end
	
	local cmd=TableToString(tbl)
		A2CON("Running script from console")
		print("   Script:\t'"..tostring(cmd).."'")

	
	RunOnServer(cmd)
end)


concommand.Add('lua_run_client',function(ply,_,tbl)
	
	if ply:IsValid() then return end
	
	if !tbl[1] or !tbl[2] then A2CON("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) script") return end

	local plyid=tostring(tbl[1])
	
	
	local cl=nil
	for k,v in pairs(player.GetAll()) do
		if v:SteamID()==plyid or v:UniqueID()==plyid or tostring(v:UserID())==plyid then
			cl=v
			return
		end
	end
	if !cl then
		for k,v in pairs(player.GetAll()) do
			if string.find(v:Name(),plyid) then
				cl=v
				return
			end
		end
	end
	
	if !cl then ErrorNoHalt("Client not found!\n") return end
	A2CON("Running script on "..tostring(cl:Name()))
	
	
	table.remove(tbl,1)
	local cmd=TableToString(tbl)
	
	if cl==LocalPlayer() then
		Run(cmd)
	end
	
	RunOnClient(cmd,cl)
	
end)
