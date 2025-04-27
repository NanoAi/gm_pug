local frame = {}
local dtree = {}
local readFile = ""
local rData = {}
local ErrorNoHaltWithStack = ErrorNoHaltWithStack

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
				for kk, vv in next, v.data.settings do
					local option = node:AddNode( kk )
					option:DockPadding( 0, 0, 10, 0 )

					option.key = kk
					option.value = vv
					option.type = type( vv )

					if option.type == "boolean" then
						if option.value then
							option.Icon:SetImage( "icon16/accept.png" )
						else
							option.Icon:SetImage( "icon16/delete.png" )
						end
					else
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

						function TextEntry:OnEnter()
							local entry = rData[ node.key ].data.settings
							entry = entry[ option.key ]

							if option.type == "table" then
								local new = {}
								self:GetValue():gsub('[0-9]+', function(n)
									table.insert( new, tonumber( n ) )
								end)
								entry = new
							end

							if option.type == "number" then
								self:GetValue():gsub('[0-9]+', function(n)
									entry = tonumber( n )
								end)
							end

							if option.type == "string" then
								entry = self:GetValue()
							end

							option.Icon:SetImage( "icon16/disk.png" )
							rData[ node.key ].data.settings[ option.key ] = entry
						end
					end

					function option:DoClick()
						if self.type == "boolean" then
							local enabled = rData[ node.key ].data.settings
							enabled = ( not enabled[ self.key ] )

							if enabled then
								self.Icon:SetImage( "icon16/accept.png" )
							else
								self.Icon:SetImage( "icon16/delete.png" )
							end

							rData[ node.key ].data.settings[ self.key ] = enabled
						end
					end
				end
			end
		end
	end
end


local function init()
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "[PUG][SETTINGS] ~ 0a05cc1" )
	frame:SetSize( 300, 500 )
	frame:Center()
	frame:Hide()

	frame:SetDeleteOnClose( false )

	dtree = vgui.Create( "DTree", frame )
	dtree:Dock( FILL )

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
	end
end)

net.Receive("pug.send", function( len )
	showSettings( net.ReadData( len ), len )
end)

language.Add("pug_istrap", "The entity cannot be unghosted because there is something inside it")
language.Add("pug_doorghost", "Your fading door has been ghosted because something was obstructing it")
language.Add("pug_ghost", "Ghosted entities have limited interactability")
language.Add("pug_entfrozen", "Target entity frozen")
language.Add("pug_tool2fast", "You are using your tool gun too fast, slow down!")
language.Add("pug_spawn2fast", "You are spawning stuff too fast, slow down!")
language.Add("pug_toolworld", "You may not use the tool gun on the world")
language.Add("pug_lagdetected", "Lag detected, running cleanup function!")
language.Add("pug_lagpanic", "Heavy lag detected, running panic function!")
language.Add("pug_lagsettings", "Your average tickrate does not match your set tickrate, please review your settings!")

CreateConVar("pug_enabled", "1", FCVAR_ARCHIVE)

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

concommand.Add("pug_reload_menu", init)