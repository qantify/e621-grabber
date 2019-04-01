--[[
--
-- // Garry's Mod e621 Grabber //
--
-- Simple chat bot thing for grabbing top quality e621 content.
--
-- MIT License
--
-- Copyright (c) 2019 Qantify
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the 'Software'), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
--]]

//[[ Setup. ]]//

// Prevent this script from running on the client.
if CLIENT then return end

// Version number.
local version = '1.1'

// Mode enums.
local M_SEARCH = 1
local M_SHOW = 2

// Rating types.
local R_SAFE = 'safe'
local R_QUESTIONABLE = 'questionable'
local R_EXPLICIT = 'explicit'

// Patterns for matching commands.
local patterns = {
  start = {'furbot ', 'e621 ', 'furry ', 'fur '},
  show = {'show', 'view', 'open'},
  safe = {'sfw search', 'swf search', 'e926', 'safe'},
  questionable = {'mild search', 'questionable'},
  explicit = {'search', 'e621', 'explicit', 'explict'}
}

// Maximum amount of posts to load.
local postLimit = 20

// Max tag count. (e621 sets this as 6, but watch out for bot defined tags)
local tagLimit = 4

// HTTP headers.
local headers = {}
headers['User-Agent'] = 'GarrysMode621Grabber/' .. version .. ' (https://github.com/qantify/e621-grabber)'

//[[ Settings. ]]//

// Define convars.
local varEnabled = CreateConVar(
  'e621_enabled',
  '1',
  FCVAR_REPLICATED,
  'Enable the e621 bot?'
)
local varAllowUnsafe = CreateConVar(
  'e621_allowunsafe',
  '0',
  FCVAR_REPLICATED,
  'Allow explicit/questionable searches?'
)
local varMinScore = CreateConVar(
  'e621_minscore',
  '20',
  FCVAR_REPLICATED,
  'Minimum post score?'
)
local varBlacklist = CreateConVar(
  'e621_blacklist',
  'cub feral forced gore loli mlp scat watersports',
  FCVAR_REPLICATED,
  'Blacklisted tags for this server, seperate with spaces.'
)

// Function to get current settings.
local function curSettings()
  return {
    enabled = varEnabled:GetBool(),
    allowUnsafe = varAllowUnsafe:GetBool(),
    minScore = varMinScore:GetInt(),
    blacklist = string.Split(varBlacklist:GetString(), ' ')
  }
end

//[[ Utility functions. ]]//

// Format a chat message.
local function format(message)
  message = tostring(message)
  message = '[e621] ' .. message
  return message
end

// Log a message to console.
local function console(message)
  // Print to the console.
  print(format(message))
end

// Log a message to chat.
local function out(message)
  // Format.
  message = format(message)
  // Print to the console.
  print(message)
  // Timer to prevent time travel.
  timer.Simple(0, function()
    // Send to players.
    for _, ply in pairs(player.GetAll()) do
      ply:ChatPrint(message)
    end
  end)
end

// Log a message to a specific player.
local function outPly(ply, message)
  // Timer to prevent time travel.
  timer.Simple(0, function()
    // Send to player.
    ply:ChatPrint(format(message))
  end)
end

// See if a string matches a list of patterns and return the match.
local function matchPatterns(text, start, check, prefix)
  // Loop through specified patterns.
  for _, pattern in pairs(check) do
    // Use prefix.
    if prefix != nil then pattern = prefix .. pattern end
    // Check for matches and pack results.
    local result = {string.match(text, pattern, start)}
    // See if we actually matched.
    if result[1] != nil then
      // Return results.
      return unpack(result)
    end
  end
  // Did not match at all, return nil.
  return nil
end

// Check if a table contains an element.
local function contains(table, element)
  // Loop through the table and check each element.
  for _, value in pairs(table) do
    // Equal?
    if value == element then
      return true
    end
  end
  return false
end

// Function to encode URLs.
local function urlEncode(url)
  // Character to hex converter.
  local function charToHex(char)
    return string.format('%%%02X', string.byte(char))
  end
  // Convert string.
  url = string.gsub(url, '\n', '\r\n')
  url = string.gsub(url, '([^%w ])', charToHex)
  url = string.gsub(url, ' ', '+')
  // Return encoded URL.
  return url
end

