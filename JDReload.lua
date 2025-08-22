local CUSTOM_TEXTURES = (JDReloadTextures and JDReloadTextures.CUSTOM_TEXTURES) or {}

local DEFAULT_TEXTURES = {
  "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
  "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
  "Interface\\Buttons\\UI-GroupLoot-DE-Up",
  "Interface\\Icons\\INV_Misc_QuestionMark",
}

local IMG_SIZE       = 512
local PADDING        = 24
local TITLE_SPACE    = 36
local BUTTON_W       = 220
local BUTTON_H       = 40
local BUTTON_MARGIN  = 18
local FRAME_W        = math.max(IMG_SIZE + 2 * PADDING, BUTTON_W + 2 * PADDING)
local FRAME_H        = TITLE_SPACE + IMG_SIZE + BUTTON_MARGIN + BUTTON_H + PADDING

local PREFIX = "JDRELOAD"
local DEBUG  = false

local function dprint(...)
  if DEBUG then print("|cff7fbfffJDReload|r", ...) end
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
  C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

local function pickRandomTexture()
  local pool = (#CUSTOM_TEXTURES > 0) and CUSTOM_TEXTURES or DEFAULT_TEXTURES
  return pool[math.random(1, #pool)]
end

local function CreateReloadFrame()
  if JDReloadFrame then return end

  local f = CreateFrame("Frame", "JDReloadFrame", UIParent)
  f:SetSize(FRAME_W, FRAME_H)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetClampedToScreen(true)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(true)
  bg:SetColorTexture(0, 0, 0, 0.85)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -8)
  title:SetText("JD Reload")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -6, -6)

  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetSize(IMG_SIZE, IMG_SIZE)
  tex:SetPoint("TOP", 0, -TITLE_SPACE)
  tex:SetTexture(pickRandomTexture())
  f.tex = tex

  local btnBg = f:CreateTexture(nil, "ARTWORK")
  btnBg:SetSize(BUTTON_W, BUTTON_H)
  btnBg:SetPoint("BOTTOM", 0, PADDING / 2)
  btnBg:SetColorTexture(0.18, 0.18, 0.18, 1)

  local btnHL = f:CreateTexture(nil, "HIGHLIGHT")
  btnHL:SetAllPoints(btnBg)
  btnHL:SetColorTexture(1, 1, 1, 0.12)

  local btn = CreateFrame("Button", "JDReload_CustomButton", f)
  btn:SetAllPoints(btnBg)
  btn:EnableMouse(true)
  btn:SetScript("OnClick", function() ReloadUI() end)

  local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  btnText:SetPoint("CENTER")
  btnText:SetText("Reload UI")
  f.btn = btn

  f:SetScript("OnShow", function(self)
    self.lastShown = GetTime()
    self.tex:SetTexture(pickRandomTexture())
  end)

  f:Hide()
end

local function UnitFullNameWithRealm(unit)
  local name, realm = UnitFullName(unit)
  if not name then return nil end
  if not realm or realm == "" then realm = GetNormalizedRealmName() end
  return name .. "-" .. realm
end

local function ForEachGroupMember(callback)
  local n = GetNumGroupMembers()
  if n == 0 then return end
  local isRaid = IsInRaid()
  for i = 1, n do
    local unit = isRaid and ("raid"..i) or ("party"..i)
    if UnitExists(unit) then
      callback(unit, UnitFullNameWithRealm(unit))
    end
  end
end

local function GetAddonChannel()
  if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
    return "INSTANCE_CHAT"
  end
  if IsInRaid() then
    return "RAID"
  end
  if IsInGroup() then
    return "PARTY"
  end
  return nil
end

local function WhisperFallback(msg)
  ForEachGroupMember(function(unit, full)
    if full and not UnitIsUnit(unit, "player") then
      C_ChatInfo.SendAddonMessage(PREFIX, msg, "WHISPER", full)
    end
  end)
end

local function Broadcast(msg)
  local ch = GetAddonChannel()
  if ch then
    C_ChatInfo.SendAddonMessage(PREFIX, msg, ch)
  end
  WhisperFallback(msg)
end

local evt = CreateFrame("Frame")
evt:RegisterEvent("ADDON_LOADED")
evt:RegisterEvent("CHAT_MSG_ADDON")

evt:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" then
    local name = ...
    if name == "JDReload" then
      if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
      end
      dprint("loaded and prefix registered")
    end
  elseif event == "CHAT_MSG_ADDON" then
    local prefix, msg, channel, sender = ...
    if prefix ~= PREFIX then return end

    if msg == "SHOW" then
      if JDReloadFrame and JDReloadFrame:IsShown() and (GetTime() - (JDReloadFrame.lastShown or 0)) < 0.5 then
        return
      end
      local me = UnitFullNameWithRealm("player")
      if sender ~= me then
        print("|cff7fbfffJDReload|r triggered by " .. (sender or "unknown"))
      end
      CreateReloadFrame()
      JDReloadFrame:Show()
    elseif msg == "PING" then
      local me = UnitFullNameWithRealm("player")
      if sender ~= me then
        C_ChatInfo.SendAddonMessage(PREFIX, "PONG", "WHISPER", sender)
      end
    elseif msg == "PONG" then
      print("|cff7fbfffJDReload|r online: " .. (sender or "unknown"))
    end
  end
end)

_G.SLASH_JDRELOAD1 = "/jdreload"
SlashCmdList["JDRELOAD"] = function()
  if IsInGroup() then
    if not (UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")) then
      print("|cffff0000Only raid leader or assistant can trigger this.|r")
      return
    end
    CreateReloadFrame()
    JDReloadFrame:Show()
    Broadcast("SHOW")
  else
    CreateReloadFrame()
    JDReloadFrame:Show()
    print("|cffffff00Solo test. In group it will be sent to everyone with the addon.|r")
  end
end

_G.SLASH_JDCHECK1 = "/jdcheck"
SlashCmdList["JDCHECK"] = function()
  if not IsInGroup() then
    print("|cffffff00Not in group.|r")
    return
  end
  print("|cff7fbfffJDReload|r check: ping…")
  Broadcast("PING")
end
