-- ULX YouTube Jukebox - Allows admins to play audio from YouTube videos on the server.
local ulx_cmd_category = "ULX YouTube Jukebox"

local current_vid = {}
if CLIENT then current_vid = nil end

--[[
	This function attempts to find and return the video ID in a YouTube video URL.
	Returns nil on failure.
]]
function ulx.getVideoIDFromURL( url )
	if url:len() <= 0 then return end

	local _, v_end = url:find( "v=", 1, true )
	if not v_end then return end

	local video_id = url:sub( v_end + 1, v_end + 11 ) -- 11 = Length of all YouTube video ID's
	if video_id and video_id:len() ~= 11 then return end

	return video_id
end

--[[
	This function attempts to find and return the video title in data from an HTTP request for YouTube video info.
	Returns "<unknown_title>" on failure.
]]
function ulx.getVideoTitleFromHTTPData( data )
	local video_title

	if data:len() <= 0 then
		print( "ULX YouTube Jukebox: Error retrieving video title" )
		video_title = "<unknown_title>"
	else
		local _, title_tag1_end = data:find( "<media:title type='plain'>", 1, true )
		local title_tag2_pos = data:find( "</media:title>", title_tag1_end + 1, true )
		video_title = data:sub( title_tag1_end + 1, title_tag2_pos - 1 )
		video_title = ( video_title ~= nil and video_title ~= "" ) and video_title or "<unknown_title>"
	end

	return video_title
end

--[[
	This function attempts to find and return the video length in data from an HTTP request for YouTube video info.
	Returns nil on failure.
]]
function ulx.getVideoLengthFromHTTPData( data )

	if data:len() <= 0 then return end

	local _, dur_start = data:find( "<yt:duration seconds='", 1, true )
	local dur_end = data:find( "'/>", dur_start + 1, true )

	if not dur_start or not dur_end then return end

	local duration = tonumber( data:sub( dur_start + 1, dur_end - 1 ) )

	return duration
end

function ulx.play_video( calling_ply, url )

	local video_id = ulx.getVideoIDFromURL( url )
	if not video_id then
		ULib.tsayError( calling_ply, "Invalid YouTube URL", true )
		return
	end

	for k,v in ipairs( player.GetAll() ) do
		current_vid[ v ] = video_id -- For saving videos to the server's playlist
	end

	umsg.Start( "ulx_playvid" )
		umsg.String( video_id )
	umsg.End()

	http.Get( "http://gdata.youtube.com/feeds/api/videos/" .. video_id .. "?v=2", "", function( contents )

		local video_title = ulx.getVideoTitleFromHTTPData( contents )

		ulx.fancyLogAdmin( calling_ply, "#A played YouTube video:\n#s\n#s", url, video_title )
		ULib.tsay( nil, "Type !stopvid to stop it.", true )
		ULib.csay( nil, "Now playing: " .. video_title, nil, 10 )

	end )

end
local play_video = ulx.command( ulx_cmd_category, "ulx playvid", ulx.play_video, "!playvid", true )
play_video:defaultAccess( ULib.ACCESS_ADMIN )
play_video:addParam{ type = ULib.cmds.StringArg, hint = "url" }
play_video:help( "Plays audio from a YouTube video on all clients." )

function ulx.play_video_client( calling_ply, url )

	local video_id = ulx.getVideoIDFromURL( url )
	if not video_id then
		ULib.tsayError( calling_ply, "Invalid YouTube URL", true )
		return
	end

	current_vid[ calling_ply ] = video_id

	umsg.Start( "ulx_playvid", calling_ply )
		umsg.String( video_id )
	umsg.End()

	http.Get( "http://gdata.youtube.com/feeds/api/videos/" .. video_id .. "?v=2", "", function( contents )

		local video_title = ulx.getVideoTitleFromHTTPData( contents )

		ulx.fancyLog( { calling_ply }, "#P played YouTube video client-side:\n#s\n#s", calling_ply, url, video_title ) -- Logging this way makes it only echo to the person who ran the command.
		ULib.tsay( calling_ply, "Type !stopvid to stop it.", true )
		ULib.csay( calling_ply, "Now playing: " .. video_title, nil, 10 )

	end )

end
local play_video_client = ulx.command( ulx_cmd_category, "ulx playvidcl", ulx.play_video_client, "!playvidcl", true )
play_video_client:defaultAccess( ULib.ACCESS_ALL )
play_video_client:addParam{ type = ULib.cmds.StringArg, hint = "url" }
play_video_client:help( "Plays audio from a YouTube video client-side." )

function ulx.stop_video_all( calling_ply, url )
	umsg.Start( "ulx_stopvid" )
	umsg.End()
	ulx.fancyLogAdmin( calling_ply, "#A stopped the YouTube video" )
