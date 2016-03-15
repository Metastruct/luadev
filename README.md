# LuaDev
A simple library to help developers run lua code in-game.

###### Usage ######
 - ```lua_watch``` \<filename.lua\>
   - Run on self the file when its timestamp changes.
 - ```lua_send_sh``` \<filename.lua\>
   - Run on server and all clients.
 - ```lua_send_clients``` \<filename.lua\>
   - Run on a single client
 - ```lua_send_cl``` \<client\> \<filename.lua\>
   - Run on a single client
 - ```lua_send_sv``` \<filename.lua\>
   - Run on server
 - ```lua_send_self``` \<filename.lua\>
   - lua_openscript_cl through luadev
 - ```lua_run_client``` \<part of name/steamid/userid\> \<code\>
 - ```lua_run_clients``` \<code\>
 - ```lua_run_sh``` \<code\>
 - ```lua_run_sv``` \<code\>
 - ```lua_run_self``` \<code\>

Extra commands exist (lua_send_ent for direct entity code ending), unfinished.

###### Lua functions ######

(Desc is the string to identify errors)

 - ```luadev.RunOnServer```	(code,desc,extra)
 - ```luadev.RunOnShared```	(code,desc,extra)
 - ```luadev.Run```	(code,desc,extra)
 - ```luadev.RunOnClients```	(code,desc,extra)
 - ```luadev.RunOnClient```	(player,code,desc,extra)

Parameter ```extra``` is subject to change. It can essentially hold extra information to transfer with the code.

###### Notes ######
 - There is no player autocomplete yet
 - Embeds your steamid on errors. Does not prevent changing it though.
 - Only checks if you are superadmin. Be careful who you let to use this. There is a hook for luadev access check for override.
 - No GUI, use Sublime-LuaDev for example

###### Cvars ######
 - ```luadev_verbose``` 0-9
   - Console debug printing

###### Credits ######
 - CapsAdmin
 - Noiwex
 - Lixquid
 - Python1320
 - PotcFdk
 - Morten
 - Garry
 - Meta Construct


###### Extras ######
 - Sublime support
   - https://github.com/Noiwex/Sublime-LuaDev
 - Atom support
   - https://github.com/Lixquid/atom-gmod-luadev
 - GMod error console
   - https://github.com/Metastruct/EPOE
 - Easylua for code augmentation (outdated)
   - https://github.com/CapsAdmin/fast_addons/blob/master/lua/helpers/easylua.lua
