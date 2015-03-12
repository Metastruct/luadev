module("luadev",package.seeall)
Tag=_NAME..'tag'

if SERVER then
	util.AddNetworkString(Tag)
end


-- Enums

	local enums={
		TO_CLIENTS=1,
		TO_CLIENT=2,
		TO_SERVER=3,
		TO_SHARED=4,
	}

	local revenums={} -- lookup
	_M.revenums=revenums

	for k,v in pairs(enums) do
		_M[k]=v
		revenums[v]=k
	end

	STAGE_PREPROCESS=1
	STAGE_COMPILED=2
	STAGE_POST=3
	STAGE_PREPROCESSING=4
	
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
		return script and not script:find("\n",1,true)
	end
	
	function GiveFileContent(fullpath,searchpath)
		--Print("Reading: "..tostring(fullpath))
		if fullpath==nil or fullpath=="" then return false end

		local content=file.Read(fullpath,searchpath or "MOD")
		if content==0 then return false end
		return content
	end

	function TableToString(tbl)
		return string.Implode(" ",tbl)
	end

	function Print(...)
		Msg("[Luadev"..(SERVER and ' Server' or '').."] ")
		print(...)
	end
	
	if CLIENT then
		luadev_verbose = CreateClientConVar( "luadev_verbose", "1",true)
	else
		luadev_verbose = CreateConVar( "luadev_verbose", "1", { FCVAR_NOTIFY ,FCVAR_ARCHIVE} )
	end
	function Verbose(lev)
		return (luadev_verbose:GetInt() or 99)>=(lev or 1)
	end

	function PrintX(script,...)
		local oneline = IsOneLiner(script) and 2
		local verb = Verbose(oneline)
		local Msg=not verb and _Msg or Msg
		local print=not verb and _print or print	
		Msg("[Luadev"..(SERVER and ' Server' or '').."] ")
		print(...)
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
		return IsValid(cl) and cl or nil
	end

-- compression

	function Compress( data )
		return util.Compress( data )
	end

	function Decompress(data)
		return util.Decompress( data )
	end

	function WriteCompressed(data)
		if #data==0 then
			net.WriteUInt( 0, 24 )
			return false
		end
		
		local compressed = Compress( data )
		local len = compressed:len()
		net.WriteUInt( len, 24 )
		net.WriteData( compressed, len )
		return compressed
	end

	function ReadCompressed()
		local len = net.ReadUInt( 24 )
		if len==0 then return "" end
		
		return Decompress( net.ReadData( len ) )
	end

-- Compiler / runner
local function ValidCode(src,who)
	local ret = CompileString(src,who or "",false)
	if type(ret)=='string' then
		return nil,ret
	end
	return ret or true
end
_M.ValidScript=ValidCode
_M.ValidCode=ValidCode

function ProcessHook(stage,...)
	return hook.Run("LuaDevProcess",stage,...)
end
local LuaDevProcess=ProcessHook

local LUADEV_EXECUTE_STRING=RunStringEx
local LUADEV_EXECUTE_FUNCTION=xpcall
local LUADEV_COMPILE_STRING=CompileString
local mt= {
	__tostring=function(self) return self[1] end,
	
	__index={
		set=function(self,what) self[1]=what end,
		get=function(self,what) return self[1] end,
	},
	--__newindex=function(self,what) rawset(self,1,what) end,
}
local strobj=setmetatable({""},mt)

function Run(script,info,extra)
	--compat
	if CLIENT and not extra and info and istable(info) then
		return luadev.RunOnSelf(script,"COMPAT",{ply=info.ply})
	end
	
	info = info or "??ANONYMOUS??"
	if not isstring(info) then
		debug.Trace()
		ErrorNoHalt("LuaDev Warning: info type mismatch: "..type(info)..': '..tostring(info))
	end
	
	-- STAGE_PREPROCESS
	local ret,newinfo = LuaDevProcess(STAGE_PREPROCESS,script,info,extra,nil)
	
		if ret == false then return end
		if ret ~=nil and ret~=true then script = ret end
	
		if newinfo then info = newinfo end
	
	-- STAGE_PREPROCESSING
	rawset(strobj,1,script)
		LuaDevProcess(STAGE_PREPROCESSING,strobj,info,extra,nil)
	script = rawget(strobj,1)
	
	if not script then
		return false,"no script"
	end
	
	-- Compiling
	
	local func = LUADEV_COMPILE_STRING(script,tostring(info),false)
	if not func or isstring( func )  then  compileerr = func or true  func = false end
	
	local ret = LuaDevProcess(STAGE_COMPILED,script,info,extra,func)
		-- replace function
		if ret == false then return end
		if ret ~=nil and isfunction(ret) then
			func = ret
			compileerr = false
		end

	if not func then
		if compileerr then
			return false,"Syntax error: "..tostring(compileerr)
		end
	end
	
	lastextra = extra
	lastinfo = info
	lastscript = script
	lastfunc = func
		
	local args = extra and extra.args and (istable(extra.args) and extra.args or {extra.args})
	if not args then args=nil end

	
	-- Run the stuff
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
	
	-- STAGE_POST
	LuaDevProcess(STAGE_POST,script,info,extra,func,args,ok,returnvals)
	
	if not ok then
		return false,errormessage
	end
	
	return ok,returnvals
end


function RealFilePath(name)
	local searchpath = "MOD"
	
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

	local searchpath = "MOD"
	
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
	
	local files,folders=file.Find(searchstr,searchpath or "MOD")
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

local sv_allowcslua = GetConVar 'sv_allowcslua'

function CanLuaDev(ply,script,command,target,target_ply,extra)
	local ret,x = hook.Run("CanLuaDev",ply,script,command,target,target_ply,extra)
	if ret~=nil then return ret,x end
	local ret,x = hook.Run("LuaDevIsPlayerAllowed", ply, script or "")
	if ret~=nil then return ret,x end
	if ply:IsSuperAdmin() then return true end
	if target == TO_CLIENT and
		(target_ply == ply
		or (target_ply
			and istable(target_ply)
			and target_ply[1]==ply
			and table.Count(target_ply)==1))
	then
		if sv_allowcslua:GetBool() then return true end
	end
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