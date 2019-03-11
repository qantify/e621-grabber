--[[
--
-- // Garry's Mod e621 Grabber //
--
-- Simple chat bot thing for grabbing top quality E621 content.
--
-- MIT License
--
-- Copyright (c) 2019 Qantify
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
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
local version = "1.0"

// Mode enums.
local M_SEARCH = 1
local M_SHOW = 2

// Rating types.
local R_SAFE = "safe"
local R_QUESTIONABLE = "questionable"
local R_EXPLICT = "explict"

// Patterns for matching commands.
local patterns = {
  start = {"furbot ", "e621 ", "furry "},
  show = {"show", "view"},
  safe = {"sfw search", "swf search", "e926", "safe"},
  questionable = {"mild search", "questionable"},
  explict = {"search", "e621", "explict"},
  thanks = {"good bot", "great bot", "thank", "thanks"},
  bad = {"bad bot", "fuck you"}
}

// HTTP headers.
local headers = {}
headers["User-Agent"] = "GarrysMode621Grabber/" .. version .. " (https://github.com/qantify/e621-grabber)"

//[[ Settings. ]]//

// Define convars.
local varEnabled = CreateConVar(
  "e621_enabled",
  "1",
  FCVAR_REPLICATED,
  "Enable the e621 bot?"
)
local varAllowUnsafe = CreateConVar(
  "e621_allowunsafe",
  "0",
  FCVAR_REPLICATED,
  "Allow explict/questionable searches?"
)
local varBlacklist = CreateConVar(
  "e621_blacklist",
  "cub feral forced gore loli mlp scat watersports",
  FCVAR_REPLICATED,
  "Blacklisted tags for this server, seperate with spaces."
)

// Function to get current settings.
local function curSettings()
  return {
    enabled = varEnabled:GetBool(),
    allowUnsafe = varAllowUnsafe:GetBool(),
    blacklist = string.Split(varBlacklist:GetString(), " ")
  }
end

//[[ Utility functions. ]]//

// Format a chat message.
local function format(message)
  message = tostring(message)
  message = "[e621] " .. message
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
  // Send to players.
  if chat then
    for _, ply in pairs(player.GetAll()) do
      ply:ChatPrint(message)
    end
  end
end

// Log a message to a specific player.
local function outPly(ply, message)
  ply:ChatPrint(format(message))
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

// Generate a new random value. (base36 string)
local function randomID()
  // Conversion settings.
  local base = 36
  local characters = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  local characterCount = 4

  // Generate a random value.
  local value = math.random(math.pow(base, characterCount))

  // Convert the value into a base36 string.
  local text = ""
  local i = 0
  local d = 0
  while value > 0 do
    i = i + 1
    value = math.floor(value / base)
    d = (value % base) + 1
    text = string.sub(characters, d, d)
  end

  // Return the string.
  return text
end

//[[ Main functionality. ]]//

// Post cache.
local postCache = {}

// Run this function every time someone says something.
hook.Add("PlayerSay", "PlayerSay_e621Grabber", function(ply, text, team)

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
  local checkSearchExplict = matchPatterns(message, 1, patterns.explict, call)

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
  elseif checkSearchExplict != nil then
    mode = M_SEARCH
    rating = R_EXPLICT
    fullCall = checkSearchExplict

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
    local input = string.Split(string.sub(message, callPosition), " ")

    // Check if a post ID was specified.
    if input[1] == nil then return end

    // Attempt to get said post.
    local postURL = postCache[string.upper(tostring(input[1]))]

    // Complain if it was not found.
    if postURL == nil then
      outPly(ply, "Sorry " .. ply:Name() .. ", that post was not found.")
      return
    end

    // Open said post.
    ply:SendLua([[gui.OpenURL("]] .. postURL .. [[")]])

    // Don't run further code.
    return
    
  end

end)

//[[ Say hi! ]]//
console("Started e621 bot v" .. version .. " successfully!")
