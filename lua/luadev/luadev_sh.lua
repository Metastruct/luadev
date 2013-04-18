module("luadev",package.seeall)
Tag=_NAME..'tag'

if SERVER then
	util.AddNetworkString(Tag)
end


-- Enums

	enums={
		TO_CLIENTS,
		TO_CLIENT,
		TO_SERVER,
		TO_SHARED,
	}
	revenums={} -- lookup

	for k,v in pairs(enums) do
		_M[k]=v
		revenums[v]=k
	end

	STAGE_PREPROCESS=1
	STAGE_COMPILED=2
	STAGE_POST=3
	
-- Figure out what to put to extra
	function MakeExtras(pl)
		if pl and isentity(pl) and pl:IsPlayer() then
			return {ply=pl}
		end
	end

-- Helpers 

	function TransmitHook(stage,...)
		return hook.Run("LuaDevTransmit",stage,...)
	end

	function IsOneLiner(script)
		return string.find(script,"\n")==nil
	end
	function GiveFileContent(fullpath,searchpath)
		--Print("Reading: "..tostring(fullpath))
		if fullpath==nil or fullpath=="" then return false end

		local content=file.Read(fullpath,searchpath or "GAME")
		if content==0 then return false end
		return content
	end

	function TableToString(tbl)
		return string.Implode(" ",tbl)
	end

	function Print(msg)
		Msg("[Luadev"..(SERVER and ' Server' or '').."] ")
		print(msg)
	end

	function FindPlayer(plyid)
		if not plyid or not isstring(plyid) then return end
		
		local cl
		for k,v in pairs(player.GetAll()) do
			if v:SteamID()==plyid or v:UniqueID()==plyid or tostring(v:UserID())==plyid then
				cl=v
				break
			end
		end
		if !cl then
			for k,v in pairs(player.GetAll()) do
				if v:Name():lower():find(plyid:lower(),1,true)==1 then
					cl=v
					break
				end
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
		if !cl then
			for k,v in pairs(player.GetAll()) do
				if v:Name():lower():find(plyid:lower(),1,true) then
					cl=v
					break
				end
			end
		end
		if !cl and easylua and easylua.FindEntity then
			cl = easylua.FindEntity(plyid)
		end
		return cl
	end

-- compression 

	function Compress( data )
		return util.Compress( data )
	end

	function Decompress(data)
		return util.Decompress( data )
	end

	function WriteCompressed(data)
		local compressed = Compress( data )
		net.WriteUInt( compressed:len(), 24 )		
		net.WriteData( compressed, compressed:len() )
	end

	function ReadCompressed()
		return Decompress( net.ReadData( net.ReadUInt( 24 ) ) )
	end

-- Compiler / runner


function ProcessHook(stage,...)
	return hook.Run("LuaDevProcess",stage,...)
end