// Generate a new random identifier.
local function randomID(length)
  // Conversion settings.
  local base = 30 // 36
  local characters = string.upper('0123456789ABCDEFHIKMOPRSTUVXYZ') // '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  local characterCount = length or 3

  // Generate a random value.
  local value = math.random(math.pow(base, characterCount))

  // Convert.
  local result = ''
  while value > 0 do
    result = characters[value % base] .. result
    value = math.floor(value / base)
  end

  // Return result.
  return result
end

//[[ Main functionality. ]]//

// Post cache.
local postCache = {}

// Function to get post data from the e621 API.
local function e621(rating, minScore, tags, callback)
  // Set URL.
  local url = 'https://e621.net/post/index.json' ..
  '?limit=' ..
  postLimit ..
  '&tags='

  // Start the tag URL.
  local tagUrl = 'rating:' .. rating .. ' score:>=' .. minScore
  // Add tag padding if needed.
  if #tags != 0 then tagUrl = tagUrl .. ' ' end

  // Apply tags.
  for i, tag in ipairs(tags) do
    // Add this tag.
    tagUrl = tagUrl .. tag
    // Add a space if needed.
    if i != #tags then tagUrl = tagUrl .. ' ' end
  end

  // Encode the tags.
  tagUrl = urlEncode(tagUrl)
  // Combine both the base URL and the tag URL.
  url = url .. tagUrl

  // Log.
  console('Requesting URL "' .. url .. '".')

  // Fetch content.
  http.Fetch(
    url, // Use generated URL.
    function (body, len, head, stat) // Got response.
      // Log.
      console('Response received, code ' .. stat .. '.')

      // Check for errors.
      stat = tostring(stat)
      if stat != '200' then
        callback(head['Status'] or stat)
        return
      end

      // Execute callback.
      callback(
        nil,
        util.JSONToTable(body) // Convert JSON response to a table.
      )
    end,
    function (err) // Error encountered.
      // Log.
      console('Error sending request or receiving response!')
      // Send error.
      callback(tostring(err))
    end,
    headers // Supply headers defined earlier, with user agent.
  )
end

