module("luadev",package.seeall)

local verbose =	CreateConVar( "luadev_verbose", "1", { FCVAR_NOTIFY } )

function S2C(cl,msg)
	if cl and cl:IsValid() and cl:IsPlayer() then
		cl:PrintMessage(HUD_PRINTCONSOLE,"LuaDev:\tNo access")
	end
	
	
end


function RunOnClients(script,who)
	local data={
		src=script,
		info=who
	}
	
	if verbose:GetBool() then
		Print(tostring(who).." running on clients")
	end
	
	datastream.StreamToClients(player.GetAll(),Tag,data)
end

function RunOnClient(script,pl,who)
	local data={
		src=script,
		info=who
	}
	
	if verbose:GetBool() then
		Print(tostring(who).." running on "..tostring(pl))
	end
	
	datastream.StreamToClients(pl,Tag,data)
end

function RunOnServer(script,who)

	if verbose:GetBool() then
		Print(tostring(who).." running on server")
	end
	
	Run(script,tostring(who))
end



function RunOnShared(script,who)
	RunOnClients(script,who)
	RunOnServer(script,who)
end




function _ReceivedData(ply, handler, id, _, decoded)
	
	if !ply:IsSuperAdmin() then
		S2C(ply,"No Access")
		return
	end
		
	local script=decoded.src
	local target=decoded.dst
	local target_ply=decoded.dst_ply
	
	local info=ply:SteamID()
	if decoded.info then
		info=info..'/'..tostring(decoded.info)
	end
	
	if target==TO_SERVER then 		RunOnServer(script,info)
	elseif target==TO_CLIENT then	RunOnClient(script,target_ply,info)
	elseif target==TO_CLIENTS then	RunOnClients(script,info)
	elseif target==TO_SHARED then	RunOnShared(script,info)
	else 
		S2C(ply,"Unknown cmd")	
		return
	end
	
	
end
datastream.Hook(Tag, _ReceivedData)

hook.Add("AcceptStream", Tag, function(ply, handler, id)
	if handler==Tag then 
	
		if ply and ply:IsValid() and ply:IsSuperAdmin() then
			return true
		end
		
		S2C(ply,"No Access")
		
	end
end)

