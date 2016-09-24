easylua = {} local s = easylua

local function compare(a, b)

	if a == b then return true end
	if a:find(b, nil, true) then return true end
	if a:lower() == b:lower() then return true end
	if a:lower():find(b:lower(), nil, true) then return true end

	return false
end

local function comparenick(a, b)
	local MatchTransliteration = GLib and GLib.UTF8 and GLib.UTF8.MatchTransliteration
	if not MatchTransliteration then return compare (a, b) end
	
	if a == b then return true end
	if a:lower() == b:lower() then return true end
	if MatchTransliteration(a, b) then return true end

	return false
end

local function compareentity(ent, str)
	if ent.GetName and compare(ent:GetName(), str) then
		return true
	end

	if ent:GetModel() and compare(ent:GetModel(), str) then
		return true
	end

	return false
end

local TagPrintOnServer = "elpos"
if CLIENT then
	function easylua.PrintOnServer(...)
		local args = {...}
		local new = {}

		for key, value in pairs(args) do
			table.insert(new, luadata and luadata.ToString(value) or tostring(value))
		end
		net.Start(TagPrintOnServer)
			local str = table.concat(new," ")
			local max = 256
			net.WriteString(str:sub(1,max))
			net.WriteBool(#str>max)
		net.SendToServer()
	end
else
	util.AddNetworkString(TagPrintOnServer)
end

function easylua.Print(...)
	if CLIENT then
		easylua.PrintOnServer(...)
	end
	if SERVER then
		local args = {...}
		local str = ""

		Msg(string.format("[ELua %s] ", IsValid(me) and me:Nick() or "Sv"))

		for key, value in pairs(args) do
			str = str .. type(value) == "string" and value or luadata.ToString(value) or tostring(value)

			if key ~= #args then
				str = str .. ","
			end
		end

		print(str)
	end
end

if SERVER then
	--TODO: Antispam
	function easylua.CMDPrint(ply, cmd, args)
		args = table.concat(args, ", ")

		Msg(string.format("[ELua %s] ", IsValid(ply) and ply:Nick() or "Sv"))
		print(args)
	end
	concommand.Add("easylua_print", easylua.CMDPrint)
	
	net.Receive(TagPrintOnServer,function(len,ply)
		local str = net.ReadString()
		str=str:sub(1,512)
		local more = net.ReadBool()
		Msg(string.format("[ELua %s] ", IsValid(ply) and ply:Nick() or "Sv"))
		local outstr = ('%s%s'):format(str,more and "..." or ""):gsub("[\r\n]"," ")
		print(outstr)
	end)
end

function easylua.FindEntity(str)
	if not str then return NULL end

	str = tostring(str)

	if str == "#this" and IsEntity(this) and this:IsValid() then
		return this
	end

	if str == "#me" and IsEntity(me) and me:IsPlayer() then
		return me
	end

	if str == "#all" then
		return all
	end

	if str == "#us" then
		return us
	end
	
	if str == "#randply" then
		return table.Random(player.GetAll())
	end

	if str:sub(1,1) == "#" then
		local str = str:sub(2)

		if #str > 0 then
			str = str:lower()
			local found

			for teamid, data in pairs(team.GetAllTeams()) do
				if data.Name:lower() == str then
					found = teamid
					break
				end
			end
			if found then
				return CreateAllFunction(function(v) return v:IsPlayer() and v:Team() == found end)
			end


			for key, ent in pairs(ents.GetAll()) do
				if ent:GetClass():lower() == str then
					found = str
					break
				end
			end
			if found then
				return CreateAllFunction(function(v) return v:GetClass():lower() == found end)
			end
		end
	end

	-- unique id
	local ply = player.GetByUniqueID(str)
	if ply and ply:IsPlayer() then
		return ply
	end

	-- steam id
	if str:find("STEAM") then
		for key, _ply in pairs(player.GetAll()) do
			if _ply:SteamID() == str then
				return _ply
			end
		end
	end

	if str:sub(1,1) == "_" and tonumber(str:sub(2)) then
		str = str:sub(2)
	end

	if tonumber(str) then
		ply = Entity(tonumber(str))
		if ply:IsValid() then
			return ply
		end
	end

	-- community id
	if #str == 17 then

	end

	-- ip
	if SERVER then
		if str:find("%d+%.%d+%.%d+%.%d+") then
			for key, _ply in pairs(player.GetAll()) do
				if _ply:IPAddress():find(str) then
					return _ply
				end
			end
		end
	end
	-- search in sensible order
	
	-- search exact
	for _,ply in pairs(player.GetAll()) do
		if ply:Nick()==str then
			return ply
		end
	end
	
	-- Search bots so we target those first
	for key, ply in pairs(player.GetBots()) do
		if comparenick(ply:Nick(), str) then
			return ply
		end
	end
	
	-- search from beginning of nick
	for _,ply in pairs(player.GetHumans()) do
		if ply:Nick():lower():find(str,1,true)==1 then
			return ply
		end
	end
	
	-- Search normally and search with colorcode stripped
	for key, ply in pairs(player.GetAll()) do
		if comparenick(ply:Nick(), str) then
			return ply
		end
		if comparenick(ply:Nick():gsub("%^%d+", ""), str) then
			return ply
		end
	end

	for key, ent in pairs(ents.GetAll()) do
		if compareentity(ent, str) then
			return ent
		end
	end

	do -- class

		local _str, idx = str:match("(.-)(%d+)$")
		if idx then
			idx = tonumber(idx)
			str = _str
		else
			str = str
			idx = (me and me.easylua_iterator) or 0
		end

		local found = {}

		for key, ent in pairs(ents.GetAll()) do
			if compare(ent:GetClass(), str) then
				table.insert(found, ent)
			end
		end

		return found[math.Clamp(idx%#found, 1, #found)] or NULL
	end
end

function easylua.CreateEntity(class, callback)
	local mdl = "error.mdl"

	if IsEntity(class) and class:IsValid() then
		this = class
	elseif class:find(".mdl", nil, true) then
		mdl = class
		class = "prop_physics"

		this = ents.Create(class)
		this:SetModel(mdl)
	else
		this = ents.Create(class)
	end

	if callback and type(callback) == 'function' then
		callback(this);
	end

	this:Spawn()
	this:SetPos(there + Vector(0,0,this:BoundingRadius() * 2))
	this:DropToFloor()
	this:PhysWake()

	undo.Create(class)
		undo.SetPlayer(me)
		undo.AddEntity(this)
	undo.Finish()
	
	me:AddCleanup("props", this)
	
	return this
end

function easylua.CopyToClipboard(var, ply)
	ply = ply or me
	if luadata then
		local str = luadata.ToString(var)

		if not str and IsEntity(var) and var:IsValid() then
			if var:IsPlayer() then
				str = string.format("player.GetByUniqueID(--[[%s]] %q)", var:GetName(), var:UniqueID())
			else
				str = string.format("Entity(%i)", var:EntIndex())
			end

		end

		if CLIENT then
			SetClipboardText(str)
		end

		if SERVER then
			local str = string.format("SetClipboardText(%q)", str)
			if #str > 255 then
				if luadev and luadev.RunOnClient then
					luadev.RunOnClient(str, ply)
				else
					error("Text too long to send and luadev not found",1)
				end
			else
				ply:SendLua(str)
			end
		end
	end
end


local started = false
function easylua.Start(ply)
	if started then
		Msg"[ELua] "print("Session not ended for ",_G.me or (s.vars and s.vars.me),", restarting session for",ply)
		easylua.End()
	end
	started = true

	ply = ply or CLIENT and LocalPlayer() or nil

	if not ply or not IsValid(ply) then return end

	local vars = {}
		local trace = util.QuickTrace(ply:EyePos(), ply:GetAimVector() * 10000, {ply, ply:GetVehicle()})

		if trace.Entity:IsWorld() then
			trace.Entity = NULL
		end

		vars.me = ply
		vars.this = trace.Entity
		vars.wep = ply:GetActiveWeapon()
		vars.veh = ply:GetVehicle()

		vars.we = {}

		for k, v in pairs(ents.FindInSphere(ply:GetPos(), 512)) do
			if v:IsPlayer() then
				table.insert(vars.we, v)
			end
		end

		vars.there = trace.HitPos
		vars.here = trace.StartPos
		vars.dir = ply:GetAimVector()

		vars.trace = trace
		vars.length = trace.StartPos:Distance(trace.HitPos)

		vars.copy = s.CopyToClipboard
		vars.create = s.CreateEntity
		vars.prints = s.PrintOnServer

		if vars.this:IsValid() then
			vars.phys = vars.this:GetPhysicsObject()
			vars.model = vars.this:GetModel()
		end

		vars.E = s.FindEntity
		vars.last = ply.easylua_lastvars
		
		
		s.vars = vars
		local old_G={}
		s.oldvars=old_G
		
	for k,v in pairs(vars) do old_G[k]=_G[k] _G[k] = v end

	-- let this gc. maybe allow few more recursions.
	if vars.last and istable(vars.last) then vars.last.last = nil end
	
	ply.easylua_lastvars = vars
	ply.easylua_iterator = (ply.easylua_iterator or 0) + 1
end

function easylua.End()
	if not started then
		Msg"[ELua] "print"Ending session without starting"
	end
	started = false
	
	if s.vars then
		for key, value in pairs(s.vars) do
			if s.oldvars and s.oldvars[key] then
				_G[key] = s.oldvars[key]
			else
				_G[key] = nil
			end
		end
	end
end

do -- env meta
	local META = {}

	local _G = _G
	local easylua = easylua
	local tonumber = tonumber
	
	local nils={
		["CLIENT"]=true,
		["SERVER"]=true,
	}
	function META:__index(key)
		local var = _G[key]

		if var ~= nil then
			return var
		end

		if not nils [key] then -- uh oh
			var = easylua.FindEntity(key)
			if var:IsValid() then
				return var
			end
		end

		return nil
	end

	function META:__newindex(key, value)
		_G[key] = value
	end

	easylua.EnvMeta = setmetatable({}, META)
end

function easylua.RunLua(ply, code, env_name)
	local data =
	{
		error = false,
		args = {},
	}

	easylua.Start(ply)
		if s.vars then
			local header = ""

			for key, value in next,(s.vars or {}) do
				header = header .. string.format("local %s = %s ", key, key)
			end

			code = header .. "; " .. code
		end

		env_name = env_name or string.format("%s", tostring(
			IsValid(ply) and ply:IsPlayer()
				and	"["..ply:SteamID():gsub("STEAM_","").."]"..ply:Name()
				or ply))

		data.env_name = env_name

		local func = CompileString(code, env_name, false)

		if type(func) == "function" then
			setfenv(func, easylua.EnvMeta)

			local args = {pcall(func)}

			if args[1] == false then
				data.error = args[2]
			end

			table.remove(args, 1)
			data.args = args
		else
			data.error = func
		end
	easylua.End()

	return data
end

-- legacy luadev compatibility

local	STAGE_PREPROCESS=1
local	STAGE_COMPILED=2
local	STAGE_POST=3

local insession = false
hook.Add("LuaDevProcess","easylua",function(stage,script,info,extra,func)
	if stage==STAGE_PREPROCESS then
			
		if insession then
			insession=false
			easylua.End()
		end
		
		if not istable(extra) or not IsValid(extra.ply) or not script or extra.easylua==false then
			return
		end
			
		insession = true
		easylua.Start(extra.ply)
		
		local t={}
		for key, value in pairs(easylua.vars or {}) do
			t[#t+1]=key
		end
		if #t>0 then
			script=' local '..table.concat(t,", ")..' = '..table.concat(t,", ")..' ; '..script
		end
		
		--ErrorNoHalt(script)
		return script
				
	elseif stage==STAGE_COMPILED then
		
		if not istable(extra) or not IsValid(extra.ply) or not isfunction(func) or extra.easylua==false then
			if insession then
				insession=false
				easylua.End()
			end
			return
		end

		if insession then
			local env = getfenv(func)
			if not env or env==_G then
				setfenv(func, easylua.EnvMeta)
			end
		end
			
	elseif stage == STAGE_POST and insession then
		insession=false
		easylua.End()
	end
end)

function easylua.StartWeapon(classname)
	_G.SWEP = {
		Primary = {},
		Secondary = {},
		ViewModelFlip = false,
	}

	SWEP.Base = "weapon_base"

	SWEP.ClassName = classname
end

function easylua.EndWeapon(spawn, reinit)
	if not SWEP then error"missing SWEP" end
	if not SWEP.ClassName then error"missing classname" end
	
	weapons.Register(SWEP, SWEP.ClassName)

	for key, entity in pairs(ents.FindByClass(SWEP.ClassName)) do
		--if entity:GetTable() then table.Merge(entity:GetTable(), SWEP) end
		if reinit then
			entity:Initialize()
		end
	end

	if SERVER and spawn then
		SafeRemoveEntity(me:GetWeapon(SWEP.ClassName))
		local me = me
		local class = SWEP.ClassName
		timer.Simple(0.2, function() if me:IsPlayer() then me:Give(class) end end)
	end

	SWEP = nil
end

function easylua.StartEntity(classname)
	_G.ENT = {}

	ENT.ClassName = classname or "no_ent_name_" .. me:Nick() .. "_" .. me:UniqueID()
end

function easylua.EndEntity(spawn, reinit)
	
	ENT.Model = ENT.Model or Model("models/props_borealis/bluebarrel001.mdl")
	
	if not ENT.Base then -- there can be Base without Type but no Type without base without redefining every function so um
		ENT.Base = "base_anim"
		ENT.Type = ENT.Type or "anim"
	end
	
	scripted_ents.Register(ENT, ENT.ClassName)

	for key, entity in pairs(ents.FindByClass(ENT.ClassName)) do
		--table.Merge(entity:GetTable(), ENT)
		if reinit then
			entity:Initialize()
		end
	end

	if SERVER and spawn then
		create(ENT.ClassName)
	end

	ENT = nil
end

do -- all
	local META = {}

	function META:__index(key)
		return function(_, ...)
			local args = {}

			for _, ent in pairs(ents.GetAll()) do
				if (not self.func or self.func(ent)) then
					if type(ent[key]) == "function" or ent[key] == "table" and type(ent[key].__call) == "function" and getmetatable(ent[key]) then
						table.insert(args, {ent = ent, args = (ent[key](ent, ...))})
					else
						ErrorNoHalt("attempt to call field '" .. key .. "' on ".. tostring(ent) .." a " .. type(ent[key]) .. " value\n")
					end
				end
			end

			return args
		end
	end

	function META:__newindex(key, value)
		for _, ent in pairs(ents.GetAll()) do
			if not self.func or self.func(ent) then
				ent[key] = value
			end
		end
	end
	
	function CreateAllFunction(func)
		return setmetatable({func = func}, META)
	end

	all = CreateAllFunction(function(v) return v:IsPlayer() end)
	us = CreateAllFunction(function(v) return table.HasValue(we, v) end)
	props = CreateAllFunction(function(v) return v:GetClass() == "prop_physics" end)
	-- props = CreateAllFunction(function(v) return util.IsValidPhysicsObject(vm) end)
	bots = CreateAllFunction(function(v) return v:IsPlayer() and v:IsBot() end)
	these = CreateAllFunction(function(v) return table.HasValue(constraint.GetAllConstrainedEntities(this), v) end)
end