// Run this function every time someone says something.
hook.Add('PlayerSay', 'PlayerSay_e621Grabber', function(ply, text, team)

  //[[ Init. ]]//

  // Get settings.
  local settings = curSettings()

  // Do not run for team chat.
  if team then return end
  // Do not run if disabled.
  if not settings.enabled then return end

  // Lowercase the message.
  local message = string.lower(text)

  // Find out the string that was used to call the bot.
  local call = matchPatterns(message, 1, patterns.start)
  // Do not run if no call was found.
  if call == nil then return end

  //[[ Find the mode and rating. ]]//

  // Check for show.
  local checkShow = matchPatterns(message, 1, patterns.show, call)

  // Check for various types of search.
  local checkSearchSafe = matchPatterns(message, 1, patterns.safe, call)
  local checkSearchQuest = matchPatterns(message, 1, patterns.questionable, call)
  local checkSearchExplicit = matchPatterns(message, 1, patterns.explicit, call)

  // Selected mode, rating, full call and good status.
  local mode
  local rating
  local fullCall

  // Select the mode and rating.
  if checkShow != nil then
    mode = M_SHOW
    fullCall = checkShow

  elseif checkSearchSafe != nil then
    mode = M_SEARCH
    rating = R_SAFE
    fullCall = checkSearchSafe
  elseif checkSearchQuest != nil then
    mode = M_SEARCH
    rating = R_QUESTIONABLE
    fullCall = checkSearchQuest
  elseif checkSearchExplicit != nil then
    mode = M_SEARCH
    rating = R_EXPLICIT
    fullCall = checkSearchExplicit

  else
    // All checks failed! (don't do anything)
    return
  end

  // Find the position of the call.
  local _, callPosition = string.find(message, fullCall)
  // Pad.
  callPosition = callPosition + 2

  //[[ Show a post. ]]//

  // Make sure the mode is showing.
  if mode == M_SHOW then

    // Get and split input.
    local input = string.Split(string.sub(message, callPosition), ' ')

    // Check if a post ID was specified.
    if input[1] == nil then return end

    // Attempt to get said post.
    local postID = string.upper(tostring(input[1]))
    local postURL = postCache[postID]

    // Complain if it was not found.
    if postURL == nil then
      outPly(ply, 'Sorry ' .. ply:Name() .. ', post ' .. postID .. ' was not found.')
      return
    end

    // Log.
    outPly(ply, 'Opening post ' .. postID .. '...')
    console('User ' .. ply:Name() .. ' opened post ' .. postID .. '.')

    // Open said post.
    ply:SendLua([[gui.OpenURL(']] .. postURL .. [[')]])

    // Don't run further code.
    return

  end

  //[[ Find a post. ]]//

  // Lock the rating if needed.
  if (not settings.allowUnsafe) and rating != R_SAFE then
    rating = R_SAFE
    out(
      'Explicit/questionable searches are disabled on this server, using safe mode. (change with "e621_allowunsafe 1" command)'
    )
  end

  // Get the string containing tags.
  local tagString = string.sub(message, callPosition)

  // Remove empty tags and format spaces.
  tagString = string.gsub(tagString, '%s', ' ')
  tagString = string.gsub(tagString, '%s%s', ' ')
  tagString = string.gsub(tagString, '%s', ' ')
  tagString = string.gsub(tagString, '%s%s', ' ')

  // Split into table.
  local tags = string.Split(tagString, ' ')

  // Make sure atleast 1 tag was specified.
  if #tags < 1 or (#tags > 0 and tags[1] == '') then
    out('Sorry ' .. ply:Name() .. ', you have to specify some tags.')
    return
  end

  // Limit tags.
  if #tags > tagLimit then
    out(
      'Sorry ' ..
      ply:Name() ..
      ', I can only do ' ..
      tagLimit ..
      ' tags at a time.'
    )
    return
  end

  // Log.
  out(
    'Ok ' ..
    ply:Name() ..
    ', searching for a post with tags "' ..
    tagString ..
    '" and rating ' ..
    rating ..
    '.'
  )

  // Ping E621 and wait for the response.
  e621(rating, settings.minScore, tags, function (error, response)

    // Check for errors.
    if error or response == nil then
      out(
        'Sorry ' ..
        ply:Name() ..
        ', there was an issue processing your request.'
      )
      console('Error occurred, "' .. error .. '".')
      return
    end

    // Matching posts.
    local matches = {}

    // Loop through response table and find posts that match the criteria.
    for _, post in pairs(response) do
      // Make sure it is active.
      if post['status'] != 'active' then continue end
      // Make sure that it isn't flash.
      if post['file_ext'] == 'swf' then continue end

      // Get tags.
      local postTags = string.Split(post['tags'], ' ')

      // Check against blacklist.
      local blacklistFound = false
      for _, blacklisted in pairs(settings.blacklist) do
        if contains(postTags, blacklisted) then
          blacklistFound = true
          break
        end
      end

      // Make sure no blacklisted tags were found.
      if blacklistFound then continue end

      // Insert the post into the matches.
      table.insert(matches, post)
    end

    // Make sure we actually found atleast 1 post.
    if #matches < 1 then
      out(
        'No matching posts found, you may have an invalid/blacklisted tag, or all posts for your tags have a score below ' ..
        settings.minScore ..
        '.'
      )
      return
    end

    // Find a random post in matching posts.
    local selected = matches[math.random(#matches)]

    // Find a new unique ID.
    local newIDLength = 3
    local newID = randomID(newIDLength)
    // Make sure there are no duplicates.
    while postCache[newID] != nil do
      newIDLength = newIDLength + 1
      newID = randomID(newIDLength)
    end

    // Register it.
    postCache[newID] = 'https://e621.net/post/show/' .. selected['id']

    // Print out post.
    out('Found post "' .. postCache[newID] .. '", use "' .. call .. 'show ' .. newID .. '" to open this link.')

  end)

end)

// Bugfix for Pretzel, forces this hook to run.
// NOTE: By force to run I mean by deleting all other PlayerSay hooks.
concommand.Add('e621_forceenable', function(ply, cmd, args, str)
  // Log.
  out('Forcefully disabling all other PlayerSay hooks. This WILL break other addons.')
  // Set the hook PlayerSay table in the worst way possible.
  hook.GetTable()['PlayerSay'] = {
    // Only use this hook.
    PlayerSay_e621Grabber = hook.GetTable()['PlayerSay']['PlayerSay_e621Grabber']
  }
end)

//[[ Say hi! ]]//
console('Started e621 bot v' .. version .. ' successfully!')
