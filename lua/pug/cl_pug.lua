local istable = istable
local matCache = {
	screen = Material( "materials/pug/terminal.png", "noclamp smooth" ),
	upload = Material( "pug/icons/send_small.png", "smooth" ),
	download = Material( "pug/icons/request_small.png", "smooth" ),
	icon = Material( "materials/pug/x256.png", "smooth" ),
}

local lang = include("pug/client/language.lua")
local RNDX = include("pug/client/rndx.lua")
local PGM = include("pug/client/menu_struct.lua")
local l = PGM.l

local readFile = ""
local strEmpty = ""
local function funcEmpty() end

local frame = {}
local dtree = {}

local simData = {}
local frameData = {}

PGM.RNDX = RNDX

local function showSettings( data, len, decompress )
	dtree:Clear()

	if decompress then
		readFile = util.Decompress( data, len )
	end

	if not readFile or readFile == "" then
		notification.AddLegacy("Could not parse settings data.", NOTIFY_ERROR, 2)
		surface.PlaySound("npc/metropolice/pain1.wav")
		return
	end
	
	if decompress then
		PGM.rawData = util.JSONToTable( readFile )
	else
		PGM.rawData = data
	end

	if not istable( PGM.rawData ) then
		return
	end

	for k, v in next, PGM.rawData do
		local node = dtree:AddNode( k )

		node.key = k
		node.value = v

		function node:UpdateOption( enabled )
			if enabled == nil then
				enabled = PGM.rawData[ self.key ].enabled
			end
			if enabled then
				self.Icon:SetImage( "icon16/accept.png" )
			else
				self.Icon:SetImage( "icon16/delete.png" )
			end
			PGM.rawData[ self.key ].enabled = enabled
		end

		function node:DoClick()
			local enabled = PGM.rawData[ self.key ].enabled
			self:UpdateOption( not enabled )
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
	PGM.finalize()
end


