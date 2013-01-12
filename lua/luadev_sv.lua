module("luadev",package.seeall)

util.AddNetworkString(Tag)

local verbose =	CreateConVar( "luadev_verbose", "1", { FCVAR_NOTIFY } )

-- inform the client of the version
local version = CreateConVar( "_luadev_version", "1.4", FCVAR_NOTIFY )

function S2C(cl,msg)
	if cl and cl:IsValid() and cl:IsPlayer() then
		cl:PrintMessage(HUD_PRINTCONSOLE,"LuaDev:\tNo access")
	end
end


function RunOnClients(script,who,extra)
	local data={
		src=script,
		info=who,
		extra=extra,
	}

	if verbose:GetBool() then
		Print(tostring(who).." running on clients")
	end

	net.Start(Tag)
		net.WriteTable(data)
	net.Broadcast()
end

function RunOnClient(script,pl,who,extra)
	local data={
		src=script,
		info=who,
		extra=extra,
	}

	if verbose:GetBool() then
		Print(tostring(who).." running on "..tostring(pl))
	end

	net.Start(Tag)
		net.WriteTable(data)
	net.Send(pl)
end

function RunOnServer(script,who,extra)

	if verbose:GetBool() then
		Print(tostring(who).." running on server")
	end

	Run(script,tostring(who),extra)
end



function RunOnShared(script,who,extra)
	RunOnClients(script,who,extra)
	RunOnServer(script,who,extra)
end




function _ReceivedData(len, ply)

	if not ply:IsAdmin() and not ply:IsSuperAdmin() then
		S2C(ply,"No Access")
		return
	end
	local decoded=net.ReadTable()
	local script=decoded.src
	local target=decoded.dst
	local target_ply=decoded.dst_ply
	local extra=decoded.extra

	local info=ply:SteamID()
	if decoded.info then
		info=info..'/'..tostring(decoded.info)
	end

	if target==TO_SERVER then 		RunOnServer(script,info,extra)
	elseif target==TO_CLIENT then	RunOnClient(script,target_ply,info,extra)
	elseif target==TO_CLIENTS then	RunOnClients(script,info,extra)
	elseif target==TO_SHARED then	RunOnShared(script,info,extra)
	else 
		S2C(ply,"Unknown cmd")	
		return
	end


end
net.Receive(Tag, _ReceivedData)