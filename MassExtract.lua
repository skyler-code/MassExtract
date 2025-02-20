local addonName = ...
local destroy = CreateFrame("Button", addonName, UIParent, "SecureActionButtonTemplate")

local tconcat = table.concat
local LootFrame, MerchantFrame, CastingBarFrame, BACKPACK_CONTAINER, NUM_BAG_SLOTS, CreateColor
    = LootFrame, MerchantFrame, CastingBarFrame, BACKPACK_CONTAINER, NUM_BAG_SLOTS, CreateColor
local UnitCastingInfo, GetContainerItemInfo, GetContainerNumSlots, GetItemInfoInstant
    = UnitCastingInfo, C_Container.GetContainerItemInfo, C_Container.GetContainerNumSlots, C_Item.GetItemInfoInstant

local gprint = print
local function print(...)
    gprint("|cff33ff99"..addonName.."|r:", ...)
end

local prospecting = C_Spell.GetSpellName(31252) -- Prospecting
local milling = C_Spell.GetSpellName(51005) -- Milling
local lockpicking = C_Spell.GetSpellName(1804) -- Pick Lock
local disenchant = C_Spell.GetSpellName(13262) -- Disenchant

local ITEM_DISENCHANT_MIN_SKILL_MSG = ITEM_DISENCHANT_MIN_SKILL:gsub("%%s", "(.+)"):gsub("%%d", "(.+)")

local DESTROY_SPELL_DB = {
    [prospecting:lower()] = {
        bindingId = 1,
        localeString = prospecting,
        tipString = ITEM_PROSPECTABLE,
        stack = 5,
        cache = {},
        itemPropCheck = function(itemInfo)
            ---@cast itemInfo ContainerItemInfo
            local itemType, itemSubType = select(6, GetItemInfoInstant(itemInfo.itemID))
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
        cache = {},
        itemPropCheck = function(itemInfo)
            ---@cast itemInfo ContainerItemInfo
            local itemType, itemSubType = select(6, GetItemInfoInstant(itemInfo.itemID))
            return itemType == 15 and itemSubType == 0 -- Miscellaneous Junk
        end,
    },
    [disenchant:lower()] = {
        bindingId = 4,
        localeString = disenchant,
        tipString = {ITEM_BIND_ON_EQUIP,ITEM_DISENCHANT_MIN_SKILL_MSG},
        itemPropCheck = function(itemInfo)
            ---@cast itemInfo ContainerItemInfo
            return itemInfo.quality <= Enum.ItemQuality.Rare
        end,
    }
}
destroy.DESTROY_SPELL_DB = DESTROY_SPELL_DB

_G["BINDING_HEADER_"..addonName:upper()] = addonName
for k, v in pairs(DESTROY_SPELL_DB) do
    _G["BINDING_NAME_"..addonName:upper().."BINDING"..v.bindingId] = v.localeString
end

local function CanRun()
    return not LootFrame:IsVisible() and not CastingBarFrame:IsVisible() and not UnitCastingInfo("player") and not MerchantFrame:IsVisible() and GetNumLootItems() == 0
end

local RED_LOCKED_TEXT = "ffff2020"

local fontIsNotRedTable = {}
local function fontIsNotRed(font)
    local r,g,b = font:GetTextColor()
    local indexString = tconcat({r,g,b}, ",")
    if fontIsNotRedTable[indexString] then
        return fontIsNotRedTable[indexString]
    end

    local colorFont = CreateColor(r,g,b):GenerateHexColor()
    fontIsNotRedTable[indexString] = RED_LOCKED_TEXT ~= colorFont
    return fontIsNotRedTable[indexString]
end

local function tableMatch(matchTable, value)
    for k,v in pairs(matchTable) do
        if v:match(value) then
            return v:match(value)
        end
    end
end

local destroyTooltip
local function InvSlotHasText(item, value)
    if not destroyTooltip then
        destroyTooltip = CreateFrame("GameTooltip", addonName.."Tooltip", nil, "GameTooltipTemplate")
        destroyTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    elseif destroyTooltip.lastItemID and item:GetItemID() == destroyTooltip.lastItemID then
        return
    end
    destroyTooltip:SetBagItem(item.itemLocation.bagID, item.itemLocation.slotIndex)
    destroyTooltip.lastItemID = item:GetItemID()

    if type(value) == "table" then
        local matches = 0
        for _, region in pairs({destroyTooltip:GetRegions()}) do
            local regionText = (region.GetText and region:GetText()) or ""
            if regionText ~= "" then
                if (tContains(value, regionText) or tableMatch(value, regionText)) then
                    matches = matches + 1
                end
                if matches == #value then
                    return region
                end
            end
        end
    else
        for _, region in pairs({destroyTooltip:GetRegions()}) do
            if region.GetText and region:GetText() == value then
                return region
            end
        end
    end
end

local function SlotHasMat(destroyInfo, item)
    local itemInfo = GetContainerItemInfo(item.itemLocation.bagID, item.itemLocation.slotIndex)
    if itemInfo.itemID ~= HEARTHSTONE_ITEM_ID and (not destroyInfo.stack or itemInfo.stackCount >= destroyInfo.stack) then
        if destroyInfo.cache and destroyInfo.cache[itemInfo.itemID] ~= nil then
            return destroyInfo.cache[itemInfo.itemID]
        end
        local function slotCanBeExtracted()
            if (not destroyInfo.itemPropCheck or destroyInfo.itemPropCheck(itemInfo)) then
                local font = InvSlotHasText(item, destroyInfo.tipString)
                if font then
                    return fontIsNotRed(font) or nil, true
                end
            end
            return false
        end
        local matIsUsable, possible = slotCanBeExtracted()
        if destroyInfo.cache and (matIsUsable or not possible) then
            destroyInfo.cache[itemInfo.itemID] = matIsUsable
        end
        return matIsUsable
    end
end

local function findmat(destroyInfo)
    for bagSlot = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
        for itemSlot = 1, GetContainerNumSlots(bagSlot) do
            local item = Item:CreateFromBagAndSlot(bagSlot, itemSlot)
            if not item:IsItemEmpty() and not item:IsItemLocked() and SlotHasMat(destroyInfo, item) then
                return bagSlot, itemSlot
            end
        end
    end
end

local function SetupMacro(self, destroyType)
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

destroy.Setup = SetupMacro

function destroy:GetBindingFrame(bindingInfo)
    if not self.bindingsTable then
        self.bindingsTable = setmetatable({}, {
            __index = function(btable, key)
                local bindingBtnName = key:gsub(" ", "")
                local newBinding = CreateFrame("BUTTON", self:GetName()..bindingBtnName, self, "SecureActionButtonTemplate")
                newBinding:SetAttribute("type", "macro")
                newBinding:SetScript("PreClick", function(btn) SetupMacro(btn, key) end)
                rawset(btable, key, newBinding)
                return newBinding
            end
        })
    end
    return self.bindingsTable[bindingInfo.localeString]
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
    if self.events[event] then
        self.events[event](self, event, ...)
    end
end

destroy:SetScript("OnEvent", destroy.OnEvent)