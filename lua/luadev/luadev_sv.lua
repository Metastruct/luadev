module("luadev",package.seeall)

if CLIENT then return end 

luadev_verbose = CreateConVar( "luadev_verbose", "9", { FCVAR_NOTIFY } )
function Verbose(lev)
	return (luadev_verbose:GetInt(99) or 99)>=(lev or 1)
end

-- inform the client of the version
_luadev_version = CreateConVar( "_luadev_version", "1.5", FCVAR_NOTIFY )

function S2C(cl,msg)
	if cl and cl:IsValid() and cl:IsPlayer() then
		cl:ChatPrint("[LuaDev] "..tostring(msg))
	end
end

function RunOnClients(script,who,extra)
	local data={
		--src=script,
		info=who,
		extra=extra,
	}

	if Verbose() then
		Print(tostring(who).." running on clients")
	end

	net.Start(Tag)
		WriteCompressed(script)
		net.WriteTable(data)
	net.Broadcast()
end

local function ClearTargets(targets)
	local i=1
	local target=targets[i]
	while target do
		if not IsValid(target) then
			table.remove(targets,i)
			i=i-1
		end
		i=i+1
		target=targets[i]
	end
end


function RunOnClient(script,targets,who,extra)
	local data={
		--src=script,
		info=who,
		extra=extra,
	}

	if not istable(targets) then
		targets = {targets}		
	end
	
	ClearTargets(targets)
		
	local targetslist
	for _,target in pairs(targets) do
		local pre = targetslist and ", " or ""
		targetslist=(targetslist or "")..pre..tostring(target)
	end
	
	if Verbose() then
		Print(tostring(who).." running on "..tostring(targetslist or "NONE"))
	end

	net.Start(Tag)
		WriteCompressed(script)
		net.WriteTable(data)
	net.Send(targets)
end

function RunOnServer(script,who,extra)

	if Verbose() then
		Print(tostring(who).." running on server")
	end

	return Run(script,tostring(who),extra)
end

--function RunOnSelf(script,who,extra)
--	RunOnServer(script,who,extra)
--end

RunOnServer = RunOnSelf

function RunOnShared(...)
	RunOnClients(...)
	RunOnServer(...)
end


function GetPlayerIdentifier(ply,extrainfo)
	if type(ply)=="Player" then
	
		local info=ply:Name()
		info = info:gsub("%]","}"):gsub("%[","{"):gsub("%z","_") -- hack
		if Verbose(3) then
			info=ply:SteamID():gsub("^STEAM_","")
			info='<'..info..'|'..ply:GetName():sub(1,16)..'>'
		elseif Verbose(2) then
			info=ply:SteamID():gsub("^STEAM_","")
		end
		if extrainfo then
			info=info..'<'..tostring(extrainfo)..'>'
		end
		return info
	else
		return "??"..tostring(ply)
	end
end

function _ReceivedData(len, ply)
	
	local script = ReadCompressed() -- WriteCompressed(data)
	local decoded=net.ReadTable()
	decoded.src=script
	
	
	local target=decoded.dst
	local info = decoded.info
	local target_ply=decoded.dst_ply
	local extra=decoded.extra or {}
	if not istable(extra) then
		return RejectCommand (ply,"bad extra table")
	end
	extra.ply=ply
	
	if not CanLuaDev  (ply,script,nil,target,target_ply,extra) then
		return RejectCommand (ply)
	end

	TransmitHook(decoded)
	
	local identifier = GetPlayerIdentifier(ply,info)

	if 		target==TO_SERVER  then RunOnServer (script,			identifier,extra)
	elseif  target==TO_CLIENT  then	RunOnClient (script,target_ply,	identifier,extra)
	elseif  target==TO_CLIENTS then	RunOnClients(script,			identifier,extra)
	elseif  target==TO_SHARED  then	RunOnShared (script,			identifier,extra)
	else  	S2C(ply,"Unknown target")	
	end

end
net.Receive(Tag, function(...) _ReceivedData(...) end)
