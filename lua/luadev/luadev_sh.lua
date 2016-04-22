module("luadev",package.seeall)
Tag=_NAME..'1'

--net_retdata = Tag..'_retdata'

if SERVER then
	util.AddNetworkString(Tag)
	--util.AddNetworkString(net_retdata)
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
	
-- Figure out what to put to extra table
	function MakeExtras(pl,extrat)
		if pl and isentity(pl) and pl:IsPlayer() then
			extrat = extrat or {}
			extrat.ply = pl
		end
		return extrat
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
		luadev_store = CreateClientConVar( "luadev_store", "1",true)
		function ShouldStore()
			return luadev_store:GetBool()
		end
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
	
	specials = {
		swep = {
			function(val,extra,script,info)
				local SWEP=weapons.GetStored(val)
				if not SWEP then
					SWEP = {Primary={}, Secondary={},Base = "weapon_base",ClassName = val, Folder = 'weapons/'..val }
				end
				_G.SWEP = SWEP
			end,
			function(val,extra,script,info)
				local tbl = _G.SWEP
				_G.SWEP = nil
				if istable(tbl) then
					--local table_ForEach=table.ForEach table.ForEach=function()end timer.Simple(0,function() table.ForEach=table_ForEach end)
						if Verbose() then
							Print("Registering weapon "..tostring(val))
						end
						weapons.Register(tbl, val, true)
					--table.ForEach=table_ForEach
				end
			end,
		},
		sent = {
			function(val,extra,script,info)
				local ENT=scripted_ents.GetStored(val)
				if ENT and ENT.t then
					ENT=ENT.t
				else
					ENT = {ClassName=val , Folder = 'entities/'..val}
				end
				_G.ENT = ENT
			end,
			function(val,extra,script,info)
				local tbl = _G.ENT
				_G.ENT = nil
				if istable(tbl) then
				
					tbl.Model = tbl.Model or Model("models/props_borealis/bluebarrel001.mdl")
					if not tbl.Base then
						tbl.Base = "base_anim"
						tbl.Type = tbl.Type or "anim"
					end
					if Verbose() then
						Print("Registering entity "..tostring(val))
					end	
					scripted_ents.Register(tbl, val)
				end
			end,
		},
		stool = {
			function(val,extra,script,info)
				local gmod_tool=weapons.GetStored("gmod_tool")
				if gmod_tool and gmod_tool.Tool and gmod_tool.Tool[val] then
					TOOL=gmod_tool.Tool[val]
					assert(TOOL and TOOL.Mode == val)
				else
					
					assert(ToolObj,"Need ToolObj from gamemode to create new tools")
					
					TOOL = ToolObj:Create(toolmode)
					TOOL.Mode = toolmode
					
				end
				
				_G.TOOL = TOOL
			end,
			function(val,extra,script,info)
				local tbl = _G.TOOL
				_G.TOOL = nil
				if not istable(tbl) then return end
				
				Print("Registering tool "..tostring(val))
				
				if tbl.CreateConVars then 
					tbl:CreateConVars()
				end
				
				local gmod_tool=weapons.GetStored("gmod_tool")
				if TOOL and gmod_tool and gmod_tool.Tool then
					gmod_tool.Tool[val] = TOOL
				end
				
				
			end,
		},		
		-- TODO --
		effect = {
			function(val,extra,script,info)
				if SERVER then return end
				_G.EFFECT = {ClassName=val,Folder = 'effects/'..val }
			end,
			function(val,extra,script,info)
				if Verbose() then
					Print("Registering effect "..tostring(val))
				end
				if CLIENT then
					local tbl = _G.EFFECT _G.EFFECT = nil
					if tbl then
						effects.Register(_G.EFFECT,val)
					end
				end
			end,
		},
	}
	local specials = specials
	
	
	function ProcessSpecial(mode,script,info,extra)
		
		if not extra then return end
		for special_type,funcs in next,specials do
			local val = extra[special_type]
			if val then
				if Verbose(10) then
					Print("ProcessSpecial",mode,special_type," -> ",val)
				end
				local func = funcs[mode]
				if func then return func(val,extra,script,info) end
				return
			end
		end
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
	

-- Watch system

	function FileTime(fullpath,searchpath)
		--Print("Reading: "..tostring(fullpath))
		if fullpath==nil or fullpath=="" then return false end

		local t=file.Time(fullpath,searchpath or "MOD")
		
		if not t or t==0 then return false end
		
		return t
	end

	local watchlist = rawget(_M,"GetWatchList") and GetWatchList() or {} function GetWatchList() return watchlist end
	local i=0
	hook.Add("Think",Tag.."_watchlist",function()
		if not watchlist[1] then return end
		
		i=i+1
		local entry = watchlist[i]
		if not entry then
			i=0
			entry = watchlist[1]
			if not entry then return end
		end
		
		local newtime = FileTime(entry.path,entry.searchpath)
		local oldtime = entry.time
		if newtime and newtime~=oldtime then
			
			entry.time = newtime
			
			Msg"[LuaDev] Refresh " print(unpack(entry.cmd))
			
			RunConsoleCommand(unpack(entry.cmd))
			
		end
		
	end)
	
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
		local ret = LuaDevProcess(STAGE_PREPROCESSING,strobj,info,extra,nil)
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
	
	ProcessSpecial(1,script,info,extra)
	
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
	local ret = LuaDevProcess(STAGE_POST,script,info,extra,func,args,ok,returnvals)
	ProcessSpecial(2,script,info,extra)
	
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