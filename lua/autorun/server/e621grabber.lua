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
local M_THANKS = 3

// Patterns for matching commands.
local patterns = {
  start = {"furbot ", "e621 ", "furry "},
  show = {"show", "view"},
  safe = {"sfw search", "swf search", "e926", "safe"},
  questionable = {"mild search", "questionable"},
  explict = {"search", "e621", "explict", --[[ May fuck stuff up? ]] ""},
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
local varThanks = CreateConVar(
  "e621_thanks",
  "1",
  FCVAR_REPLICATED,
  "Allow users to thank the bot?"
)

// Function to get current settings.
local function curSettings()
  return {
    enabled = varEnabled:GetBool(),
    allowUnsafe = varAllowUnsafe:GetBool(),
    blacklist = varBlacklist:GetString():split(" "),
    thanks = varThanks:GetBool()
  }
end

//[[ Utility functions. ]]//

// Log a message to chat.
local function out(chat, message)
  // Make sure it is a string.
  message = tostring(message)
  // Add the header thing.
  message = "[e621] " .. message
  // Print to the console.
  print(message)
  // Send to players.
  if chat then
    for _, ply in pairs(player.GetAll()) do
      ply:ChatPrint(message)
    end
  end
end

//[[ Main functionality. ]]//

// Was the last message sent by the bot?
local lastMessageBot = false

// Run this function every time someone says something.
hook.Add("PlayerSay", "PlayerSay_e621Grabber", function(ply, text, team)
  // Update last message state.
  lastMessageBot = true

  // Get settings.
  local settings = curSettings()

  // Do not run for team chat.
  if team then return end
  // Do not run if disabled.
  if not settings.enabled then return end

  // Lowercase the message.
  local message = text:lower()

end)

//[[ Say hi! ]]//
out("Started e621 bot v" .. version .. " successfully!")
