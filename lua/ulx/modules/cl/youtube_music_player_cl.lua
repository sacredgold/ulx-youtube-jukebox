-- ULX YouTube Jukebox - Allows admins to play audio from YouTube videos on the server.
local PlayerSize = { x = 92, y = 19 }
local PlayerPos = { x = ( ScrW() / 2 ) - ( PlayerSize.x / 2 ), y = 2 }

local PlayerSizeActual = { x = 268, y = 268 }

local reloading
if ULXSongPlayerPanel != nil and type( ULXSongPlayerPanel ) == "Panel" then
	ULXSongPlayerPanel:Remove()
	reloading = true
end

if ULXSongPlayer != nil and type( ULXSongPlayer ) == "Panel" then
	ULXSongPlayer:Remove()
	reloading = true
end

local panel
local SongPlayer
local function songplayer_init( authed_ply )

	ULXSongPlayerPanel = vgui.Create( "DPanel" )
	panel = ULXSongPlayerPanel
	panel:SetPos( PlayerPos.x, PlayerPos.y )
	panel:SetSize( PlayerSize.x, PlayerSize.y )
	panel:SetVisible( false )

	ULXSongPlayer = vgui.Create( "HTML", panel )
	SongPlayer = ULXSongPlayer
	--SongPlayer:SetSize( 3 + 55 + 1 + PlayerSize.x + 1 + 28 + 1 + 1 + 30 + 1, PlayerSize.x + 8 )
	SongPlayer:SetSize( PlayerSizeActual.x, PlayerSizeActual.y ) -- Make it a little bigger than the panel, to cut off some buttons, and the seek bar.
	SongPlayer:SetPos( -3 - 55 - 1, -( PlayerSizeActual.y - 4 - PlayerSize.y ) ) -- Offset it a little to hide the pause/play button.
	SongPlayer:SetMouseInputEnabled( false )
	SongPlayer:SetVisible( false )

end
hook.Add( ULib.HOOK_LOCALPLAYERREADY, "ULXSongPlayerInit", songplayer_init )

if ( reloading ) then
	songplayer_init()
	reloading = false
end

