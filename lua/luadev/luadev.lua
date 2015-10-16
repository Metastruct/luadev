module("luadev",package.seeall)

local function CMD(who)
	return CLIENT and "CMD" or who or "CMD"
end

COMMAND('run_sv',function(ply,_,script,who)
	RunOnServer(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_sh',function(ply,_,script,who)
	RunOnShared(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_clients',function(ply,_,script,who)
	RunOnClients(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_self',function(ply,_,script,who)
	RunOnSelf(script,CMD(who),MakeExtras(ply))
end,true)

COMMAND('run_client',function(ply,tbl,script,who)

	if !tbl[1] or !tbl[2] then Print("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) script") return end

	local cl=FindPlayer(tbl[1])

	if !cl then Print("Client not found!\n") return end
	if CLIENT then
		Print("Running script on "..tostring(cl:Name()))
	end

	local _, e = script:find('^%s*"[^"]+')
	if e then
		script = script:sub(e+2)
	else
		local _, e = script:find('^%s*[^%s]+%s')
		if not e then
			Print("Invalid Command syntax.")
			return
		end
		script = script:sub(e)
	end

	script = script:Trim()

	RunOnClient(script,cl,CMD(who),MakeExtras(ply))

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

	local content = Path and GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	RunOnClient(content,cl,who or CMD(who),MakeExtras(ply))

end)

COMMAND('send_sv',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = Path and GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnServer(content,who or CMD(who),MakeExtras(ply))

end)

COMMAND('send_clients',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = Path and GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnClients(content,who or CMD(who),MakeExtras(ply))

end)

COMMAND('send_sh',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = Path and GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnShared(content,who or CMD(who),MakeExtras(ply))

end)

local function Guess(name,Path)
	
	if name=="init" or name=="shared"  or name=="cl_init" then
		local newname = Path:gsub("\\","/"):match("^.+%/([^%/]-)/.-%.lua$")
		Print("Guessing identifier: "..tostring(newname or "<Failed>"))
		return newname or name
	end
	
	return name
end

local function SendEFFECT(cl,Path,ply,c,cmd,who)
	local who=string.GetFileFromFilename(Path)
	
	local effectname=string.GetFileFromFilename(Path):gsub("%.lua","")
	
	effectname = Guess(effectname,Path)
	
	if cl then
		RunOnClients(cl,who or CMD(who),MakeExtras(ply,{effect=effectname}))
	end
	
end

COMMAND('send_effect',function(ply,c,cmd,who)
	local path = c[2] and TableToString(c) or c[1]
	
	local Path,searchpath=RealFilePath(path)
	if not Path then
		Print("Could not find the file\n")
		return
	end
	
	local content = GiveFileContent(Path,searchpath)
	if content then
		local sh = content
		SendEFFECT(content,Path,ply,c,cmd,who)
		return
	end
	
	local cl = GiveFileContent(Path..'/init.lua',searchpath)
	
	if cl then
		SendEFFECT(cl,Path,ply,c,cmd,who)
		return
	else
		Print("Could not find required files from the folder\n")
	end

end)



local function SendSWEP(cl,sh,sv,Path,ply,c,cmd,who)
	local who=string.GetFileFromFilename(Path)
	
	local swepname=string.GetFileFromFilename(Path):gsub("%.lua","")
	swepname=Guess(swepname,Path)
	
	if cl then
		RunOnClients(cl,who or CMD(who),MakeExtras(ply,{swep=swepname}))
	end
	if sh then
		RunOnShared(sh,who or CMD(who),MakeExtras(ply,{swep=swepname}))
	end
	if sv then
		RunOnServer(sv,who or CMD(who),MakeExtras(ply,{swep=swepname}))
	end
	
end

COMMAND('send_wep',function(ply,c,cmd,who)
	local path = c[2] and TableToString(c) or c[1]
	
	local Path,searchpath=RealFilePath(path)
	if not Path then
		Print("Could not find the file\n")
		return
	end
	
	local content = GiveFileContent(Path,searchpath)
	if content then
		local sh = content
		SendSWEP(nil,sh,nil,Path,ply,c,cmd,who)
		return
	end
	
	local cl = GiveFileContent(Path..'/cl_init.lua',searchpath)
	local sh = GiveFileContent(Path..'/shared.lua',searchpath)
	local sv = GiveFileContent(Path..'/init.lua',searchpath)
	
	if sv or sh or cl then
		SendSWEP(cl,sh,sv,Path,ply,c,cmd,who)
		return
	else
		Print("Could not find required files from the folder\n")
	end

end)


local function SendENT(cl,sh,sv,Path,ply,c,cmd,who)
	local who=string.GetFileFromFilename(Path)
	
	local entname=string.GetFileFromFilename(Path):gsub("%.lua","")
	entname = Guess(entname,Path)
	if cl then
		RunOnClients(cl,who or CMD(who),MakeExtras(ply,{sent=entname}))
	end
	if sh then
		RunOnShared(sh,who or CMD(who),MakeExtras(ply,{sent=entname}))
	end
	if sv then
		RunOnServer(sv,who or CMD(who),MakeExtras(ply,{sent=entname}))
	end
	
end

COMMAND('send_ent',function(ply,c,cmd,who)
	local path = c[2] and TableToString(c) or c[1]
	
	local Path,searchpath=RealFilePath(path)
	if not Path then
		Print("Could not find the file\n")
		return
	end
	
	local content = GiveFileContent(Path,searchpath)
	if content then
		local sh = content
		SendENT(nil,sh,nil,Path,ply,c,cmd,who)
		return
	end
	
	local cl = GiveFileContent(Path..'/cl_init.lua',searchpath)
	local sh = GiveFileContent(Path..'/shared.lua',searchpath)
	local sv = GiveFileContent(Path..'/init.lua',searchpath)
	
	if sv or sh or cl then
		SendENT(cl,sh,sv,Path,ply,c,cmd,who)
		return
	else
		Print("Could not find required files from the folder\n")
	end

end)



COMMAND('send_self',function(ply,c,cmd,who)

	local Path,searchpath=RealFilePath(c[2] and TableToString(c) or c[1])
	if !Path then Print("Could not find the file\n") return end

	local content = GiveFileContent(Path,searchpath)
	if !content then Print("Could not read the file\n") return end

	local who=string.GetFileFromFilename(Path)

	RunOnSelf(content,who or CMD(who),MakeExtras(ply))

end)


if SERVER then return end

net.Receive(Tag,function(...) _ReceivedData(...) end)

function _ReceivedData(len)
	
	local script = ReadCompressed()
	local decoded=net.ReadTable()
	
	local info=decoded.info
	local extra=decoded.extra

	local ok,ret = Run(script,tostring(info),extra)

	if not ok then
		ErrorNoHalt(tostring(ret)..'\n')
	end
	
	--[[ -- Not done
	if extra.retid then
		net.Start(net_retdata)
			net.WriteUInt(extra.retid,32)
			net.WriteBool(ok)
			net.WriteTable(ret)
		net.SendToServer()
	end --]]

end


function ToServer(data)
	if TransmitHook(data)~=nil then return end
	
	net.Start(Tag)
		WriteCompressed(data.src or "")
		
		-- clear extra data
		data.src = nil
		if data.extra then
			data.extra.ply = nil
			if table.Count(data.extra)==0 then data.extra=nil end
		end
		
		net.WriteTable(data)
		if net.BytesWritten()==65536 then 
			Print("Unable to send lua code (too big)\n")
			return nil,"Unable to send lua code (too big)"
		end
		
	net.SendToServer()
	return true
end


function RunOnClients(script,who,extra)
	
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	local data={
		src=script,
		dst=TO_CLIENTS,
		info=who,
		extra=extra,
	}

	return ToServer(data)

end


function RunOnSelf(script,who,extra)
	if not isstring(who) then who = nil end
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	return RunOnClient(script,LocalPlayer(),who,extra)
end

function RunOnClient(script,targets,who,extra)
	-- compat
		if not targets and isentity(who) then
			targets=who
			who = nil
		end
		
		if extra and isentity(extra) and who==nil then extra={ply=extra} end
		
	if (not istable(targets) and !IsValid(targets))
	or (istable(targets) and table.Count(targets)==0)
	then error"Invalid player(s)" end
	
	local data={
		src=script,
		dst=TO_CLIENT,
		dst_ply=targets,
		info=who,
		extra=extra,
	}

	return ToServer(data)

end

function RunOnServer(script,who,extra)
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	local data={
		src=script,
		dst=TO_SERVER,
		--dst_ply=pl
		info=who,
		extra=extra,
	}
	return ToServer(data)

end

function RunOnShared(script,who,extra)
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	local data={
		src=script,
		dst=TO_SHARED,
		--dst_ply=pl
		info=who,
		extra=extra,
	}

	return ToServer(data)

end
