local currencyClickButton = CreateFrame("Button", "CashinatorCurrencyClickButton", UIParent, "SecureActionButtonTemplate")
currencyClickButton:SetAttribute("type", "click")
currencyClickButton:RegisterForClicks("AnyUp", "AnyDown")
currencyClickButton:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT")
currencyClickButton:SetSize(5, 5)
do
  local transferShowButton = CreateFrame("Button", "CashinatorTransferShowButton", UIParent, "SecureActionButtonTemplate")
  transferShowButton:RegisterForClicks("AnyUp", "AnyDown")
  transferShowButton:SetAttribute("type", "click")
  transferShowButton:SetAttribute("clickbutton", TokenFramePopup.CurrencyTransferToggleButton)

  local maxTransferButton = CreateFrame("Button", "CashinatorMaxTransferButton", UIParent, "SecureActionButtonTemplate")
  maxTransferButton:RegisterForClicks("AnyUp", "AnyDown")
  maxTransferButton:SetAttribute("type", "click")
  maxTransferButton:SetAttribute("clickbutton", CurrencyTransferMenu.AmountSelector.MaxQuantityButton)

  local actuallyTransferButton = CreateFrame("Button", "CashinatorActuallyTransferButton", UIParent, "SecureActionButtonTemplate")
  actuallyTransferButton:RegisterForClicks("AnyUp", "AnyDown")
  actuallyTransferButton:SetAttribute("type", "click")
  actuallyTransferButton:SetAttribute("clickbutton", CurrencyTransferMenu.ConfirmButton)
end

local SetParent = UIParent.SetParent

local sounds = {
  567422, -- SOUNDKIT.IG_CHARACTER_INFO_TAB
  567507, -- SOUNDKIT.IG_CHARACTER_INFO_OPEN
  567433, -- SOUNDKIT.IG_CHARACTER_INFO_CLOSE
}
local function Mute()
  for _, s in ipairs(sounds) do
    MuteSoundFile(s)
  end
end
local function Unmute()
  C_Timer.After(0, function()
    for _, s in ipairs(sounds) do
      UnmuteSoundFile(s)
    end
  end)
end