end
local stop_video_all = ulx.command( ulx_cmd_category, "ulx stopvidall", ulx.stop_video_all, "!stopvidall", true )
stop_video_all:defaultAccess( ULib.ACCESS_ADMIN )
stop_video_all:help( "Stops the YouTube video that's playing for everyone." )

function ulx.stop_video_client( calling_ply, url )
	umsg.Start( "ulx_stopvid", calling_ply )
	umsg.End()
	ulx.fancyLog( { calling_ply }, "#P stopped the YouTube video client-side", calling_ply )
end
local stop_video_client = ulx.command( ulx_cmd_category, "ulx stopvid", ulx.stop_video_client, "!stopvid", true )
stop_video_client:defaultAccess( ULib.ACCESS_ALL )
stop_video_client:help( "Stops the YouTube video that's playing client-side." )

local songplayer_video_file = "ulx/songplayer_videos.txt"
function ulx.save_video( calling_ply, url )

	local video_id
	if url then -- Check if they're specifying a specific video to add by URL.

		video_id = ulx.getVideoIDFromURL( url )
		if not video_id then
			ULib.tsayError( calling_ply, "Invalid YouTube URL", true )
			return
		end

	else -- No URL specified, they must be trying to add their currently playing video.

		if not current_vid[ calling_ply ] then
			ULib.tsayError( calling_ply, "No YouTube videos have been played since you joined", true )
			return
		end
		video_id = current_vid[ calling_ply ]
		url = "http://www.youtube.com/watch?v=" .. video_id

	end

	if ulx.songplayer_videos[ video_id ] then
		ULib.tsayError( calling_ply, "This video is already on the server's playlist", true )
		return
	end

	http.Get( "http://gdata.youtube.com/feeds/api/videos/" .. video_id .. "?v=2", "", function( contents )

		local video_title = ulx.getVideoTitleFromHTTPData( contents )

		local video_length = ulx.getVideoLengthFromHTTPData( contents )
		ulx.songplayer_videos[ video_id ] = { title = video_title, length = video_length }

		file.Write( songplayer_video_file, ULib.makeKeyValues( ulx.songplayer_videos ) )

		ULXClientSongListRefresh()


		ulx.fancyLogAdmin( calling_ply, "#A saved YouTube video to server:\n#s\n#s", url, video_title )

	end )

end
local save_video = ulx.command( ulx_cmd_category, "ulx savevid", ulx.save_video, "!savevid", true )
save_video:defaultAccess( ULib.ACCESS_ADMIN )
save_video:addParam{ type = ULib.cmds.StringArg, hint = "url" }
save_video:help( "Saves a YouTube video URL to the server's playlist." )
local save_cur_video = ulx.command( ulx_cmd_category, "ulx savecurvid", ulx.save_video, "!savecurvid", true )
save_cur_video:defaultAccess( ULib.ACCESS_ADMIN )
save_cur_video:help( "Saves the currently playing/last played YouTube video to the server's playlist." )

function ulx.remove_video( calling_ply, url )

	local video_id = ulx.getVideoIDFromURL( url )
	if not video_id then
		ULib.tsayError( calling_ply, "Invalid YouTube URL", true )
		return
	end

	if not ulx.songplayer_videos[ video_id ] then
		ULib.tsayError( calling_ply, "This video is not on the server's playlist", true )
		return
	end

	local video_title = ulx.songplayer_videos[ video_id ].title

	ulx.songplayer_videos[ video_id ] = nil

	file.Write( songplayer_video_file, ULib.makeKeyValues( ulx.songplayer_videos ) )

	ULXClientSongListRefresh()


	ulx.fancyLogAdmin( calling_ply, "#A removed YouTube video from server:\n#s\n#s", url, video_title )

end
local remove_video = ulx.command( ulx_cmd_category, "ulx removevid", ulx.remove_video, "!removevid", true )
remove_video:defaultAccess( ULib.ACCESS_ADMIN )
remove_video:addParam{ type = ULib.cmds.StringArg, hint = "url" }
remove_video:help( "Removes a YouTube video URL from the server's playlist." )

function ulx.rename_video( calling_ply, url, new_title )

	local video_id = ulx.getVideoIDFromURL( url )
	if not video_id then
		ULib.tsayError( calling_ply, "Invalid YouTube URL", true )
		return
	end

	if not ulx.songplayer_videos[ video_id ] then
		ULib.tsayError( calling_ply, "This video is not on the server's playlist", true )
		return
	end

	local old_title = ulx.songplayer_videos[ video_id ].title
	new_title = new_title:gsub( "<quote>", "\"" ) -- This is to fix quotation marks being replaced with ' by RunConsoleCommand.
	ulx.songplayer_videos[ video_id ].title = new_title

	file.Write( songplayer_video_file, ULib.makeKeyValues( ulx.songplayer_videos ) )

	ULXClientSongListRefresh()


	ulx.fancyLogAdmin( calling_ply, "#A renamed YouTube video from:\n#s\nto:\n#s", old_title, new_title )

