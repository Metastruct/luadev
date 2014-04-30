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
	RunOnSelf(script,CMD(who),MakeExtras(ply))
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


local PAYLOAD_SV=([===================[
local __SWP__=[[SWEPNAME]]
local SWEP,_REG_=weapons.GetStored(__SWP__),nil
if not SWEP then
	SWEP = {Primary={}, Secondary={},Base = "weapon_base",ClassName = __SWP__}
	_REG_ = true
end

CONTENT

if _REG_ and SWEP then
	weapons.Register(SWEP, __SWP__, true)
end
]===================]):gsub("\n"," ")
local PAYLOAD_CL=([===================[
local __SWP__=[[SWEPNAME]]
local SWEP,_REG_=weapons.GetStored(__SWP__),nil
if not SWEP then
	SWEP = {Primary={}, Secondary={},Base = "weapon_base",ClassName = __SWP__}
	_REG_ = true
end

CONTENT

if _REG_ and SWEP then
	weapons.Register(SWEP, __SWP__, true)
end
]===================]):gsub("\n"," ")
local PAYLOAD_SH=([===================[
local __SWP__=[[SWEPNAME]]
local SWEP,_REG_=weapons.GetStored(__SWP__),nil
if not SWEP then
	SWEP = {Primary={}, Secondary={},Base = "weapon_base",ClassName = __SWP__}
	_REG_ = true
end

CONTENT

if _REG_ and SWEP then
	local table_ForEach=table.ForEach table.ForEach=function()end timer.Simple(0,function() table.ForEach=table_ForEach end)
		weapons.Register(SWEP, __SWP__, true)
	table.ForEach=table_ForEach
end
]===================]):gsub("\n"," ")

local function SendSWEP(cl,sh,sv,Path,ply,c,cmd,who)
	local who=string.GetFileFromFilename(Path)
	
	local swepname=string.GetFileFromFilename(Path):gsub("%.lua","")
	print("SendSWEP",swepname,cl and #cl,sh and #sh,sv and #sv)

	if cl then
		cl = PAYLOAD_CL:gsub("CONTENT",cl):gsub("SWEPNAME",swepname)
		RunOnClients(cl,who or CMD(who),MakeExtras(ply))
	end
	if sh then
		sh = PAYLOAD_SH:gsub("CONTENT",sh):gsub("SWEPNAME",swepname)
		RunOnShared(sh,who or CMD(who),MakeExtras(ply))
	end
	if sv then
		sv = PAYLOAD_SV:gsub("CONTENT",sv):gsub("SWEPNAME",swepname)
		RunOnServer(sv,who or CMD(who),MakeExtras(ply))
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





-- entity
local PAYLOAD=([===================[
local _ENT_=[[ENTNAME]]
local ENT,_REG_=scripted_ents.GetStored(_ENT_),nil
if not ENT then
	ENT = {ClassName=_ENT_}
	_REG_ = true
end

CONTENT

if ENT then
	ENT.Model = ENT.Model or Model("models/props_borealis/bluebarrel001.mdl")
	if not ENT.Base then
		ENT.Base = "base_anim"
		ENT.Type = ENT.Type or "anim"
	end
	local table_ForEach=table.ForEach table.ForEach=function()end timer.Simple(0,function() table.ForEach=table_ForEach end)
		scripted_ents.Register(ENT, _ENT_)
	table.ForEach=table_ForEach
end

]===================]):gsub("\n"," "):gsub("\t\t"," "):gsub("  "," "):gsub("  "," ")

local function SendENT(cl,sh,sv,Path,ply,c,cmd,who)
	local who=string.GetFileFromFilename(Path)
	
	local entname=string.GetFileFromFilename(Path):gsub("%.lua","")
	print("SendENT",entname,cl and #cl,sh and #sh,sv and #sv)

	if cl then
		cl = PAYLOAD:gsub("CONTENT",cl):gsub("ENTNAME",entname)
		RunOnClients(cl,who or CMD(who),MakeExtras(ply))
	end
	if sh then
		sh = PAYLOAD:gsub("CONTENT",sh):gsub("ENTNAME",entname)
		RunOnShared(sh,who or CMD(who),MakeExtras(ply))
	end
	if sv then
		sv = PAYLOAD:gsub("CONTENT",sv):gsub("ENTNAME",entname)
		RunOnServer(sv,who or CMD(who),MakeExtras(ply))
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
	
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	local data={
		src=script,
		dst=TO_CLIENTS,
		info=who,
		extra=extra,
	}

	ToServer(data)

end


function RunOnSelf(script,who,extra)
	if not isstring(who) then who = nil end
	if not who and extra and isentity(extra) then extra = {ply=extra} end
	
	RunOnClient(script,LocalPlayer(),who,extra)
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

	ToServer(data)

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
	ToServer(data)

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

	ToServer(data)

end