local function GetTransferButton(templates)
  templates = templates and "SecureActionButtonTemplate," .. templates or "SecureActionButtonTemplate"
  local transferButton = CreateFrame("Button", "CashinatorButton", UIParent, templates)
  transferButton:RegisterForClicks("AnyUp", "AnyDown")
  transferButton:SetAttribute("downbutton", "startup")
  transferButton:SetAttribute("typerelease", "macro")
  transferButton:SetAttribute("type", "macro")
  transferButton:SetAttribute("pressAndHoldAction", true)
  transferButton:SetAttribute("macrotext-startup", [[
/click CashinatorCurrencyClickButton LeftButton 1
/click CashinatorTransferShowButton LeftButton 1
/click CashinatorMaxTransferButton LeftButton 1
  ]])
  transferButton:SetAttribute("macrotext", [[
/click CashinatorActuallyTransferButton LeftButton 1
  ]])
  transferButton:HookScript("OnClick", function()
    TokenFramePopup:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 3, -28)
  end)

  transferButton:SetScript("OnEnter", function()
    if InCombatLockdown() or not transferButton.currencyID then
      return
    end

    Mute()
    local characterParent = CharacterFrame:GetParent()
    local tokenParent = TokenFrame:GetParent()
    local characterVisible = CharacterFrame:IsVisible()
    local tokenVisible = TokenFrame:IsVisible()
    HideUIPanel(CharacterFrame)
    HideUIPanel(TokenFrame)
    -- Weird SetParent to work around UI overhauls no-op-ing it out.
    SetParent(CharacterFrame, UIParent)
    SetParent(TokenFrame, CharacterFrame)
    Unmute()

    local function Handler()
      local index = 0
      while index < C_CurrencyInfo.GetCurrencyListSize() do
        index = index + 1
        local info = C_CurrencyInfo.GetCurrencyListInfo(index)
        if info.isHeader then
          if not info.isHeaderExpanded then
            C_CurrencyInfo.ExpandCurrencyList(index, true)
          end
        else
          local link = C_CurrencyInfo.GetCurrencyListLink(index)
          if link ~= nil then
            local currencyID = C_CurrencyInfo.GetCurrencyIDFromLink(link)
            if currencyID == transferButton.currencyID then
              break
            end
          end
        end
      end
      TokenFrame.ScrollBox:ClearAllPoints()
      -- 30 is slightly larger than the tallest possible row in the currency
      -- panel
      TokenFrame.ScrollBox:SetHeight(30 * C_CurrencyInfo.GetCurrencyListSize())
      TokenFrame.ScrollBox:SetWidth(200)
      TokenFrame.ScrollBox:SetPoint("TOPLEFT", UIParent)

      TokenFrame.ScrollBox:RegisterCallback(BaseScrollBoxEvents.OnLayout, function()
        TokenFrame.ScrollBox:UnregisterCallback(BaseScrollBoxEvents.OnLayout, transferButton)
        currencyClickButton:SetAttribute("clickbutton", TokenFrame.ScrollBox:GetFrames()[index])
        Mute()
        HideUIPanel(TokenFrame)
        HideUIPanel(CharacterFrame)
        SetParent(CharacterFrame, characterParent)
        SetParent(TokenFrame, tokenParent)
        if tokenVisible then
          ShowUIPanel(TokenFrame)
        end
        if characterVisible then
          ShowUIPanel(CharacterFrame)
        end
        Unmute()
        TokenFrame.ScrollBox:ClearAllPoints()
        TokenFrame.ScrollBox:SetPoint("TOPLEFT", CharacterFrame.Inset, 4, -4)
        TokenFrame.ScrollBox:SetPoint("BOTTOMRIGHT", CharacterFrame.Inset, -22, 2)
      end, transferButton)

      Mute()
      ShowUIPanel(CharacterFrame)
      ShowUIPanel(TokenFrame)
      Unmute()

      transferButton:SetScript("OnUpdate", nil)
    end
    transferButton:SetScript("OnUpdate", Handler)
    Handler()
  end)
  transferButton:SetScript("OnLeave", function()
    transferButton:SetScript("OnUpdate", nil)
  end)
  transferButton:SetScript("OnHide", function()
    transferButton:SetScript("OnUpdate", nil)
  end)
  return transferButton
end

local function GetCurrencyID(currencyName)
  for index = 1, C_CurrencyInfo.GetCurrencyListSize() do
    index = index + 1
    local info = C_CurrencyInfo.GetCurrencyListInfo(index)
    if info.isHeader then
      if not info.isHeaderExpanded then
        C_CurrencyInfo.ExpandCurrencyList(index, true)
      end
    else
      local link = C_CurrencyInfo.GetCurrencyListLink(index)
      if link ~= nil then
        local currencyID = C_CurrencyInfo.GetCurrencyIDFromLink(link)
        if info.name == currencyName then
          return currencyID
        end
      end
    end
  end
end

