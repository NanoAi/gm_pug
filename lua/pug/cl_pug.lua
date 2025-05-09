local type = type
local istable = istable
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local lang = include("pug/client/language.lua")

local frame = {}
local dtree = {}
local readFile = ""
local rData = {}

local typeBuilder = {
	_i = {
		TextEntry = false,
	}
}

local function netRequestSettings()
	net.Start("pug.send")
	net.SendToServer()
end

local function setDataValue(node, path, value)
	local keys = {}
	for key in string.gmatch(path, "([^/]+)") do
		table.insert(keys, key)
	end

	if #keys == 0 then
		keys[1] = path
	end
	
	local c = #keys 
	local v = rData[ node.key ].data.settings[ keys[1] ]

	if c > 1 and istable(v) then
		if c == 3 then
			v[keys[2]][keys[3]].v = value
		elseif c == 2 then
			v[keys[2]].v = value
		end
		rData[ node.key ].data.settings[ keys[1] ] = v
	else
		v = value
	end

	rData[ node.key ].data.settings[ keys[1] ] = v
end

local function getDataValue(node, path)
	local keys = {}
	for key in string.gmatch(path, "([^/]+)") do
		table.insert(keys, key)
	end

	if #keys == 0 then
		keys[1] = path
	end
	
	local c = #keys 
	local v = rData[ node.key ].data.settings[ keys[1] ]

	if c > 1 and istable(v) then
		if c == 3 then
			return v[keys[2]][keys[3]].v
		elseif c == 2 then
			return v[keys[2]].v
		end
		rData[ node.key ].data.settings[ keys[1] ] = v
	else
		return v
	end
end

typeBuilder = {
	["boolean"] = function(node, option)
		if option.value then
			option.Icon:SetImage( "icon16/accept.png" )
		else
			option.Icon:SetImage( "icon16/delete.png" )
		end

		function option:DoClick()
			local enabled = getDataValue(node, self.path)
			enabled = ( not enabled )

			if enabled then
				self.Icon:SetImage( "icon16/accept.png" )
			else
				self.Icon:SetImage( "icon16/delete.png" )
			end

			setDataValue(node, self.path, enabled)
		end
		return true
	end,
	["folder"] = function(node, option)
		option.Icon:SetImage("icon16/folder.png")
		return true
	end,
	["textfield"] = {
		[0] = function(node, option)
			option.Icon:SetImage( "icon16/textfield_rename.png" )

			if type( option.value ) == "table" then
				option.value = table.concat( option.value, ", " )
			end

			local TextEntry = vgui.Create( "DTextEntry", option )
			TextEntry:Dock( RIGHT )
			TextEntry:SetText( tostring( option.value ) )
			TextEntry:SetWide( 100 )

			function TextEntry:OnChange()
				option.Icon:SetImage( "icon16/textfield_rename.png" )
			end
			
			function TextEntry:SaveEntry(entry)
				option.Icon:SetImage( "icon16/disk.png" )
				setDataValue(node, option.path, entry)
			end

			typeBuilder._TextEntry = TextEntry

			local entry = getDataValue(node, option.path)
			typeBuilder["textfield"][option.type](entry)
		end,
		["table"] = function(entry)
			local i = typeBuilder._TextEntry
			function i:OnEnter()
				local new = {}
				self:GetValue():gsub('[0-9]+', function(n)
					table.insert( new, tonumber( n ) )
				end)
				entry = new
				self:SaveEntry(entry)
			end
		end,
		["number"] = function(entry)
			local i = typeBuilder._TextEntry
			function i:OnEnter()
				self:GetValue():gsub('[0-9]+', function(n)
					entry = tonumber( n )
				end)
				self:SaveEntry(entry)
			end
		end,
		["string"] = function(entry)
			function i:OnEnter()
				entry = self:GetValue()
				self:SaveEntry(entry)
			end
		end,
	},
}

setmetatable(typeBuilder, {
	__index = function(data, key)
		return (function() return false end)
	end,
})

local function setOptionData(option, path, value)
	option.path = path
	option.value = value
	option.type = type( value )
	return option
end

local function addNodeOption(node, option)
	if option ~= nil then
		if not typeBuilder[option.type](node, option) then
			typeBuilder["textfield"][0](node, option)
		end
	else
		ErrorNoHaltWithStack("Attempt to index local 'option' (a nil value).")
	end
end

