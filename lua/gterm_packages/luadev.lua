-- GTerm tool package for LuaDev (github.com/Metastruct/luadev).
--
-- LuaDev lets a superadmin run Lua on the server and other clients from their own
-- client. On a dedicated server GTerm's server realm is unreachable, so this is the
-- only way the agent can execute server-side code. Every tool here requires that the
-- local player is a superadmin on the server; LuaDev enforces that, and a non-superadmin
-- call simply does nothing.
--
-- Results only come back for run_server, and asynchronously: the server runs the code,
-- captures its return value and prints, and LuaDev sends them back to this client, where
-- they appear in GTerm's console output a moment later. Raise the tool timeout to wait
-- for them. The other tools are fire-and-forget.

local function guard()
	if not istable(luadev) then return "LuaDev is not installed on this server." end
	if not LocalPlayer():IsSuperAdmin() then return "You are not a superadmin here; LuaDev will ignore this." end
end

-- Server-side wrapper: runs the user code, captures its return value and prints, and
-- relays them to the calling client through LuaDev. steam64/nonce/code are embedded as
-- literals so no argument crosses the wire untrusted.
local function serverProgram(steam64, nonce, code)
	return ([==[
		local ply = player.GetBySteamID64(%q)
		if not IsValid(ply) then return end
		local out, realprint = {}, print
		local function cap(...)
			local t = {} for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
			out[#out + 1] = table.concat(t, "\t")
		end
		local f = CompileString(%q, "gterm_luadev", false)
		local ok, ret
		if isstring(f) then ok, ret = false, "Syntax error: " .. f
		else
			print = cap
			ok, ret = pcall(f)
			print = realprint
		end
		local serialized = istable(ret) and util.TableToJSON(ret) or (ret == nil and "nil" or tostring(ret))
		local reply = util.TableToJSON({ nonce = %q, ok = ok, ret = serialized, out = out })
		luadev.RunOnClient("print('<<GTERM_LUADEV>>' .. " .. string.format("%%q", reply) .. ")", ply, "gterm_luadev")
	]==]):format(steam64, code, nonce)
end

return {
	description = "Run Lua on the server or other clients through LuaDev (superadmin only).",
	tools = {
		{
			name = "run_server",
			target = "server",
			description = "Runs Lua on the SERVER and returns its result. Use this to reach the server realm, which is otherwise unreachable on a dedicated server. The code's return value and any print() output are sent back and appear in the console output shortly after; raise timeout to wait. Superadmin only.",
			inputSchema = {
				type = "object",
				properties = { code = { type = "string", description = "Lua to run on the server. Return a value or table to get it back." } },
				required = { "code" },
			},
			run = function(args)
				local g = guard() if g then return g end
				local nonce = tostring(math.random(1, 1e9))
				luadev.RunOnServer(serverProgram(LocalPlayer():SteamID64(), nonce, tostring(args.code)), "gterm_luadev")
				return "dispatched to server (nonce " .. nonce .. "). The result prints in the console output shortly, tagged <<GTERM_LUADEV>>."
			end,
		},
		{
			name = "run_shared",
			target = "server + clients",
			description = "Runs Lua on the server AND every client at once (fire-and-forget, no result). High impact: this executes on everyone. Superadmin only.",
			inputSchema = { type = "object", properties = { code = { type = "string" } }, required = { "code" } },
			run = function(args)
				local g = guard() if g then return g end
				luadev.RunOnShared(tostring(args.code), "gterm_luadev")
				return "dispatched to server and all clients (no result captured)."
			end,
		},
		{
			name = "run_clients",
			target = "clients",
			description = "Runs Lua on every client (fire-and-forget, no result). High impact: this executes on all players. Superadmin only.",
			inputSchema = { type = "object", properties = { code = { type = "string" } }, required = { "code" } },
			run = function(args)
				local g = guard() if g then return g end
				luadev.RunOnClients(tostring(args.code), "gterm_luadev")
				return "dispatched to all clients (no result captured)."
			end,
		},
	},
}
