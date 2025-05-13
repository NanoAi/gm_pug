local istable = istable
local matCache = {
	screen = Material( "materials/pug/terminal.png", "noclamp smooth" ),
	upload = Material( "pug/icons/send.png", "noclamp smooth" ),
	download = Material( "pug/icons/request.png", "noclamp smooth" ),
}

local lang = include("pug/client/language.lua")
local RNDX = include("pug/client/rndx.lua")
local PGM = include("pug/client/menu_struct.lua")
local l = PGM.l

local strEmpty = ""
local frame = {}
local dtree = {}
local readFile = ""

PGM.RNDX = RNDX

local function showSettings( data, len )
	dtree:Clear()

	readFile = util.Decompress( data, len )

	if readFile and readFile ~= "" then
		PGM.rawData = util.JSONToTable( readFile )
		if not istable( PGM.rawData ) then return end

		for k, v in next, PGM.rawData do
			local node = dtree:AddNode( k )

			node.key = k
			node.value = v

			function node:DoClick()
				local enabled = PGM.rawData[ self.key ].enabled
				enabled = ( not enabled )

				if enabled then
					self.Icon:SetImage( "icon16/accept.png" )
				else
					self.Icon:SetImage( "icon16/delete.png" )
				end

				PGM.rawData[ self.key ].enabled = enabled
			end

			function node:DoRightClick()
				local line = string.format("%s - %s", l(self.key), l(self.key, true))
				frame.console:Push(line)
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

						option = node:AddNode(l(folder))
						option:DockPadding( 0, 0, 10, 0 )
						option.type = vv[0]
						option.isFolderLike = true
						folders[folder] = {[0] = option}
						vv[0] = nil

						for opt, data in next, vv do
							local path = string.format("%s/%s", folder, opt)
							if data.inherit then
								PGM.typeBuilder["boolean"](node, folders[folder][0])
								PGM.setOptionData(folders[folder][0], path, data.v)
							else
								local folderNode = folders[folder][opt]
								folderNode = folders[folder][0]:AddNode(l(opt))
								folderNode = PGM.setOptionData(folderNode, path, data.v)
								option = folderNode
								PGM.addNodeOption(node, option)
							end
						end
					else
						option = node:AddNode( l(kk) )
						option:DockPadding( 0, 0, 10, 0 )
						option = PGM.setOptionData(option, kk, vv)
						PGM.addNodeOption(node, option)
					end
					-- END
				end
			end
		end
	end
end


