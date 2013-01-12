module("luadev",package.seeall)


Tag="LuaDevTag"

if SERVER then
	AddCSLuaFile 'luadev_sh.lua'
end

-- Enums
TO_CLIENTS=1
TO_CLIENT=2
TO_SERVER=3
TO_SHARED=4


function Print(msg)
	Msg("[Luadev"..(SERVER and ' Server' or '').."] ")
	print(msg)
end

function Run(script,info,extra)
	if !script then debug.Trace() ErrorNoHalt"no script" end
	if !info then info="LuaDev" end

	if hook.Call("PreLuaDevRun", nil, script, info, extra) ~= false then
		RunStringEx(script,info)
		hook.Call("PostLuaDevRun", nil, script, info, extra)
	end

end

function IsOneLiner(script)
	return string.find(script,"\n")==nil
end

function RealFilePath(name)
	local RelativePath='lua/'..name
	if !file.Exists(RelativePath,"GAME") then return nil end
	return RelativePath
end

function GiveFileContent(fullpath)
	--Print("Reading: "..tostring(fullpath))
	if fullpath==nil or fullpath=="" then return false end

	local content=file.Read(fullpath,"GAME")
	if content==0 then return false end
	return content
end

function TableToString(tbl)
	return string.Implode(" ",tbl)
end

function AutoComplete(commandName,args)

	local name = string.Explode(' ',args)

	name=name[#name] or ""

	local path = string.GetPathFromFilename(name)

	local files,folders=file.Find("lua/"..(name or "").."*","GAME")
	files=files or {}
	folders=folders or {}
	for k,v in pairs(folders) do
		table.insert(files,v)
	end
	local candidates=files
	candidates=candidates or {}
	for i,_ in pairs(candidates) do
		candidates[i]=commandName.." "..path..candidates[i]
	end

	return candidates

end	

function AddCMD(str,func,complete)
	if SERVER then
		concommand.Add('lua_'..str,function(pl,_,cmds,str)
			if IsValid(pl) and !pl:IsSuperAdmin() then return end
			func(cmds,str)
		end)
	else
		concommand.Add('lua_'..str,function(_,_,cmds,str)
			func(cmds,str)
		end,(!complete and AutoComplete) or nil)
	end
end