EventUtil.ContinueAfterAllEvents(function()
  local transferButton = GetTransferButton()
  transferButton:SetNormalTexture("warbands-transferable-icon")
  transferButton:HookScript("OnClick", function(_, _, isDown)
    if not isDown then
      C_Timer.After(0.25, function()
        transferButton:Hide()
      end)
    end
  end)

  local confirmationDialog
  do
    local dialog = CreateFrame("Frame", "BaganatorCustomiseDialogCategoriesImportDialog", UIParent)
    dialog:SetToplevel(true)
    table.insert(UISpecialFrames, "BaganatorCustomiseDialogCategoriesImportDialog")
    dialog:SetPoint("TOP", 0, -135)
    dialog:EnableMouse(true)
    dialog:SetFrameStrata("DIALOG")

    dialog.NineSlice = CreateFrame("Frame", nil, dialog, "NineSlicePanelTemplate")
    NineSliceUtil.ApplyLayoutByName(dialog.NineSlice, "Dialog", dialog.NineSlice:GetFrameLayoutTextureKit())

    local bg = dialog:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetColorTexture(0, 0, 0, 0.8)
    bg:SetPoint("TOPLEFT", 11, -11)
    bg:SetPoint("BOTTOMRIGHT", -11, 11)

    dialog:SetSize(500, 110)

    dialog.text = dialog:CreateFontString(nil, nil, "GameFontHighlight")
    dialog.text:SetText("You will lose X")
    dialog.text:SetPoint("TOP", 0, -30)
    dialog.transferButton = GetTransferButton("UIPanelDynamicResizeButtonTemplate")
    dialog.transferButton:SetText("Transfer")
    dialog.transferButton:SetParent(dialog)
    dialog.transferButton:HookScript("OnClick", function(_, _, isDown)
      if not isDown then
        dialog:Hide()
      end
    end)
    DynamicResizeButton_Resize(dialog.transferButton)
    dialog.transferButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -20, 30)
    dialog.cancelButton = CreateFrame("Button", nil, dialog, "UIPanelDynamicResizeButtonTemplate")
    dialog.cancelButton:SetText("Cancel")
    dialog.cancelButton:SetScript("OnClick", function()
      dialog:Hide()
    end)
    DynamicResizeButton_Resize(dialog.cancelButton)
    dialog.cancelButton:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 20, 30)
    confirmationDialog = dialog
  end

  local lossyTransferButton = CreateFrame("Button", nil, UIParent)
  lossyTransferButton:SetScript("OnClick", function()
    confirmationDialog:Show()
  end)
  lossyTransferButton:SetNormalTexture("warbands-transferable-icon")

  for _, button in ipairs({transferButton, lossyTransferButton}) do
    button:HookScript("OnEnter", function()
      GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
      button.UpdateTooltip()
    end)
    button.UpdateTooltip = function()
      GameTooltip:SetMerchantItem(button.index)
      GameTooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode("<Click to start transferring required currency>"))
      GameTooltip:Show()
    end
    button:HookScript("OnLeave", function()
      GameTooltip:Hide()
      button:Hide()
    end)
    button:HookScript("OnHide", function()
      button:Hide()
    end)
  end

  for i = 1, 10 do
    local itemButton = _G["MerchantItem" .. i .. "ItemButton"]
    itemButton:HookScript("OnEnter", function()
      local index = itemButton:GetID()
      if not CanAffordMerchantItem(index) then
        local count = GetMerchantItemCostInfo(index)
        for j = 1, count do
          local _, quantity, _, name = GetMerchantItemCostItem(index, j)
          if name ~= nil then
            local currencyID = GetCurrencyID(name)
            if currencyID then
              local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
              if info.quantity < quantity and info.isAccountTransferable then
                transferButton.currencyID = currencyID
                confirmationDialog.transferButton.currencyID = currencyID
                local button
                if info.transferPercentage == 100 then
                  button = transferButton
                else
                  button = lossyTransferButton
                  confirmationDialog.text:SetText("You will lose " .. (100 - info.transferPercentage) .. "% on transfer")
                end
                button.index = index
                button:Show()
                button:SetFrameStrata("DIALOG")
                button:SetAllPoints(itemButton)
                local merchantItemInfo = C_MerchantFrame.GetItemInfo(index)
                if merchantItemInfo.isUsable and merchantItemInfo.isPurchasable then
                  button:GetNormalTexture():SetDesaturated(false)
                else
                  button:GetNormalTexture():SetDesaturated(true)
                end
                break
              end
            end
          end
        end
      end
    end)
  end
  C_CurrencyInfo.RequestCurrencyDataForAccountCharacters()
end, "PLAYER_LOGIN")
