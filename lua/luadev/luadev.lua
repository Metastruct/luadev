module("luadev",package.seeall)

local function CMD(who)
	return CLIENT and "CMD" or who or "CMD"
end

COMMAND('run_sv',function(ply,_,script,who)
	RunOnServer(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_sh',function(ply,_,cmd,who)
	RunOnShared(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_clients',function(ply,_,script,who)
	RunOnClients(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_self',function(ply,_,script,who)
	if CLIENT then
		RunOnClient(script,LocalPlayer(),CMD(who),MakeExtras(ply))
	else
		RunOnServer(script,CMD(who),MakeExtras(ply))
	end
end,true)

COMMAND('run_client',function(ply,tbl,cmd,who)

	if !tbl[1] or !tbl[2] then Print("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) script") return end

	local cl=FindPlayer(tbl[1])

	if !cl then Print("Client not found!\n") return end
	if CLIENT then
		Print("Running script on "..tostring(cl:Name()))
	end

	table.remove(tbl,1)
	local cmd=TableToString(tbl)

	RunOnClient(cmd,cl,CMD(who),MakeExtras(ply))

end)

COMMAND('send_cl',function(ply,tbl,cmd,who)

	if !tbl[1] or !tbl[2] then Print("Syntax: lua_send_cl (steamid/userid/uniqueid/part of name) \"path\"") return end

	local cl=FindPlayer(tbl[1])

	if !cl then Print("Client not found!\n") return end
	Print("Running script on "..tostring(cl:Name()))


	table.remove(tbl,1)
	local path=TableToString(tbl)

	local Path,searchpath=RealFilePath(path)
	if !Path then Print("Could not find the file\n") return end

	local content = GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	RunOnClient(content,cl,who or CMD(who),MakeExtras(ply))

end)

COMMAND('send_sv',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnServer(content,who or CMD(who),MakeExtras(ply))

end)

COMMAND('send_clients',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnClients(content,who or CMD(who),MakeExtras(ply))

end)

COMMAND('send_sh',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnShared(content,who or CMD(who),MakeExtras(ply))

end)

if SERVER then return end


function _ReceivedData(len)
	
	local script = ReadCompressed()
	local decoded=net.ReadTable()
	
	local info=decoded.info
	local extra=decoded.extra

	Run(script,tostring(info),extra)

end

net.Receive(Tag,function(...) _ReceivedData(...) end)

function ToServer(data)
	TransmitHook(data)
	
	net.Start(Tag)
		WriteCompressed(data.src or "")
		
		-- clear extra data
		data.src = nil
		if data.extra then
			data.extra.ply = nil
			if table.Count(data.extra)==0 then data.extra=nil end
		end
		
		net.WriteTable(data)
	net.SendToServer()
end

function RunOnClients(script,who,extra)

	local data={
		src=script,
		dst=TO_CLIENTS,
		info=who,
		extra=extra,
	}

	ToServer(data)

end

function RunOnClient(script,pl,who,extra)
	
	-- gcompute compat...
	if pl==nil and isentity(who) and who:IsPlayer() then
		pl=who
		who=nil
	end
	
	if not istable(pl) and !IsValid(pl) then error"Invalid player" end
	local data={
		src=script,
		dst=TO_CLIENT,
		dst_ply=pl,
		info=who,
		extra=extra,
	}

	ToServer(data)

end

function RunOnServer(script,who,extra)

	local data={
		src=script,
		dst=TO_SERVER,
		--dst_ply=pl
		info=who,
		extra=extra,
	}	
	ToServer(data)

end

function RunOnShared(script,who,extra)

	local data={
		src=script,
		dst=TO_SHARED,
		--dst_ply=pl
		info=who,
		extra=extra,
	}

	ToServer(data)

end