local function showSettings( data, len )
	dtree:Clear()

	readFile = util.Decompress( data, len )

	if readFile and readFile ~= "" then
		rData = util.JSONToTable( readFile )

		-- If `rData` is not a table do not continue.
		if not istable( rData ) then return end

		for k, v in next, rData do
			local node = dtree:AddNode( k )

			node.key = k
			node.value = v

			function node:DoClick()
				print("Right click to toggle.")
			end

			function node:DoRightClick()
				local enabled = rData[ self.key ].enabled
				enabled = ( not enabled )

				if enabled then
					self.Icon:SetImage( "icon16/accept.png" )
				else
					self.Icon:SetImage( "icon16/delete.png" )
				end

				rData[ self.key ].enabled = enabled
			end

			if v.enabled then
				node.Icon:SetImage( "icon16/accept.png" )
			else
				node.Icon:SetImage( "icon16/delete.png" )
			end

			if v.data and istable( v.data.settings ) then
				local mem = {}
				local folders = {}

				for kk, vv in next, v.data.settings do
					local option = nil

					if istable(vv) and vv[0] == "folder" then
						local folder = kk

						option = node:AddNode(folder)
						option:DockPadding( 0, 0, 10, 0 )
						option.type = vv[0]
						option.isFolderLike = true
						folders[folder] = {[0] = option}
						vv[0] = nil

						for opt, data in next, vv do
							local path = string.format("%s/%s", folder, opt)
							if data.inherit then
								typeBuilder["boolean"](node, folders[folder][0])
								setOptionData(folders[folder][0], path, data.v)
							else
								local folderNode = folders[folder][opt]
								folderNode = folders[folder][0]:AddNode(opt)
								folderNode = setOptionData(folderNode, path, data.v)
								option = folderNode
								addNodeOption(node, option)
							end
						end
					else
						option = node:AddNode( kk )
						option:DockPadding( 0, 0, 10, 0 )
						option = setOptionData(option, kk, vv)
						addNodeOption(node, option)
					end
					-- END
				end
			end
		end
	end
end


local function init()
	rData = {}

	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "[PUG][SETTINGS] ~ 0a05cc1" )
	frame:SetSize( 800, 500 )
	frame:Center()
	frame:Hide()

	frame:SetDeleteOnClose( false )

	local dBackground = vgui.Create("DImage", frame)
	dBackground:SetPos(0, 25)
	dBackground:SetSize(1024, 1024)
	dBackground:SetImage("materials/pug/scanlines.png")

	dtree = vgui.Create( "DTree", frame )
	dtree:SetSize( 300, 500 )
	dtree:Dock( LEFT )

	local sendData = ""

	local request = vgui.Create( "DButton", frame )
	request:SetText( "Request Data" )
	request:Dock( BOTTOM )
	function request:DoClick()
		net.Start("pug.send")
		net.SendToServer()
	end

	local send = vgui.Create( "DButton", frame )
	send:SetText( "Send Data" )
	send:Dock( BOTTOM )

	function send:DoClick()
		if readFile and ( istable(rData) and next( rData ) ) then
			sendData = util.TableToJSON( rData )

			if sendData and sendData ~= "" then
				sendData = util.Compress( sendData )

				net.Start("pug.take")
				net.WriteData( sendData, #sendData )
				net.SendToServer()

				sendData = ""
			end
		end
	end

	local dImg = vgui.Create("DImage", frame)
	dImg:SetPos(544 + 30, 244 - 10)
	dImg:SetSize(256, 256)
	dImg:SetImage("materials/pug/x256.png")

	-- Send a request for data to the server.
	netRequestSettings()

	return frame
end

hook.Add("InitPostEntity", "PUG.reee", init)

net.Receive("pug.menu", function()
	if not frame.IsVisible then
		frame = init()
		ErrorNoHaltWithStack('Frame Not Found Recreating.')
	end
	if not frame:IsVisible() then
		frame:Show()
		frame:MakePopup()
		dtree:Clear()
		timer.Simple(0.3, function()
			netRequestSettings()
		end)
	end
end)

net.Receive("pug.send", function( len )
	showSettings( net.ReadData( len ), len )
end)

CreateConVar("pug_enabled", "1", FCVAR_ARCHIVE, lang.notificationToggle, 0, 1)

local notifyDelay = 0
net.Receive("pug.notify", function()
	if not GetConVar( "pug_enabled" ):GetBool() then
		return
	end

	if notifyDelay > CurTime() then
		return
	end

	local str, type, length = net.ReadString(), net.ReadInt(4), net.ReadInt(4)
	str = language.GetPhrase( str ) or str

	notification.AddLegacy( str, type, length )
	print( "NOTIFY: ", str )

	notifyDelay = CurTime() + (length * 0.45)
end)

concommand.Add("pug_reload_menu", init, nil, "Reload the menu for PUG.")
concommand.Add("pug_data_dump", function()
	print(rData)
	PrintTable(rData)
end, nil, "Dump the currently loaded data set for PUG.")
