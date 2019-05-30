local frame = {}
local dtree = {}
local readFile = ""
local rData = {}

local function showSettings( data, len )
	dtree:Clear()

	readFile = util.Decompress( data, len )

	if readFile and readFile ~= "" then
		rData = util.JSONToTable( readFile )
		if istable( rData ) then
			for k, v in next, rData do
				local node = dtree:AddNode( k )

				node.key = k
				node.value = v

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
							TextEntry.OnEnter = function( self )
								local entry = rData[ node.key ].data.settings
								entry = entry[ option.key ]

								if option.type == "table" then
									local new = {}
									self:GetValue():gsub('[0-9]+', function(n)
										table.insert( new, n )
									end)
									entry = new
								else
									self:GetValue():gsub('[0-9]+', function(n)
										entry = n
									end)
								end

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
end


local function init()
	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "PUG Settings ~" )
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
		if readFile then
			if istable(rData) and next( rData ) then
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
	end
end

hook.Add("InitPostEntity", "PUG.reee", init)

net.Receive("pug.menu", function()
	if not frame:IsVisible() then
		frame:Show()
		frame:MakePopup()
		dtree:Clear()
	end
end)

net.Receive("pug.send", function( len )
	showSettings( net.ReadData( len ), len )
end)