local function init()
	PGM.rawData = {}

	frame = vgui.Create( "DFrame" )
	frame:SetTitle( "Physics \"UnGriefer\" Settings" )
	frame:SetSize( 800, 500 )
	frame:Center()
	frame:Hide()

	frame.isReady = false

	function frame:PerformLayout(w, h)
		self.flags = RNDX.SHAPE_IOS
		self.width = w
		self.height = h

		function self.btnClose:Paint(w, h)
			RNDX.DrawCircle(w/2, (h/2) + 3, h * 0.75, Color(186, 29, 60, 250))
		end

		if self.btnMaxim then
			self.btnMaxim:Remove()
			self.btnMinim:Remove()
		end
	end

	function frame:OnClose()
		net.Start("pug.menu.close")
		net.SendToServer()
	end

	function frame:Paint(w, h)
		-- RNDX.Draw(r, x, y, w, h, col, flags)
		local w, h = self:GetWide(), self:GetTall()
    RNDX.Draw(8, 0, 0, w, h, nil, self.flags + RNDX.BLUR)
    RNDX.Draw(8, 0, 0, w, h, Color(0, 0, 0, 150), self.flags)
	end

	local p = vgui.Create( "DPanel", frame )
	p.key = 0

	function p:PerformLayout()
		p:SetPos(128, frame.height - 125)
		p:SetSize(175, 70)
	end

	function p:Paint(w, h)
		p.key = (p.key % 175) + 1
		local len = #simData
		local o = h - 10

		frameData[p.key] = math.min(math.floor(engine.ServerFrameTime() * 1000), o)
		RNDX.Draw(8, 0, 0, w, h, Color(43, 38, 38, 150), frame.flags)

		if simData and len > 1 then
			for i = 1, len - 1 do
				local n = i + 1
				if frameData and frameData[n] then
					surface.SetDrawColor( 0, 255, 255, 255 )
					surface.DrawLine(i - 1, o - frameData[i], i, o - frameData[n])
				end
				local yFrom = math.min((o - simData[i]), o)
				local yTo = math.min((o - simData[n]), o)
				surface.SetDrawColor( 255, 0, 0, 200 )
				surface.DrawLine(i - 1, yFrom, i, yTo)
			end
		end
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
	dtree._AddNode = dtree.AddNode

	dtree:SetSize( 300, 500 )
	dtree:Dock( LEFT )
	dtree:DockMargin( 0, 0, 0, 75 )
	function dtree:Paint(w, h)
		RNDX.Draw(8, 0, 0, w, h, Color(255, 255, 255, 100))
	end

	function dtree:AddNode(name, icon)
		local node = self:_AddNode(name, icon)
		if node.Label then
			node.Label:SetTextColor( Color(255, 255, 255, 255) )
			node._AddNode = node.AddNode
			node.AddNode = self.AddNode
			node:SetPaintBackgroundEnabled( true )
			function node:Paint(w, h)
				surface.SetDrawColor(Color(0, 0, 0, 120))
				surface.DrawRect(0, 0, w, h)
			end
		end
		return node
	end


	local cmdr = vgui.Create( "DTextEntry", cmd )
	cmdr:Dock( FILL )
	cmdr:DockMargin( 120, 5, 0, 0 )
	cmdr:RequestFocus()

	function cmdr:Paint(w, h)
		RNDX.Draw(8, 0, 0, w - 5, h, Color(50, 50, 50, 150), frame.flags)
		self:DrawTextEntryText(Color(255, 255, 255), Color(186, 29, 60), Color(255, 255, 255))
	end

	function cmdr:PerformLayout()
		self:SetFontInternal("Trebuchet18")
	end

	function cmdr:SetCommand( str )
		self:SetText(str)
		self:OnValueChange(str)
		self:SetCaretPos(#str)
	end

	local i = 0
	local pastCommands = {}

	function cmdr:CommandGo(out, sound, fail)
		if not fail then
			surface.PlaySound(sound or "HL1/fvox/bell.wav")
			frame.console:Push(out or "[ OK ]")
		else
			frame.console:Push("Unknown command.")
		end
		self:SetText(strEmpty)
		self:OnValueChange(strEmpty)
		self:RequestFocus()
	end

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
			local accept = false

			local _input = self:GetText()
			local args = string.Explode(" ", _input)
			frame.console:Push("] " .. _input)

			if not table.HasValue(pastCommands, string.Left(str, 1000)) then
				if #pastCommands <= 50 then
					table.insert(pastCommands, string.Left(str, 1000))
				else
					table.Empty(pastCommands)
				end
			end

			if string.lower(_input) == "send" then
				PGM.netSendSettings()
				self:CommandGo("Sending Data to Server...", nil, false)
				return true
			end

			if string.lower(_input) == "get" then
				PGM.netRequestSettings()
				self:CommandGo("Updating Data...", nil, false)
				return true
			end

			if _input == "clear" then
				self:CommandGo(nil, "npc/turret_floor/click1.wav", false)
				frame.console:SetText(strEmpty)
				return true
			end

			if args[1] == "clean" then
				-- pretend this does something.
				self:CommandGo(nil, nil, false)
				return true
			end

			self:CommandGo(nil, nil, true)
			return true
		end
	end
	frame.cmdr = cmdr

	local sendData = ""
	local buttonColours = {
		base = Color(60, 60, 60, 255),
		click = Color(80, 80, 80, 255),
		image = Color(255, 255, 255, 255),
		imageClick = Color(125, 125, 125, 255),
	}

	local noTopCorners = RNDX.NO_TL + RNDX.NO_TR
	local request = vgui.Create( "DButton", cmd )
	request:SetText( strEmpty )
	request:SetTooltip("Request Data")
	request:SetSize(75, 27)
	request:Dock( RIGHT )
	request:DockMargin( 0, 0, 5, 0 )

	PGM.setupButton(18.75, 9, 38, 38, request, matCache.download, buttonColours, frame.flags)

	function request:DoClick()
		self:Clicked()
		PGM.netRequestSettings()
	end

	local send = vgui.Create( "DButton", cmd )
	send:SetText( strEmpty )
	send:SetTooltip("Send Data")
	send:SetSize(75, 25)
	send:Dock( RIGHT )
	PGM.setupButton(18.75, 9, 38, 38, send, matCache.upload, buttonColours, frame.flags)

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

	local pugImg = vgui.Create("DButton", frame)
	pugImg:SetText( strEmpty )
	pugImg:SetPos(5, 500 - 128)
	pugImg:SetSize(128, 128)
	PGM.setupButton(0, 0, 127, 127, pugImg, matCache.icon, nil, nil, true, -3)
	function pugImg:DoClick()
		self:Clicked()
		surface.PlaySound("UI/buttonclick.wav")
	end
	-- pugImg:SetImage("materials/pug/x256.png")

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
		timer.Simple(0.1, function()
			if frame.cmdr then
				frame.cmdr:RequestFocus()
			end
			PGM.netRequestSettings()
		end)
	end
end)

net.Receive("pug.send", function( len )
	showSettings( net.ReadData( len ), len, true )
	if frame.cmdr then
		frame.cmdr:RequestFocus()
	end
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

do
	local k = 0
	net.Receive("pug.PhysicsPing", function( len )
		k = (k % 175) + 1
		simData[k] = net.ReadUInt(7)
	end)
end

concommand.Add("pug_reload_menu", init, nil, "Reload the menu for PUG.")
concommand.Add("pug_data_dump", function()
	print(PGM.rawData)
	if istable(PGM.rawData) then
		PrintTable(PGM.rawData)
	end
end, nil, "Dump the currently loaded data set for PUG.")
