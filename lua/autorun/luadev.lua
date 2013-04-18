module("luadev",package.seeall)

-- I think I finally understood why people make these seemingly silly files with just includes

include'luadev/luadev_sh.lua'
if SERVER then
	include'luadev/luadev_sv.lua'
end
include'luadev/luadev.lua'

if SERVER then
	AddCSLuaFile 'luadev/luadev_sh.lua'
	AddCSLuaFile 'luadev/luadev.lua'
end