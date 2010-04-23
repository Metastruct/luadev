if not datastream then
 require"datastream"
end
if not datastream then
	error"Datastream removed?"
end

local _ErrorNoHalt=ErrorNoHalt

module("luadev",package.seeall)
Msg("Loading LuaDev... ")

CLIENT_TO_CLIENTS="LUADEVC2CS"

CLIENT_TO_CLIENT="LUADEVC2C"

CLIENT_TO_SERVER="LUADEVC2S"

SERVER_TO_CLIENT="LUADEVS2C"


--local UPLOADHANDLE="luadev_up"
--local UPLOADCHANDLE="luadev_upc"
UploadID = nil


function A2CON(msg)
		MsgN("LuaDev_"..(SERVER and "sv" or "cl")..":\t"..tostring(msg))
end



function Run(script,ply)
	
	pcall(RunString,script)
	
end


function IsOneLiner(script)
	return string.find(script,"\n")==nil
end
--[[
-- RAWIO LOADING
-- This does not block everyone but should be sufficient not to get every script kiddy on your rawio.
-- TODO: Make safe rawio with read only feature and only on lua folder
	local RAWIO=nil
	local rawioname="rawio"
	concommand.Add('luadev_tellraw',function(a,b,c)
		rawioname=c[1]
		InitRawIO()
	end)

	function InitRawIO()
		
		if RAWIO then return true end
		
		A2CON("Loading rawio..")
		if not rawio then
			require(rawioname)
			if rawio then
				RAWIO=rawio
				rawio=nil
			end
		else
			RAWIO=rawio
		end
		if !RAWIO then
			ErrorNoHalt("Rawio not found!\n")
			return false
		end
		
	end
-- END OF RAWIO



local function RealFilePath(name)
	local RelativePath='lua/'..name
	if !file.Exists('../'..RelativePath) then return nil end
	local dir = util.RelativePathToFull(RelativePath)
	if dir == "" or dir==RelativePath or dir==nil then
		return nil
	else
		return dir
	end
end

local function GiveFileContent(fullpath)
	A2CON("Reading: "..tostring(fullpath))
	if fullpath==nil or fullpath=="" then return false end
	
	local content=rawio.readfile(fullpath)
	if content==0 then return false end
	return content
end

/*
function Access(pl)
	return LocalPlayer and LocalPlayer():Name() or "??"
end
*/
]]


-- Stubbed. file.Read is sufficient..
function InitRawIO()
	if RAWIO or file.Read then return true end
end


function RealFilePath(name)
	local RelativePath='../lua/'..name
	if !file.Exists(RelativePath) then return nil end
	return RelativePath
end

function GiveFileContent(fullpath)
	--A2CON("Reading: "..tostring(fullpath))
	if fullpath==nil or fullpath=="" then return false end
	
	local content=file.Read(fullpath)
	if content==0 then return false end
	return content
end



function TableToString(tbl)
	return string.Implode(" ",tbl)
end

	
 
if SERVER then
	include'luadev_sv.lua'

	concommand.Add('lua_send_sv',function(pl,_,c)

		if pl:IsValid() then return end
		
		if not InitRawIO() then return end
		
		local Path=RealFilePath(c[2] and TableToString(c) or c[1])
		
		if !Path then ErrorNoHalt("Could not find the file\n") return end
		
		local content = GiveFileContent(Path)
		
		if !content then ErrorNoHalt("Could not read the file\n") return end
		
		A2CON("Running script from console")
		
		RunOnServer(content)
		
	end)


	concommand.Add('lua_send_sh',function(pl,_,c)

		if pl:IsValid() then return end
	
		if not InitRawIO() then return end
		
		local Path=RealFilePath(c[2] and TableToString(c) or c[1])
		
		if !Path then ErrorNoHalt("Could not find the file\n") return end
		
		local content = GiveFileContent(Path)
		
		if !content then ErrorNoHalt("Could not read the file\n") return end
		
		A2CON("Running script on clients from console")
		
		RunOnClients(content)
		
	end)



	concommand.Add('lua_send_self',function(pl,_,c)

		if pl then return end
	
		if not InitRawIO() then return end
		
		local Path=RealFilePath(c[2] and TableToString(c) or c[1])
		
		if !Path then ErrorNoHalt("Could not find the file\n") return end
		
		local content = GiveFileContent(Path)
		
		if !content then ErrorNoHalt("Could not read the file\n") return end
		
		Run(content)
		
	end)
	
end


-----------------------------------------------------------------
if SERVER then MsgN("Loaded! (server)") return end
-----------------------------------------------------------------

datastream.Hook(SERVER_TO_CLIENT,function (handler, id, encoded, decoded)
	Run(decoded)
end)


