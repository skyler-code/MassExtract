local addonName = ...
local destroy = CreateFrame("Button", addonName, UIParent, "SecureActionButtonTemplate")

local tconcat = table.concat
local LootFrame, MerchantFrame, CastingBarFrame, BACKPACK_CONTAINER, NUM_BAG_SLOTS, CreateColor, RED_FONT_COLOR
    = LootFrame, MerchantFrame, CastingBarFrame, BACKPACK_CONTAINER, NUM_BAG_SLOTS, CreateColor, RED_FONT_COLOR
local UnitCastingInfo, GetSpellInfo, GetContainerItemInfo, GetContainerNumSlots, GetItemInfoInstant
    = UnitCastingInfo, GetSpellInfo, C_Container.GetContainerItemInfo, C_Container.GetContainerNumSlots, GetItemInfoInstant

local gprint = print
local function print(...)
    gprint("|cff33ff99"..addonName.."|r:", ...)
end

local prospecting = GetSpellInfo(31252) -- Prospecting
local milling = GetSpellInfo(51005) -- Milling
local lockpicking = GetSpellInfo(1804) -- Pick Lock

local DESTROY_SPELL_DB = {
    [prospecting:lower()] = {
        bindingId = 1,
        localeString = prospecting,
        tipString = ITEM_PROSPECTABLE,
        stack = 5,
        cache = {},
        itemPropCheck = function(itemId)
            local itemType, itemSubType = select(6, GetItemInfoInstant(itemId))
            return itemType == 7 and itemSubType == 7 -- Trade Goods Metal & Stone
        end,
    },
    [milling:lower()] = {
        bindingId = 2,
        localeString = milling,
        tipString = ITEM_MILLABLE,
        stack = 5,
        cache = {},
    },
    [lockpicking:lower()] = {
        bindingId = 3,
        localeString = lockpicking,
        tipString = LOCKED,
        itemPropCheck = function(itemId)
            local itemType, itemSubType = select(6, GetItemInfoInstant(itemId))
            return itemType == 15 and itemSubType == 0 -- Miscellaneous Junk
        end,
    }
}

_G["BINDING_HEADER_"..addonName:upper().."HEADER"] = addonName
for k, v in pairs(DESTROY_SPELL_DB) do
    _G["BINDING_NAME_"..addonName:upper().."BINDING"..v.bindingId] = v.localeString
end

local function CanRun()
    return not LootFrame:IsVisible() and not CastingBarFrame:IsVisible() and not UnitCastingInfo("player") and not MerchantFrame:IsVisible()
end

local destroyTooltip
local function InvSlotHasText(bagSlot, itemSlot, value)
    if not destroyTooltip then
        destroyTooltip = CreateFrame("GameTooltip", addonName.."Tooltip", nil, "GameTooltipTemplate")
        destroyTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    destroyTooltip:SetBagItem(bagSlot, itemSlot)
    for i = 1, destroyTooltip:NumLines() do
        local tipName = ("%sText%%s%s"):format(destroyTooltip:GetName(), i)
        local left = _G[tipName:format("Left")]
        if (startsWith and leftText:find(value)) or left:GetText() == value then
            return left
        end
        local right = _G[tipName:format("Right")]
        if right:GetText() == value then
            return right
        end
    end
end

local function nearestTenth(v)
    return Round(v * 10) / 10
end

