module("luadev",package.seeall)

local verbose =	CreateConVar( "luadev_verbose", "1", { FCVAR_NOTIFY } )

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
	
	datastream.StreamToClients(player.GetAll(),Tag,data)
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
	
	datastream.StreamToClients(pl,Tag,data)
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




function _ReceivedData(ply, handler, id, _, decoded)
	
	if !(nero and ply:IsAdmin() or ply:IsSuperAdmin()) then
		S2C(ply,"No Access")
		return
	end
		
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
datastream.Hook(Tag, _ReceivedData)

hook.Add("AcceptStream", Tag, function(ply, handler, id)
	if handler==Tag then 
	
		if ply and ply:IsValid() and (nero and ply:IsAdmin() or ply:IsSuperAdmin()) then
			return true
		end
		
		S2C(ply,"No Access")
		
	end
end)