local cvar_enabled = CreateConVar( "ulx_songplayer_enable", "1", FCVAR_ARCHIVE, "Enables/disables the ULX YouTube Jukebox client-side" )
local quality_help =
[[Sets the ULX YouTube Jukebox video quality client-side (if the quality isn't supported by the video, it will use the closest one available)
Possible values: 240p, 360p,  480p,  720p,  1080p]]
local cvar_quality = CreateConVar( "ulx_songplayer_quality", "480p", FCVAR_ARCHIVE, quality_help )
local cvar_volume = CreateConVar( "ulx_songplayer_volume", "50", FCVAR_ARCHIVE, "ULX YouTube Jukebox volume (client-side)" )

local function setPlayerVisible( b ) -- Helper function for setting the visibility of both the DPanel and the HTML conrol simultaneously
	panel:SetVisible( b )
	SongPlayer:SetVisible( b )
end

local function playerFade( fading_in, fade_time )

	if panel:IsVisible() and fading_in then return end -- The player is already visible, no need to fade in.
	if not panel:IsVisible() and not fading_in then return end -- The player is already hidden, no need to fade out.

	fade_time = fade_time or 1
	local start = CurTime()

	if fading_in then
		panel:SetAlpha( 0 )
		setPlayerVisible( true )
	end

	local function playerFadeHook()

		local alpha
		local ftime = CurTime() - start

		local cur_alpha = panel:GetAlpha()

		if ( fading_in and cur_alpha < 255 ) or ( not fading_in and cur_alpha > 0 ) then

			if fading_in then -- Fading in

				local alpha_mul = ftime / fade_time -- 0 to 1
				alpha = 255 * alpha_mul

			else -- Fading out

				local alpha_mul = ftime / fade_time -- 0 to 1
				local alpha_mul = 1 - alpha_mul -- Reverse, 1 to 0
				alpha = 255 * alpha_mul
			end

			if alpha > 255 then
				alpha = 255
			elseif alpha < 0 then
				alpha = 0
			end

			panel:SetAlpha( alpha )

		else -- Done fading

			if not fading_in then -- Was fading out
				setPlayerVisible( false )
				panel:SetAlpha( 255 )
			end
			hook.Remove( "Think", "YouTubePlayerFade" )

		end
	end

	hook.Add( "Think", "YouTubePlayerFade", playerFadeHook )
end

local function playerFadeIn( fade_time )
	playerFade( true, fade_time )
end
local function playerFadeOut( fade_time )
	playerFade( false, fade_time )
end

function ulx.play_vid_hook( um )

	if cvar_enabled:GetBool() == false then return end

	local video_id = um:ReadString()

	SongPlayer:SetHTML( "" )

	timer.Simple( 0.3, function()

		http.Get( "http://gdata.youtube.com/feeds/api/videos/" .. video_id .. "?v=2", "", function( contents )

			local video_length = ulx.getVideoLengthFromHTTPData( contents )

			if not video_length then
				print( "YouTube Jukebox: Error retrieving video length for player auto-hide. Type ulx stopvid to manually hide the player bar." )
				return
			end

			timer.Create( "ulx_hidevid", video_length + 3, 1, function()
				playerFadeOut()
			end )

		end )

		SongPlayer:OpenURL( "http://ryno-saurus.github.com/ulx_youtubemusicplayer/host.html?v=" .. video_id .. "&quality=" .. cvar_quality:GetString() .. "&volume=" .. cvar_volume:GetString() )

		timer.Simple( 0.5, playerFadeIn )

	end )

end
usermessage.Hook( "ulx_playvid", ulx.play_vid_hook )

function ulx.stop_vid_hook()
	SongPlayer:SetHTML( "" )

	timer.Simple( 0.3, function()

		timer.Simple( 0.5, playerFadeOut )

		if cvar_enabled:GetBool() == false then return end

		SongPlayer:OpenURL( "http://ryno-saurus.github.com/ulx_youtubemusicplayer/host.html?quality=" .. cvar_quality:GetString() .. "&volume=" .. cvar_volume:GetString() )

	end )

	timer.Destroy( "ulx_hidevid" )
end
usermessage.Hook( "ulx_stopvid", ulx.stop_vid_hook )

local SongCount
function ULXMusicPlayerRefresh()
	if not ULXSongPlayerFrame or not ULXSongPlayerFrame:IsVisible() then return end
	SongCount = 0
	ULXSongPlayerFrame:SetTitle( "YouTube Jukebox by RynO-SauruS *Refreshing*" )
	ULXSongPlayerList:Clear()
	RunConsoleCommand( "_ulx_songplayer", "retrievesongs" )
end

function ULXReceiveSong( um )

	local video_id = um:ReadString()
	local title = um:ReadString()
	local length = um:ReadLong()
	local length_minutes = math.floor( length / 60 )
	local length_seconds = length - ( 60 * length_minutes )
	if length_seconds < 10 then length_seconds = "0" .. length_seconds end

	ULXSongPlayerList:AddLine( title, video_id, length_minutes .. ":" .. length_seconds )

	SongCount = SongCount + 1

end
usermessage.Hook( "ULXTransferSong", ULXReceiveSong )

function ULXRecieveSongsDone()
	local CountString
	if SongCount == 1 then
		CountString = "(1 song)"
	else
		CountString = "(" .. SongCount .. " songs)"
	end
	ULXSongPlayerFrame:SetTitle( "YouTube Jukebox by RynO-SauruS " .. CountString )
	ULXSongPlayerList:SortByColumn( 1 )
end
usermessage.Hook( "ULXTransferSongsDone", ULXRecieveSongsDone )

local menu_open = false
function ULXOpenMusicPlayer()

	if ULXSongPlayerFrame && menu_open then
		ULXSongPlayerFrame:Close()
		menu_open = false
	end

	menu_open = true

	ULXSongPlayerFrame = vgui.Create( "DFrame" )
	local frame = ULXSongPlayerFrame
	frame:MakePopup()
	frame:SetTitle( "YouTube Jukebox by RynO-SauruS" )
	frame:ShowCloseButton( false )
	frame:SetDeleteOnClose( true )
	frame:SetKeyboardInputEnabled( false )
	frame:SetSizable( true )

	ULXSongPlayerList = vgui.Create( "DListView", frame )
	local list = ULXSongPlayerList
	list:SetMultiSelect( false )
	list:AddColumn( "Title" )
	list:AddColumn( "Video ID" ):SetFixedWidth( 0 ) -- No need to show this (makes more room for the title), if they want the video ID they can right click-> Copy URL to clipboard
	list:AddColumn( "Length" ):SetFixedWidth( 38 )
	list.DoDoubleClick = function( parent, index, line )
		if ULib.ucl.query( LocalPlayer(), "ulx playvid" ) then
			RunConsoleCommand( "_ulx_songplayer", "playvid", line:GetValue( 2 ) )
		else
			RunConsoleCommand( "_ulx_songplayer", "playvidcl", line:GetValue( 2 ) )
		end
	end
	list.OnRowRightClick = function( panel, line )
		local menu = vgui.Create( "DMenu" )
		menu:SetPos( gui.MousePos() )
		menu:AddOption( "Play for all", function()
			RunConsoleCommand( "_ulx_songplayer", "playvid", list:GetLine( line ):GetValue( 2 ) )
		end )
		menu:AddOption( "Play client-side", function()
			RunConsoleCommand( "_ulx_songplayer", "playvidcl", list:GetLine( line ):GetValue( 2 ) )
		end )
		menu:AddSpacer()
		menu:AddOption( "Copy URL to clipboard", function()
			SetClipboardText( "http://www.youtube.com/watch?v=" .. list:GetLine( line ):GetValue( 2 ) )
		end )
		menu:AddSpacer()
		menu:AddOption( "Remove", function()
			local confirmframe = vgui.Create( "DFrame", frame )
			confirmframe:SetTitle( "Confirm remove" )
			confirmframe:ShowCloseButton( false )
			confirmframe:SetDeleteOnClose( true )
			confirmframe:SetSize( 300, 22 + 100 )
			confirmframe:Center()
			confirmframe:MakePopup()
			confirmframe:SetKeyboardInputEnabled( false )

			local label = vgui.Create( "DLabel", confirmframe )
			label:SetPos( 10, 22 + 10 )
			label:SetWide( 280 )
			label:SetText( "Are you sure you want to remove this video?" )

			local applybutton = vgui.Create( "DButton", confirmframe )
			applybutton:SetPos( 10, 22 + 55 )
			applybutton:SetSize( 135, 35 )
			applybutton:SetText( "Remove" )
			applybutton.DoClick = function()
				RunConsoleCommand( "ulx", "removevid", "http://www.youtube.com/watch?v=" .. list:GetLine( line ):GetValue( 2 ) ) -- The server sends the refresh command back once it's removed.
				confirmframe:Close()
			end

			local cancelbutton = vgui.Create( "DButton", confirmframe )
			cancelbutton:SetPos( 155, 22 + 55 )
			cancelbutton:SetSize( 135, 35 )
			cancelbutton:SetText( "Cancel" )
			cancelbutton.DoClick = function() confirmframe:Close() end
		end )
		menu:AddOption( "Rename", function()
			local textframe = vgui.Create( "DFrame", frame )
			textframe:SetTitle( "Rename video" )
			textframe:ShowCloseButton( false )
			textframe:SetDeleteOnClose( true )
			textframe:SetSize( 300, 22 + 100 )
			textframe:Center()
			textframe:MakePopup()

			local textbox = vgui.Create( "DTextEntry", textframe )
			textbox:SetPos( 10, 22 + 10 )
			textbox:SetWide( 280 )
			textbox:SetText( list:GetLine( line ):GetValue( 1 ) )
			textbox:RequestFocus()

			local function renameVid()
				local new_title = textbox:GetValue():gsub( "\"", "<quote>" ) -- This is to fix quotation marks being replaced with ' by RunConsoleCommand.
				RunConsoleCommand( "ulx", "renamevid", "http://www.youtube.com/watch?v=" .. list:GetLine( line ):GetValue( 2 ), new_title )
				textframe:Close()
			end
			textbox.OnEnter = renameVid

			local applybutton = vgui.Create( "DButton", textframe )
			applybutton:SetPos( 10, 22 + 55 )
			applybutton:SetSize( 135, 35 )
			applybutton:SetText( "Apply" )
			applybutton.DoClick = renameVid

			local cancelbutton = vgui.Create( "DButton", textframe )
			cancelbutton:SetPos( 155, 22 + 55 )
			cancelbutton:SetSize( 135, 35 )
			cancelbutton:SetText( "Cancel" )
			cancelbutton.DoClick = function() textframe:Close() end
		end )
		menu:Open()
	end

	local playbutton = vgui.Create( "DButton", frame )
	playbutton:SetText( "Play for all" )
	playbutton.DoClick = function()
		if #list:GetSelected() <= 0 then return end
		RunConsoleCommand( "_ulx_songplayer", "playvid", list:GetSelected()[ 1 ]:GetValue( 2 ) )
	end

	local stopbutton = vgui.Create( "DButton", frame )
	stopbutton:SetText( "Stop for all" )
	stopbutton.DoClick = function()
		RunConsoleCommand( "ulx", "stopvidall" )
	end

	local refreshbutton = vgui.Create( "DButton", frame )
	refreshbutton:SetText( "Refresh" )
	refreshbutton.DoClick = ULXMusicPlayerRefresh

	local closebutton = vgui.Create( "DButton", frame )
	closebutton:SetText( "Close" )
	closebutton.DoClick = function()
		closebutton:GetParent():Close()
		menu_open = false
	end

	local playclbutton = vgui.Create( "DButton", frame )
	playclbutton:SetText( "Play client-side" )
	playclbutton.DoClick = function()
		if #list:GetSelected() <= 0 then return end
		RunConsoleCommand( "_ulx_songplayer", "playvidcl", list:GetSelected()[ 1 ]:GetValue( 2 ) )
	end

	local stopclbutton = vgui.Create( "DButton", frame )
	stopclbutton:SetText( "Stop client-side" )
	stopclbutton.DoClick = function()
		RunConsoleCommand( "ulx", "stopvid" )
	end

	local addvidbutton = vgui.Create( "DButton", frame )
	addvidbutton:SetText( "Add video" )
	addvidbutton.DoClick = function()
		local textframe = vgui.Create( "DFrame", frame )
		textframe:SetTitle( "Add video" )
		textframe:ShowCloseButton( false )
		textframe:SetDeleteOnClose( true )
		textframe:SetSize( 300, 22 + 100 )
		textframe:Center()
		textframe:MakePopup()

		local label = vgui.Create( "DLabel", textframe )
		label:SetPos( 10, 22 + 5 )
		label:SetSize( 280, 15 )
		label:SetText( "URL" )

		local textbox = vgui.Create( "DTextEntry", textframe )
		textbox:SetPos( 10, 22 + 25 )
		textbox:SetWide( 280 )
		textbox:RequestFocus()

		local function addVid()
			RunConsoleCommand( "ulx", "savevid", textbox:GetValue() )
			textframe:Close()
		end
		textbox.OnEnter = addVid

		local applybutton = vgui.Create( "DButton", textframe )
		applybutton:SetPos( 10, 22 + 55 )
		applybutton:SetSize( 135, 35 )
		applybutton:SetText( "Add" )
		applybutton.DoClick = addVid

		local cancelbutton = vgui.Create( "DButton", textframe )
		cancelbutton:SetPos( 155, 22 + 55 )
		cancelbutton:SetSize( 135, 35 )
		cancelbutton:SetText( "Cancel" )
		cancelbutton.DoClick = function() textframe:Close() end
	end

	local addcurvidbutton = vgui.Create( "DButton", frame )
	addcurvidbutton:SetText( "Add current video" )
	addcurvidbutton:SetTooltip( "Add currently playing/last played video" )
	addcurvidbutton.DoClick = function()
		RunConsoleCommand( "ulx", "savecurvid" )
	end

	local debugvidbutton = vgui.Create( "DButton", frame )
	debugvidbutton:SetText( "Debug current video" )
	debugvidbutton:SetTooltip( "\"Debugs\" the YouTube video that's playing (client-side) by showing what's on the screen (such as YouTube errors)." )
	debugvidbutton.DoClick = function()
		RunConsoleCommand( "ulx", "debugvid" )
	end

	local label = vgui.Create( "DLabel", frame )

	if ULib.ucl.query( LocalPlayer(), "ulx playvid" ) then
		label:SetText( "Double click = play for all" )
	else
		label:SetText( "Double click = play client-side" )
	end

	local function updateText( ply )
		if not ULXSongPlayerFrame or not ULXSongPlayerFrame:IsVisible() then return end
		if not ValidEntity( ply ) or ply ~= LocalPlayer() then return end
		if ULib.ucl.query( LocalPlayer(), "ulx playvid" ) then
			label:SetText( "Double click = play for all" )
		else
			label:SetText( "Double click = play client-side" )
		end
	end
	hook.Add( ULib.HOOK_UCLAUTH, "ULXMusicPlayerUpdateText", updateText )

	local volume = vgui.Create( "DNumSlider", frame )
	volume:SetText( "Volume" )
	volume:SetMin( 0 )
	volume:SetMax( 100 )
	volume:SetDecimals( 0 )
	volume:SetConVar( "ulx_songplayer_volume" )

	volume.OnValueChanged = function( panel, value )
		SongPlayer:RunJavascript( "ytplayer.setVolume( " .. value .. " )" )
	end

	volume:GetTextArea().OnGetFocus = function() frame:SetKeyboardInputEnabled( true ) end
	volume:GetTextArea().OnLoseFocus = function() frame:SetKeyboardInputEnabled( false ) end

	local OldPerformLayout = frame.PerformLayout

	frame.PerformLayout = function()

		OldPerformLayout( frame )

		local frameX, frameY = frame:GetSize()
		frameY = frameY - 22

		local buttonX = ( frameX - 50 ) / 4
		local buttonY = 40

		playbutton:SetPos( 10, 22 + 10 )
		playbutton:SetSize( buttonX, buttonY )

		stopbutton:SetPos( frameX - 10 - buttonX - 10 - buttonX - 10 - buttonX, 22 + 10 )
		stopbutton:SetSize( buttonX, buttonY )

		refreshbutton:SetPos( frameX - 10 - buttonX - 10 - buttonX, 22 + 10 )
		refreshbutton:SetSize( buttonX, buttonY )

		closebutton:SetPos( frameX - 10 - buttonX, 22 + 10 )
		closebutton:SetSize( buttonX, buttonY )

		playclbutton:SetPos( 10, 22 + 10 + buttonY + 10 )
		playclbutton:SetSize( buttonX, buttonY )

		stopclbutton:SetPos( frameX - 10 - buttonX - 10 - buttonX - 10 - buttonX, 22 + 10 + buttonY + 10 )
		stopclbutton:SetSize( buttonX, buttonY )

		addvidbutton:SetPos( frameX - 10 - buttonX - 10 - buttonX, 22 + 10 + buttonY + 10 )
		addvidbutton:SetSize( buttonX, buttonY )

		addcurvidbutton:SetPos( frameX - 10 - buttonX, 22 + 10 + buttonY + 10 )
		addcurvidbutton:SetSize( buttonX, buttonY )

		debugvidbutton:SetPos( 10, 22 + 10 + buttonY + 10 + buttonY + 10 )
		debugvidbutton:SetSize( buttonX, buttonY )

		local sliderX = math.min( 150, ( frameX / 2 ) - 15 )

		label:SetPos( 10 + buttonX + 10, 22 + 10 + buttonY + 10 + buttonY + 10 )
		label:SetSize( frameX - 10 - buttonX - 10 - 10 - sliderX - 10, 40 )

		volume:SetPos( frameX - 10 - sliderX, 22 + 10 + buttonY + 10 + buttonY + 10 )
		volume:SetSize( sliderX, 40 )

		list:SetPos( 10, 22 + 10 + buttonY + 10 + buttonY + 10 + 40 + 10 )
		list:SetSize( frameX - 20, frameY - ( 10 + buttonY + 10 + buttonY + 10 + 40 + 10 ) - 10 )

	end

	frame:SetSize( math.Clamp( 580, 0, ScrW() ), math.Clamp( 22 + 800, 0, ScrH() ) )
	frame:Center()

	ULXMusicPlayerRefresh()

end

local debugmenu
local debugmenu_open = false
function ULXSongPlayerDebug()

	if debugmenu && debugmenu_open then
		debugmenu:Close()
		debugmenu_open = false
	end

	debugmenu_open = true

	debugmenu = vgui.Create( "DFrame" )
	local frame = debugmenu
	frame:MakePopup()
	frame:SetTitle( "YouTube video debug" )
	frame:SetDeleteOnClose( true )
	frame:SetSize( math.Clamp( 10 + PlayerSizeActual.y + 10, 0, ScrW() ), math.Clamp( 22 + 10 + PlayerSizeActual.y + 10, 0, ScrH() ) )
	frame:Center()
	frame:SetKeyboardInputEnabled( false )

	SongPlayer:SetParent( frame )
	SongPlayer:SetPos( 10, 22 + 10 )
	SongPlayer:SetMouseInputEnabled( false )

	local OldClose = frame.Close
	frame.Close = function( panel )

		SongPlayer:SetParent( ULXSongPlayerPanel )
		SongPlayer:SetPos( -3 - 55 - 1, -( PlayerSizeActual.y - 4 - PlayerSize.y ) )
		SongPlayer:SetMouseInputEnabled( false )

		OldClose( panel )

		debugmenu_open = false

	end

end