local fontIsNotRedTable = {}
local function fontIsNotRed(font)
    local r,g,b = font:GetTextColor()
    local indexString = tconcat({r,g,b}, ",")
    if fontIsNotRedTable[indexString] then
        return fontIsNotRedTable[indexString]
    end
    --[[ The rgb values returned from the GameTooltip are ridiculously long floats
        that aren't equal to the values in the ColorMixin constants found in blizzard's Constants.lua
        Rounding these values allows me to compare the red on the gametooltip to RED_FONT_COLOR (#FF2020)
    ]]
    r = nearestTenth(r)
    g = nearestTenth(g)
    b = nearestTenth(b)

    fontIsNotRedTable[indexString] = not RED_FONT_COLOR:IsEqualTo(CreateColor(r,g,b))
    return fontIsNotRedTable[indexString]
end

local function findmat(destroyInfo)
    local function slotHasMat(bagSlot, itemSlot)
        local itemInfo = GetContainerItemInfo(bagSlot,itemSlot)
        if itemInfo and itemInfo.itemID ~= HEARTHSTONE_ITEM_ID and (not destroyInfo.stack or itemInfo.itemID >= destroyInfo.stack) then
            if destroyInfo.cache and destroyInfo.cache[itemInfo.itemID] ~= nil then
                return destroyInfo.cache[itemInfo.itemID]
            end
            local function slotCanBeExtracted()
                if not destroyInfo.itemPropCheck or destroyInfo.itemPropCheck(itemInfo.itemID) then
                    local font = InvSlotHasText(bagSlot, itemSlot, destroyInfo.tipString)
                    if font then
                        return fontIsNotRed(font) or nil
                    end
                end
                return false
            end
            local matIsUsable = slotCanBeExtracted()
            if destroyInfo.cache then
                destroyInfo.cache[itemInfo.itemID] = matIsUsable
            end
            return matIsUsable
        end
    end

    for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for j = 1, GetContainerNumSlots(i) do
            if slotHasMat(i,j) then
                return i,j
            end
        end
    end
end

function destroy:Setup(destroyType)
    if not destroyType or type(destroyType) ~= "string" then
        print("DESTROY TYPE MUST BE STRING")
        return
    end

    local destroyInfo = DESTROY_SPELL_DB[destroyType:lower()]
    if not destroyInfo then
        print('INVALID DESTROY TYPE')
        return
    end

    if self:GetAttribute("type") ~= "macro" then
        self:SetAttribute("type", "macro")
    end

    local text = ""
    if CanRun() then
        local b,s = findmat(destroyInfo)
        if b and s then
            text = ("%s %s\n%s %s %s"):format( SLASH_CAST1, destroyInfo.localeString, SLASH_USE1, b, s )
        end
    end
    self:SetAttribute("macrotext", text)
    if text ~= "" then
        return true
    end
end

local bindingsTable = {}
function destroy:GetBindingFrame(bindingInfo)
    if bindingsTable[bindingInfo.localeString] then
        return bindingsTable[bindingInfo.localeString]
    end
    local bindingBtnName = bindingInfo.localeString:gsub(" ", "")
    local newBinding = CreateFrame("BUTTON", self:GetName()..bindingBtnName, self, "SecureActionButtonTemplate")
    newBinding:SetAttribute("type", "macro")
    newBinding:SetScript("PreClick", function(btn)
        btn:GetParent():Setup(bindingInfo.localeString)
        btn:SetAttribute("macrotext", SLASH_CLICK1.." "..btn:GetParent():GetName())
    end)
    bindingsTable[bindingInfo.localeString] = newBinding
    return newBinding
end

function destroy:CheckBindings()
    if InCombatLockdown() then return end
    for k, v in pairs(DESTROY_SPELL_DB) do
        local button = self:GetBindingFrame(v)
		ClearOverrideBindings(button)
		for _, key in ipairs({GetBindingKey(addonName:upper().."BINDING"..v.bindingId)}) do
            SetOverrideBindingClick(button, true, key, button:GetName())
		end
    end
end

destroy.events = {}

function destroy.events:VARIABLES_LOADED()
    self:CheckBindings()
end

function destroy.events:UPDATE_BINDINGS()
    self:CheckBindings()
end

for k in pairs(destroy.events) do
    destroy:RegisterEvent(k)
end

function destroy:OnEvent(event, ...)
    local eventFunc = self.events[event]
    if eventFunc and type(eventFunc) == "function" then
        eventFunc(self, event, ...)
    end
end

destroy:SetScript("OnEvent", function(frame, ...) frame:OnEvent(...) end)