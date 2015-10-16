module("luadev",package.seeall)


-- inform the client of the version
_luadev_version = CreateConVar( "_luadev_version", "1.6", FCVAR_NOTIFY )

function S2C(cl,msg)
	if cl and cl:IsValid() and cl:IsPlayer() then
		cl:ChatPrint("[LuaDev] "..tostring(msg))
	end
end

function RunOnClients(script,who,extra)
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	local data={
		--src=script,
		info=who,
		extra=extra,
	}

	if Verbose() then
		PrintX(script,tostring(who).." running on clients")
	end

	net.Start(Tag)
		WriteCompressed(script)
		net.WriteTable(data)
		if net.BytesWritten()==65536 then 
			return nil,"too big"
		end
	net.Broadcast()
	
	return true
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
	-- compat
		if not targets and isentity(who) then
			targets=who
			who = nil
		end
		
		if extra and isentity(extra) and who==nil then
			extra={ply=extra}
			who="COMPAT"
		end
		
	local data={
		--src=script,
		info=who,
		extra=extra,
	}

	if not istable(targets) then
		targets = {targets}
	end
	
	ClearTargets(targets)
		
	if table.Count(targets)==0 then return nil,"no players" end
	
	local targetslist
	for _,target in pairs(targets) do
		local pre = targetslist and ", " or ""
		targetslist=(targetslist or "")..pre..tostring(target)
	end
	
	
	if Verbose() then
		PrintX(script,tostring(who).." running on "..tostring(targetslist or "NONE"))
	end

	net.Start(Tag)
		WriteCompressed(script)
		net.WriteTable(data)
		if net.BytesWritten()==65536 then 
			return nil,"too big"
		end
	net.Send(targets)
	
	return #targets
end

function RunOnServer(script,who,extra)
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	if Verbose() then
		PrintX(script,tostring(who).." running on server")
	end

	return Run(script,tostring(who),extra)
end

function RunOnSelf(script,who,extra)
	if not isstring(who) then who = nil end
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	return RunOnServer(script,who,extra)
end


function RunOnShared(...)
	RunOnClients(...)
	return RunOnServer(...)
end


function GetPlayerIdentifier(ply,extrainfo)
	if type(ply)=="Player" then
	
		local info=ply:Name()
		
		if Verbose(3) then
			local sid=ply:SteamID():gsub("^STEAM_","")
			info=('<%s|%s>'):format(sid,info:sub(1,24))
		elseif Verbose(2) then
			info=ply:SteamID():gsub("^STEAM_","")
		end
		if extrainfo then
			info=('%s<%s>'):format(info,tostring(extrainfo))
		end
		
		info = info:gsub("%]","}"):gsub("%[","{"):gsub("%z","_") -- GMod bug
		
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

	if TransmitHook(data)~=nil then return end
	
	local identifier = GetPlayerIdentifier(ply,info)
	local ok,err
	if 		target==TO_SERVER  then ok,err=RunOnServer (script,				identifier,extra)
	elseif  target==TO_CLIENT  then	ok,err=RunOnClient (script,target_ply,	identifier,extra)
	elseif  target==TO_CLIENTS then	ok,err=RunOnClients(script,				identifier,extra)
	elseif  target==TO_SHARED  then	ok,err=RunOnShared (script,				identifier,extra)
	else  	S2C(ply,"Unknown target")
	end
	
	-- no callback system yet
	if not ok then
		ErrorNoHalt(tostring(err)..'\n')
	end
	
end
net.Receive(Tag, function(...) _ReceivedData(...) end)