local LUADEV_EXECUTE_STRING=RunStringEx
local LUADEV_EXECUTE_FUNCTION=xpcall
local LUADEV_COMPILE_STRING=CompileString
function Run(script,info,extra)
	info = info or "??ANONYMOUS??"
	if not isstring(info) then
		debug.Trace()
		ErrorNoHalt("LuaDev Warning: info type mismatch: "..type(info)..': '..tostring(info))
	end
	
	local ret,newinfo = ProcessHook(STAGE_PREPROCESS,script,info,extra,nil)
	
		-- replace script
		if ret == false then return end
		if ret ~=nil and ret~=true then script = ret end
	
	-- replace info
	if newinfo then info = newinfo end
	
	if not script then 
		return false,"no script"
	end
	
	local func = LUADEV_COMPILE_STRING(script,tostring(info))
	if not func then compileerr = true end
	
	local ret = ProcessHook(STAGE_COMPILED,script,info,extra,func)
		-- replace function
		if ret == false then return end
		if ret ~=nil and isfunction(ret) then 
			func = ret 
			compileerr = false
		end

	if not func then 
		if compileerr then
			return false,"Syntax error"
		end 
	end
	
	lastextra = extra
	lastinfo = info
	lastscript = script
	lastfunc = func
	
	local args = extra and extra.args and (istable(extra.args) and extra.args or {extra.args})
	if not args then args=nil end

	-- ugly global passing but we can't do it otherwise
	
	--[=[
	_G.LUADEV_COMPILED_FUNCTION = func
	_G.LUADEV_EXECUTED_OK = nil
	if args then
		args=istable(args) and args or {args}
		_G.LUADEV_ARGS = args
		local LUADEV_EXECUTOR = LUADEV_EXECUTE_STRING([[_G.LUADEV_RETURNS={_G.LUADEV_COMPILED_FUNCTION(unpack(_G.LUADEV_ARGS or {}))} 
														_G.LUADEV_EXECUTED_OK = true]],"LUADEV_EXECUTOR")
		_G.LUADEV_ARGS = nil
	else
		local LUADEV_EXECUTOR = LUADEV_EXECUTE_STRING([[_G.LUADEV_RETURNS={_G.LUADEV_COMPILED_FUNCTION()} 
														_G.LUADEV_EXECUTED_OK = true]],"LUADEV_EXECUTOR")
	end
	local ret = ProcessHook(STAGE_POST,script,info,extra,func,args,_G.LUADEV_EXECUTED_OK,_G.LUADEV_RETURNS)
	local executed = _G.LUADEV_EXECUTED_OK
	_G.LUADEV_EXECUTED_OK = nil
	_G.LUADEV_RETURNS = nil
	_G.LUADEV_COMPILED_FUNCTION = nil
	--]=]
	
	-- because garry's runstring has social engineer sexploits and such
	local errormessage
	local function LUADEV_TRACEBACK(errmsg)
		errormessage = errmsg
		local tracestr = debug.traceback(errmsg,2)
		
		-- Tidy up the damn long trace
		local p1=tracestr:find("LUADEV_EXECUTE_FUNCTION",1,true)
		if p1 then
			local p2=0
			while p2 and p2<p1 do
				local new=tracestr:find("\n",p2+1,true)
		
				if new>p1 then
					tracestr=tracestr:sub(1,new)
					break
				end
				p2=new
			end
		end
		
		ErrorNoHalt('[ERROR] '..tracestr   )--   ..'\n')
	end

	local LUADEV_EXECUTE_FUNCTION=xpcall
	local returnvals = {LUADEV_EXECUTE_FUNCTION(func,LUADEV_TRACEBACK,args and unpack(args) or nil)}
	local ok = returnvals[1] table.remove(returnvals,1)
	
	ProcessHook(STAGE_POST,script,info,extra,func,args,ok,returnvals)
	
	if not ok then
		return false,errormessage
	end
	
	return ok,returnvals
end


function RealFilePath(name)
	local searchpath = "GAME"
	
	local RelativePath='lua/'..name
	
	if name:find("^lua/") then -- search cache
		name=name:gsub("^lua/","")
		RelativePath=name
		searchpath = "LUA"
	elseif name:find("^%.%./") then -- whole shit
		name=name:gsub("^%.%./","")
		RelativePath=name
	elseif name:find("^data/") then -- whatever
		name=name:gsub("^data/","")
		RelativePath='data/'..name
	end
	
	if !file.Exists(RelativePath,searchpath) then return nil end
	return RelativePath,searchpath
end


function AutoComplete(cmd,commandName,args)

	local name = string.Explode(' ',args)

	name=name[#name] or ""

	local path = string.GetPathFromFilename(name)

	local searchpath = "GAME"
	
	local RelativePath='lua/'..(name or "")
	
	if name:find("^lua/") then -- search cache
		name=name:gsub("^lua/","")
		RelativePath=name
		searchpath = "LUA"
	elseif name:find("^%.%./") then -- whole shit
		name=name:gsub("^%.%./","")
		RelativePath=name
	elseif name:find("^data/") then -- whatever
		name=name:gsub("^data/","")
		RelativePath='data/'..name
	end
	
	local searchstr = RelativePath.."*"
	
	local files,folders=file.Find(searchstr,searchpath or "GAME")
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

--command = concommand, target=target enum
function CanLuaDev(ply,script,command,target,target_ply,extra)
	local ret,x = hook.Run("CanLuaDev",ply,script,command,target,target_ply,extra)
	if ret~=nil then return ret,x end
	local ret,x = hook.Run("LuaDevIsPlayerAllowed", ply, script or "")
	if ret~=nil then return ret,x end
	if ply:IsSuperAdmin() then return true end
end

function RejectCommand(pl,x)
	S2C(pl,"No Access"..(x and (": "..tostring(x)) or ""))
end

function COMMAND(str,func,complete)
	if SERVER then
		concommand.Add('lua_'..str,function(pl,command,cmds,strcmd)
			local id=pl
			if IsValid(pl) then
				local ok,err = CanLuaDev(pl,strcmd,command,nil,nil,nil)
				if not ok then
					return RejectCommand (pl,err or command)
				end
				id = GetPlayerIdentifier(pl,str) or pl
			else
				pl = "Console"
				id = pl
			end
			func(pl,cmds,strcmd,id)
		end)
	else
		concommand.Add('lua_'..str,function(_,_,cmds,strcmd)
			func(pl,cmds,strcmd,str)
		end,(!complete and function(...) return AutoComplete(str,...) end) or nil)
	end
end