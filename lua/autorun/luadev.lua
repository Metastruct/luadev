module("luadev",package.seeall)

include'luadev_sh.lua'

if not AddCMD then return end

AddCMD('run_sv',function(tbl)
	local cmd=TableToString(tbl)
	RunOnServer(cmd,"console")
end,true)

AddCMD('run_sh',function(tbl)
	local cmd=TableToString(tbl)
	RunOnShared(cmd,"console")
end,true)


AddCMD('run_clients',function(tbl)
	local cmd=TableToString(tbl)
	RunOnClients(cmd,"console")
end,true)

--[[
AddCMD('run_self',function(tbl)
	local cmd=TableToString(tbl)
	Run(cmd,"console")
end,true)]]


AddCMD('run_client',function(tbl)
	
	if !tbl[1] or !tbl[2] then Print("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) script") return end

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
	
	if !cl then Print("Client not found!\n") return end
	Print("Running script on "..tostring(cl:Name()))
	
	
	table.remove(tbl,1)
	local cmd=TableToString(tbl)
	
	
	RunOnClient(cmd,cl,"console")
	
end)



AddCMD('send_cl',function(tbl)


	if !tbl[1] or !tbl[2] then Print("Syntax: lua_run_client (steamid/userid/uniqueid/part of name) \"path\"") return end

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
	
	if !cl then Print("Client not found!\n") return end
	Print("Running script on "..tostring(cl:Name()))
	
	
	table.remove(tbl,1)
	local path=TableToString(tbl)
	

 
	
	local Path=RealFilePath(path)
	
	if !Path then Print("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then Print("Could not read the file\n") return end
	
	RunOnClient(content,cl,"console")
	
end)


AddCMD('send_sv',function(c)
 
	local Path=RealFilePath(c[2] and TableToString(c) or c[1])
	
	if !Path then Print("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then Print("Could not read the file\n") return end
	
	local who=string.GetFileFromFilename(Path)
	
	RunOnServer(content,who)
	
end)

AddCMD('send_clients',function(c)
 
	local Path=RealFilePath(c[2] and TableToString(c) or c[1])
	
	if !Path then Print("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then Print("Could not read the file\n") return end
	
	local who=string.GetFileFromFilename(Path)
	
	RunOnClients(content,who)
	
end)


AddCMD('send_sh',function(c)
 
	local Path=RealFilePath(c[2] and TableToString(c) or c[1])
	
	if !Path then Print("Could not find the file\n") return end
	
	local content = GiveFileContent(Path)
	
	if !content then Print("Could not read the file\n") return end
	
	local who=string.GetFileFromFilename(Path)
	
	RunOnShared(content,who)
	
	
end)

	
	
if SERVER then
	AddCSLuaFile 'luadev.lua'
	include 'luadev_sv.lua'
	return
end



function _ReceivedData(_,_,_,decoded)

	local script=decoded.src
	local info=decoded.info
	local extra=decoded.extra
	
	Run(script,tostring(info),extra)

end
datastream.Hook(Tag,_ReceivedData)




---- Base info callbacks
function UploadFinished()
	Print("Uploaded!")
end

function UploadInfo(accepted, tempid, id)
	if accepted then Print"Uploading" else Print"Error: Upload refused!"	end
end


function ToServer(data)
	datastream.StreamToServer(Tag, data, UploadFinished, UploadInfo)
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
	
	if !pl:IsValid() then error"Invalid player" end
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