local function init()
	PGM.rawData = {}

	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "[PUG][SETTINGS] ~ 0a05cc1" )
	frame:SetSize( 800, 500 )
	frame:Center()
	frame:Hide()

	function frame:Paint(w, h)		
		-- draw.RoundedBox( 8, 0, 0, self:GetWide(), self:GetTall(), Color( 0, 0, 0, 150 ) )
		-- RNDX.Draw(r, x, y, w, h, col, flags)

		self.flags = RNDX.SHAPE_IOS
		local w, h = self:GetWide(), self:GetTall()
    RNDX.Draw(8, 0, 0, w, h, nil, self.flags + RNDX.BLUR)
    RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 150), self.flags)

		surface.SetFont( "GModToolName" )
		surface.SetTextColor(227, 218, 201, 255)
		surface.SetTextPos( 128, h - 125 ) 
		surface.DrawText( "P.U.G" )

		frame.cmdr:RequestFocus()
	end

	frame:SetDeleteOnClose( false )

	local cmd = vgui.Create("DPanel", frame)
	cmd:SetPaintBackground( false )
	cmd:SetSize( 800, 50 )
	cmd:Dock( BOTTOM )

	local content = vgui.Create("DPanel", frame)
	content:SetSize( 490, 500 )
	content:Dock( RIGHT )
	content:SetPaintBackground(true)
	function content:Paint(w, h)
		surface.SetMaterial( matCache.screen )
		surface.SetDrawColor( Color(255, 255, 255, 150) )
		surface.DrawTexturedRect( 0, 0, w, h )
	end
	frame.content = content

	dtree = vgui.Create( "DTree", frame )
	dtree:SetSize( 300, 500 )
	dtree:Dock( LEFT )
	dtree:DockMargin( 0, 0, 0, 75 )

	local cmdr = vgui.Create( "DTextEntry", cmd )
	cmdr:Dock( FILL )
	cmdr:DockMargin( 120, 5, 0, 0 )
	cmdr:RequestFocus()

	function cmdr:SetCommand( str )
		self:SetText(str)
		self:OnValueChange(str)
		self:SetCaretPos(#str)
	end

	local i = 0
	local pastCommands = {}
	function cmdr:OnKeyCodeTyped( key )
		local str = self:GetValue()

		if key == KEY_BACKQUOTE then
			str = string.gsub(str, "`", strEmpty)
			timer.Simple(0, function()
				if self and self.SetCommand then
					self:SetCommand(str)
				end
			end)
			return true
		end

		if key == KEY_DOWN then
			i=i+1; if i > #pastCommands then i = 1 end
			if pastCommands[i] then
				self:SetCommand( pastCommands[i] )
			end
			return true
		elseif key == KEY_UP then
			i=i-1; if i > #pastCommands or i <= 0 then i = #pastCommands end
			if pastCommands[i] then
				self:SetCommand( pastCommands[i] )
			end
			return true
		elseif key == KEY_ENTER then
			if not table.HasValue(pastCommands, string.Left(str, 1000)) then
				if #pastCommands <= 50 then
					table.insert(pastCommands, string.Left(str, 1000))
				else
					table.Empty(pastCommands)
				end
			end

			if self:GetText() ~= "clear" then
				frame.console:Push("] " .. self:GetText())
				frame.console:Push("Unknown Command.")
			else
				frame.console:SetText(strEmpty)
			end

			self:SetText(strEmpty)
			self:OnValueChange(strEmpty)
			self:RequestFocus()

			return true
		end
	end
	frame.cmdr = cmdr

	local sendData = ""
	local buttonColours = {
		base = Color(55, 55, 55, 255),
		click = Color(70, 70, 70, 255),
		image = Color(255, 255, 255, 255),
		imageClick = Color(125, 125, 125, 255),
	}

	local request = vgui.Create( "DButton", cmd )
	request:SetText( strEmpty )
	request:SetTooltip("Request Data")
	request:SetSize(75, 25)
	request:Dock( RIGHT )
	request:DockMargin( 0, 0, 5, 0 )
	PGM.setupButton(request, matCache.download, buttonColours, frame.flags)

	function request:DoClick()
		self:Clicked()
		PGM.netRequestSettings()
	end

	local send = vgui.Create( "DButton", cmd )
	send:SetText( strEmpty )
	send:SetTooltip("Send Data")
	send:SetSize(75, 25)
	send:Dock( RIGHT )
	PGM.setupButton(send, matCache.upload, buttonColours, frame.flags)

	function send:DoClick()
		self:Clicked()
		PGM.netSendSettings()
	end

	local term = vgui.Create( "RichText", content )
	term.length = 0
	term.content = {}
	term:SetPaintBackgroundEnabled(false)
	term:Dock(FILL)
	term:InsertColorChange(255, 255, 255, 255)
	function term:Push( line, colour )
		line = line .. "\n"
		term.length = term.length + #line

		if colour then
			term:InsertColorChange(colour.r, colour.g, colour.b, colour.a)
		end

		term:AppendText(line)
		term:GotoTextEnd()
	end
	function term:PerformLayout()
		self:SetFontInternal("Trebuchet18")
	end
	frame.console = term

	local pugImg = vgui.Create("DImage", frame)
	pugImg:SetPos(5, 500 - 128)
	pugImg:SetSize(128, 128)
	pugImg:SetImage("materials/pug/x256.png")

	-- Send a request for data to the server.
	PGM.netRequestSettings()

	return frame
end

hook.Add("InitPostEntity", "PUG.reee", init)

net.Receive("pug.menu", function()
	if not frame.IsVisible then
		frame = init()
		print('[PUG:Warn] Frame Not Found Recreating.')
	end
	if not frame:IsVisible() then
		frame:Show()
		frame:MakePopup()
		dtree:Clear()
		timer.Simple(0.3, function()
			PGM.netRequestSettings()
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
	str = l( str ) or str

	notification.AddLegacy( str, type, length )
	print( "NOTIFY: ", str )

	notifyDelay = CurTime() + (length * 0.45)
end)

concommand.Add("pug_reload_menu", init, nil, "Reload the menu for PUG.")
concommand.Add("pug_data_dump", function()
	print(PGM.rawData)
	PrintTable(PGM.rawData)
end, nil, "Dump the currently loaded data set for PUG.")