end
local rename_video = ulx.command( ulx_cmd_category, "ulx renamevid", ulx.rename_video, "!renamevid", true )
rename_video:defaultAccess( ULib.ACCESS_ADMIN )
rename_video:addParam{ type = ULib.cmds.StringArg, hint = "url" }
rename_video:addParam{ type = ULib.cmds.StringArg, hint = "title", ULib.cmds.takeRestOfLine }
rename_video:help( "Renames a video on the server's playlist." )

function ulx.music( calling_ply )
	ULib.clientRPC( calling_ply, "ULXOpenMusicPlayer" )
end
local music = ulx.command( ulx_cmd_category, "ulx music", ulx.music, "!music", true )
music:defaultAccess( ULib.ACCESS_ALL )
music:help( "Opens the YouTube Jukebox menu." )

function ulx.debug_video( calling_ply )
	ULib.clientRPC( calling_ply, "ULXSongPlayerDebug" )
end
local debug_video = ulx.command( ulx_cmd_category, "ulx debugvid", ulx.debug_video, "!debugvid", true )
debug_video:defaultAccess( ULib.ACCESS_ALL )
debug_video:help( "\"Debugs\" the YouTube video that's playing (client-side) by showing what's on the screen (such as YouTube errors)." )

if SERVER then

if not ulx.songplayer_videos then
	ulx.songplayer_videos = {}
	if file.Exists( songplayer_video_file ) then
		ulx.songplayer_videos = ULib.parseKeyValues( file.Read( songplayer_video_file ) )
	end
end

local function internalCommandForMenu( calling_ply, cmd, args )
	local arg = args[ 1 ]
	if arg == "playvid" or arg == "playvidcl" then

		if not ULib.ucl.query( calling_ply, "ulx " .. arg ) then
			ULib.tsay( calling_ply, "You do not have access to this command, " .. calling_ply:Nick() .. ".", true )
			return
		end

		local video_id = args[ 2 ]
		if not video_id or video_id:len() ~= 11 then
			ULib.tsayError( calling_ply, "Invalid video ID", true )
			return
		end

		if not ulx.songplayer_videos[ video_id ] then
			ULib.tsayError( calling_ply, "This video is not on the server's playlist", true )
			return
		end

		local target = ( arg == "playvidcl" ) and calling_ply or nil

		umsg.Start( "ulx_playvid", target )
			umsg.String( video_id )
		umsg.End()

		local video_title = ulx.songplayer_videos[ video_id ].title

		if target then -- Playing client-side
			ulx.fancyLog( { calling_ply }, "#P played YouTube video client-side:\n#s", calling_ply, video_title )
		else
			ulx.fancyLogAdmin( calling_ply, "#A played YouTube video:\n#s", video_title )
		end

		ULib.tsay( target, "Type !stopvid to stop it.", true )
		ULib.csay( target, "Now playing: " .. video_title, nil, 10 )

		if target then
			current_vid[ target ] = video_id
		else
			for k,v in ipairs( player.GetAll() ) do
				current_vid[ v ] = video_id
			end
		end

	elseif arg == "retrievesongs" and ULib.ucl.query( calling_ply, "ulx music" ) then
		for video_id, video_table in pairs( ulx.songplayer_videos ) do
			umsg.Start( "ULXTransferSong", calling_ply )
				umsg.String( video_id )
				umsg.String( video_table.title )
				umsg.Long( video_table.length )
			umsg.End()
		end
		umsg.Start( "ULXTransferSongsDone", calling_ply )
		umsg.End()
	end
end
concommand.Add( "_ulx_songplayer", internalCommandForMenu, nil, "*DO NOT RUN DIRECTLY* Internal command for the ULX YouTube Jukebox menu." )

function ULXClientSongListRefresh( ply ) -- Makes a client (or all clients) refresh their song list.
	ULib.clientRPC( ply, "ULXMusicPlayerRefresh" )
end

local function removePlyCurVid( ent )
	if ValidEntity( ent ) and ent:GetClass() == "player" then
		current_vid[ ent ] = nil
	end
end
hook.Add( "EntityRemoved", "ulxRemovePlyCurVid", removePlyCurVid ) -- I read that PlayerDisconnected sometimes doesn't get called, so I'm using EntityRemoved instead.

end
