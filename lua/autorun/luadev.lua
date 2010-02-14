
if not datastream then
 require"datastream"
end

local rawname="rawio"

local function HasAcl(pl)
	if !pl then return true end
	if !pl:IsPlayer() or pl:IsSuperAdmin() then
		return true
	else
		if pl:IsPlayer() then
			pl:PrintMessage(HUD_PRINTCONSOLE,"LuaDev(sv):	No access")
		end
		return false
	end
end

local UPLOADHANDLE="luadev_up"
local UPLOADCHANDLE="luadev_upc"
local UploadID = nil

local function Out(msg)
		Msg("LuaDev:	"..tostring(msg).."\n")
end


local function initraw()
	if not rawio then
		require(rawname)
	end
	return rawio!=nil
end

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
	Out("Reading: "..tostring(fullpath))

	if fullpath==nil or fullpath=="" then return nil end
	
	local content=rawio.readfile(fullpath)
	if content==0 then return nil end
	return content
	
end



luadev=luadev or {}

if SERVER then
	AddCSLuaFile'luadev.lua'
		
	datastream.Hook(UPLOADHANDLE, function(ply, handler, id, encoded, decoded)
			if decoded && HasAcl(ply) then
				Out("Running script from "..tostring(ply))
				pcall(RunString,decoded)
			end
	end)
		

	datastream.Hook(UPLOADCHANDLE, function(ply, handler, id, encoded, decoded)
			if decoded && HasAcl(ply) then
				Out("Running script on clients by "..tostring(ply))
				datastream.StreamToClients(player.GetAll(),UPLOADCHANDLE,decoded)
			end
	end)
		
	hook.Add("AcceptStream", "luadevaccept", function(ply, handler, id)
			if !HasAcl(ply) and (handler == UPLOADHANDLE or handler == UPLOADCHANDLE) then
				Out("Denied script transfer from "..tostring(ply))
				return false
			end
			if HasAcl(ply) and (handler == UPLOADHANDLE or handler == UPLOADCHANDLE) then
				Out("Transfering script from "..tostring(ply))
				return true
			end
	end)


	local META = FindMetaTable("CRecipientFilter")
	if META then
		function META:IsValid()
			return true
		end
	else
		ErrorNoHalt(os.date().." WTF@THIS\n")
	end
	
	function luadev.RunOnClients(script)
		Out("Sending to clients")
		datastream.StreamToClients(player.GetAll(),UPLOADCHANDLE,script)
	end
	
	
	concommand.Add('lua_run_sv',function(ply,b,c)
		if HasAcl(ply) then
		
			Out("Running script from "..tostring(ply or "Console"))
			
			local thestring = string.Implode("",c)
			
			if ply:IsPlayer() then
				ply:PrintMessage(HUD_PRINTCONSOLE,"LuaDev: Running on server: "..thestring)
			end
			
			pcall(RunString,thestring)
			
		end
	end)
	
	
	concommand.Add('lua_run_sh',function(ply,b,c)
		if HasAcl(ply) then
		
			Out("Running on clients by "..tostring(ply or "Console"))
			
			local thestring = string.Implode("",c)
			
			if ply:IsPlayer() then
				ply:PrintMessage(HUD_PRINTCONSOLE,"LuaDev: Running on clients: "..thestring)
			end
			
			luadev.RunOnClients(thestring)
			
		end
		
	end)
	

	concommand.Add('lua_send_clients',function(a,b,c)
	if not initraw() then return end
	local Path=RealFilePath(c[1])
	if !Path then Out("Could not find the file") return end
	local content = GiveFileContent(Path)
	if !content then Out("Could not read the file") return end
	luadev.RunOnClients(content)
	end)
	
	
	return
	
end


function luadev.RunOnClients(script)

	if UploadID then Out("Already uploading") end 
 
	local function done()
		UploadID = nil
		Out("Uploaded the script")
	end
	
	local function accepted(accepted, tempid, id)
		if(accepted) then
			UploadID = id
			Out("Uploading..")
		else
			Out("Upload refused")
		end
	end
	
	datastream.StreamToServer(UPLOADCHANDLE, script, done, accepted)
 end
 


function luadev.RunOnSelf(script)
	local did, err = pcall(RunString,script)
	if !did then 
		Out(tostring(err))
	end
end
 
 
-- From server to client, run
datastream.Hook(UPLOADCHANDLE,function (handler, id, encoded, decoded)
	luadev.RunOnSelf(decoded)
end)

 
 

 
function luadev.RunOnServer(script)
	if UploadID then Out("Already uploading") end 
 
	local function done()
		UploadID = nil
		Out("Uploaded the script")
	end
	
	local function accepted(accepted, tempid, id)
		if(accepted) then
			UploadID = id
			Out("Uploading..")
		else
			Out("Upload denied")
		end
	end
	
	datastream.StreamToServer(UPLOADHANDLE, script, done, accepted)
 end




-- AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
local function AutoComplete(commandName,args)

	local name = string.Explode(' ',args)
	
	name=name[#name] or ""

	local path = string.GetPathFromFilename(name)

	local candidates=file.FindInLua((name or "").."*")
	
	for i,_ in pairs(candidates) do
		candidates[i]=commandName.." "..path..candidates[i]
	end

	return candidates
	
end

concommand.Add('lua_send_clients',function(a,b,c)
	if not initraw() then return end
	local Path=RealFilePath(c[1])
	if !Path then Out("Could not find the file") return end
	local content = GiveFileContent(Path)
	if !content then Out("Could not read the file") return end
	luadev.RunOnClients(content)
end,AutoComplete)


concommand.Add('lua_send_self',function(a,b,c)
	if not initraw() then return end
	local Path=RealFilePath(c[1])
	if !Path then Out("Could not find the file") return end
	local content = GiveFileContent(Path)
	if !content then Out("Could not read the file") return end
	luadev.RunOnSelf(content)
end,AutoComplete)



concommand.Add('lua_run_self',function(a,b,c)
	local thestring = string.Implode("",c) -- todo?
	luadev.RunOnSelf(thestring)
end)


concommand.Add('lua_send_server',function(a,b,c)
	if not initraw() then return end
	local Path=RealFilePath(c[1])
	if !Path then Out("Could not find the file") return end
	local content = GiveFileContent(Path)
	if !content then Out("Could not read the file") return end
	luadev.RunOnServer(content)
end,AutoComplete)