function RunOnClients(script)
	
	if UploadID then A2CON("Error: Already uploading") end 
 
	local function done()
		UploadID = nil
		A2CON("Uploaded script!")
	end
	
	local function accepted(accepted, tempid, id)
		if(accepted) then
			UploadID = UploadID or id
			A2CON("Uploading ..")
		else
			A2CON("Error: Upload refused!")
		end
	end
	
	datastream.StreamToServer(CLIENT_TO_CLIENTS, script, done, accepted)
	
end

function RunOnClient(script,cl)
	
	if !cl or !cl:IsValid() then return false end
	
	if UploadID then A2CON("Error: Already uploading") end 
 
	local function done()
		UploadID = nil
		A2CON("Uploaded script!")
	end
	
	local function accepted(accepted, tempid, id)
		if(accepted) then
			UploadID = UploadID or id
			A2CON("Uploading ..")
		else
			A2CON("Error: Upload refused!")
		end
	end
	
	datastream.StreamToServer(CLIENT_TO_CLIENT, {player=cl,script=script}, done, accepted)
	
end


function RunOnServer(script)
	if UploadID then A2CON("Error: Already uploading") end 
 
	local function done()
		UploadID = nil
		A2CON("Uploaded script!")
	end
	
	local function accepted(accepted, tempid, id)
		if(accepted) then
			UploadID = UploadID or id
			A2CON("Uploading ..")
		else
			A2CON("Error: Upload refused!")
		end
	end
	
	datastream.StreamToServer(CLIENT_TO_SERVER, script, done, accepted)
end






concommand.Add('lua_run_sv',function(ply,_,tbl)
	local cmd=TableToString(tbl)
	RunOnServer(cmd)
end)

concommand.Add('lua_run_sh',function(ply,_,tbl)
	local cmd=TableToString(tbl)
	RunOnClients(cmd)
end)

concommand.Add('lua_run_self',function(_,_,tbl)
	local cmd=TableToString(tbl)
	Run(cmd)
end)


concommand.Add('lua_run_client',function(_,_,tbl)
	
	if !tbl[1] or !tbl[2] then A2CON("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) script") return end

	local plyid=tostring(tbl[1])
	
	
	local cl=nil
	for k,v in pairs(player.GetAll()) do
		if v:SteamID()==plyid or v:UniqueID()==plyid or tostring(v:UserID())==plyid then
			cl=v
			break
		end
	end
	if !cl then
		for k,v in pairs(player.GetAll()) do
			if string.find(v:Name(),plyid) then
				cl=v
				break
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



concommand.Add('lua_send_cl',function(_,_,tbl)


	if !tbl[1] or !tbl[2] then A2CON("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) \"path\"") return end

	local plyid=tostring(tbl[1])
	
	
	local cl=nil
	for k,v in pairs(player.GetAll()) do
		if v:SteamID()==plyid or v:UniqueID()==plyid or tostring(v:UserID())==plyid then
			cl=v
			break
		end
	end
	if !cl then
		for k,v in pairs(player.GetAll()) do
			if string.find(v:Name(),plyid) then
				cl=v
				break
			end
		end
	end
	
	if !cl then ErrorNoHalt("Client not found!\n") return end
	A2CON("Running script on "..tostring(cl:Name()))
	
	
	table.remove(tbl,1)
	local path=TableToString(tbl)
	


	if not InitRawIO() then return end
	
	local Path=RealFilePath(path)
	
	if !Path then ErrorNoHalt("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then ErrorNoHalt("Could not read the file\n") return end
	
	if cl==LocalPlayer() then
		Run(content)
	end
	
	RunOnClient(content,cl)
	
end)--,AutoComplete) -- todo :(




	
function AutoComplete(commandName,args)

	local name = string.Explode(' ',args)
	
	name=name[#name] or ""

	local path = string.GetPathFromFilename(name)

	local candidates=file.FindInLua((name or "").."*")
	
	for i,_ in pairs(candidates) do
		candidates[i]=commandName.." "..path..candidates[i]
	end

	return candidates
	
end	








concommand.Add('lua_send_sv',function(_,_,c)

	if not InitRawIO() then return end
	
	local Path=RealFilePath(c[2] and TableToString(c) or c[1])
	
	if !Path then ErrorNoHalt("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then ErrorNoHalt("Could not read the file\n") return end
	
	RunOnServer(content)
	
end,AutoComplete)


concommand.Add('lua_send_sh',function(_,_,c)

	if not InitRawIO() then return end
	
	local Path=RealFilePath(c[2] and TableToString(c) or c[1])
	
	if !Path then ErrorNoHalt("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then ErrorNoHalt("Could not read the file\n") return end
	
	RunOnClients(content)
	
end,AutoComplete)




concommand.Add('lua_send_self',function(_,_,c)

	if not InitRawIO() then return end
	
	local Path=RealFilePath(c[2] and TableToString(c) or c[1])
	
	if !Path then ErrorNoHalt("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then ErrorNoHalt("Could not read the file\n") return end
	
	Run(content)
	
end,AutoComplete)

MsgN("Loaded! (client)")