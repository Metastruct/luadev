hook.Add("Think","luadev_cmdsinit",function()
hook.Remove("Think","luadev_cmdsinit")

local function add(cmd,callback)
	if aowl and aowl.AddCommand then
		aowl.AddCommand(cmd,function(ply,script,param_a,...)
			
			local a,b
			
			easylua.End() -- nesting not supported
			
			local ret,why = callback(ply,script,param_a,...)
			if not ret then 
				if why==false then
					a,b = false,why or aowl.TargetNotFound(param_a or "notarget") or "H"
				elseif isstring(why) then
					ply:ChatPrint("FAILED: "..tostring(why))
					a,b= false,tostring(why)
				end
			end
		
			easylua.Start(ply)
			return a,b
			
		end,cmd=="lm" and "players" or "developers")
	end
end

local function X(ply,i) return luadev.GetPlayerIdentifier(ply,'cmd:'..i) end

add("l", function(ply, line, target)
	if not line or line=="" then return false,"invalid script" end
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,"l") if not valid then return false,err end end
	return luadev.RunOnServer(line, X(ply,"l"), {ply=ply}) 
end)

add("ls", function(ply, line, target)
	if not line or line=="" then return false,"invalid script" end
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,"ls") if not valid then return false,err end end
	return luadev.RunOnShared(line, X(ply,"ls"), {ply=ply})
end)

add("lc", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,"lc") if not valid then return false,err end end
	return luadev.RunOnClients(line,  X(ply,"lc"), {ply=ply})
end)

add("lsc", function(ply, line, target)
	local ent = easylua.FindEntity(target)
	if ent:IsPlayer() then
		local script = string.sub(line, string.find(line, target, 1, true)+#target+1)
		if luadev.ValidScript then local valid,err = luadev.ValidScript(script,'lsc') if not valid then return false,err end end
		return luadev.RunOnClient(script,  ent,  X(ply,"lsc"), {ply=ply}) 
	else
		return false
	end
end)
local sv_allowcslua = GetConVar"sv_allowcslua"
add("lm", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,'lm') if not valid then return false,err end end
	
	if not ply:IsAdmin() and not sv_allowcslua:GetBool() then return false,"sv_allowcslua is 0" end
	
	luadev.RunOnClient(line, ply,X(ply,"lm"), {ply=ply})
	
end)

add("lb", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,'lb') if not valid then return false,err end end

	luadev.RunOnClient(line, ply, X(ply,"lb"), {ply=ply})
	return luadev.RunOnServer(line, X(ply,"lb"), {ply=ply}) 
end)

add("print", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript('x('..line..')','print') if not valid then return false,err end end

	return luadev.RunOnServer("print(" .. line .. ")",  X(ply,"print"), {ply=ply})
end)

add("table", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript('x('..line..')','table') if not valid then return false,err end end

	return luadev.RunOnServer("PrintTable(" .. line .. ")",  X(ply,"table"), {ply=ply}) 
end)

add("keys", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript('x('..line..')','keys') if not valid then return false,err end end

	return luadev.RunOnServer("for k, v in pairs(" .. line .. ") do print(k) end",  X(ply,"keys"), {ply=ply})
end)

add("printc", function(ply, line, target)
	if not line or line=="" then return end
	line = "easylua.PrintOnServer(" .. line .. ")"
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,'printc') if not valid then return false,err end end

	return luadev.RunOnClients(line,  X(ply,"printc"), {ply=ply})
end)

add("printm", function(ply, line, target)
	if not line or line=="" then return end
	line = "easylua.PrintOnServer(" .. line .. ")"
	if luadev.ValidScript then local valid,err = luadev.ValidScript(line,'printm') if not valid then return false,err end end
	
	luadev.RunOnClient(line,  ply,  X(ply,"printm"), {ply=ply})
end)

add("printb", function(ply, line, target)
	if not line or line=="" then return end
	if luadev.ValidScript then local valid,err = luadev.ValidScript('x('..line..')','printb') if not valid then return false,err end end

	luadev.RunOnClient("easylua.PrintOnServer(" .. line .. ")",  ply, X(ply,"printb"), {ply=ply})
	return luadev.RunOnServer("print(" .. line .. ")",  X(ply,"printb"), {ply=ply})
end)

end)