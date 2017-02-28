--[[
Usage:
local Rdamage = getdmg("R",target,source,3)
-------------------------------------------------------
params:
getdmg("SKILL",target,source,stagedmg,spelllvl)
]]

local DamageReductionTable = {
  ["Braum"] = {buff = "BraumShieldRaise", amount = function(target) return 1 - ({0.3, 0.325, 0.35, 0.375, 0.4})[target:GetSpellData(_E).level] end},
  ["Urgot"] = {buff = "urgotswapdef", amount = function(target) return 1 - ({0.3, 0.4, 0.5})[target:GetSpellData(_R).level] end},
  ["Alistar"] = {buff = "Ferocious Howl", amount = function(target) return ({0.5, 0.4, 0.3})[target:GetSpellData(_R).level] end},
  ["Amumu"] = {buff = "Tantrum", amount = function(target) return ({2, 4, 6, 8, 10})[target:GetSpellData(_E).level] end, damageType = 1},
  ["Galio"] = {buff = "GalioIdolOfDurand", amount = function(target) return 0.5 end},
  ["Garen"] = {buff = "GarenW", amount = function(target) return 0.7 end},
  ["Gragas"] = {buff = "GragasWSelf", amount = function(target) return ({0.1, 0.12, 0.14, 0.16, 0.18})[target:GetSpellData(_W).level] end},
  ["Annie"] = {buff = "MoltenShield", amount = function(target) return 1 - ({0.16,0.22,0.28,0.34,0.4})[target:GetSpellData(_E).level] end},
  ["Malzahar"] = {buff = "malzaharpassiveshield", amount = function(target) return 0.1 end}
}

function GetPercentHP(unit)
  return 100 * unit.health / unit.maxHealth
end

function string.ends(String,End)
  return End == "" or string.sub(String,-string.len(End)) == End
end

function GetItemSlot(unit, id)
  for i = ITEM_1, ITEM_7 do
    if unit:GetItemData(i).itemID == id then
      return i
    end
  end
  return 0
end

function GotBuff(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff.count
    end
  end
  return 0
end

function GetBuffData(unit, buffname)
  for i = 0, unit.buffCount do
    local buff = unit:GetBuff(i)
    if buff.name == buffname and buff.count > 0 then 
      return buff
    end
  end
  return {type = 0, name = "", startTime = 0, expireTime = 0, duration = 0, stacks = 0, count = 0}
end

function CalcPhysicalDamage(source, target, amount)
  local ArmorPenPercent = source.armorPenPercent
  local ArmorPenFlat = (0.4 + target.levelData.lvl / 30) * source.armorPen
  local BonusArmorPen = source.bonusArmorPenPercent

  if source.type == Obj_AI_Minion then
    ArmorPenPercent = 1
    ArmorPenFlat = 0
    BonusArmorPen = 1
  elseif source.type == Obj_AI_Turret then
    ArmorPenFlat = 0
    BonusArmorPen = 1
    if source.charName:find("3") or source.charName:find("4") then
      ArmorPenPercent = 0.25
    else
      ArmorPenPercent = 0.7
    end
  end

  if source.type == Obj_AI_Turret then
    if target.type == Obj_AI_Minion then
      amount = amount * 1.25
      if string.ends(target.charName, "MinionSiege") then
        amount = amount * 0.7
      end
      return amount
    end
  end

  local armor = target.armor
  local bonusArmor = target.bonusArmor
  local value = 100 / (100 + (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat)

  if armor < 0 then
    value = 2 - 100 / (100 - armor)
  elseif (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat < 0 then
    value = 1
  end
  return math.max(0, math.floor(DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 1)))
end

function CalcMagicalDamage(source, target, amount)
  local mr = target.magicResist
  local value = 100 / (100 + (mr * source.magicPenPercent) - source.magicPen)

  if mr < 0 then
    value = 2 - 100 / (100 - mr)
  elseif (mr * source.magicPenPercent) - source.magicPen < 0 then
    value = 1
  end
  return math.max(0, math.floor(DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 2)))
end

function DamageReductionMod(source,target,amount,DamageType)
  if source.type == Obj_AI_Hero then
    if GotBuff(source, "Exhaust") > 0 then
      amount = amount * 0.6
    end
  end

  if target.type == Obj_AI_Hero then

    for i = 0, target.buffCount do
      if target:GetBuff(i).count > 0 then
        local buff = target:GetBuff(i)
        if buff.name == "MasteryWardenOfTheDawn" then
          amount = amount * (1 - (0.06 * buff.count))
        end
    
        if DamageReductionTable[target.charName] then
          if buff.name == DamageReductionTable[target.charName].buff and (not DamageReductionTable[target.charName].damagetype or DamageReductionTable[target.charName].damagetype == DamageType) then
            amount = amount * DamageReductionTable[target.charName].amount(target)
          end
        end

        if target.charName == "Maokai" and source.type ~= Obj_AI_Turret then
          if buff.name == "MaokaiDrainDefense" then
            amount = amount * 0.8
          end
        end

        if target.charName == "MasterYi" then
          if buff.name == "Meditate" then
            amount = amount - amount * ({0.5, 0.55, 0.6, 0.65, 0.7})[target:GetSpellData(_W).level] / (source.type == Obj_AI_Turret and 2 or 1)
          end
        end
      end
    end

    if GetItemSlot(target, 1054) > 0 then
      amount = amount - 8
    end

    if target.charName == "Kassadin" and DamageType == 2 then
      amount = amount * 0.85
    end
  end

  return amount
end

function PassivePercentMod(source, target, amount, damageType)
  local SiegeMinionList = {"Red_Minion_MechCannon", "Blue_Minion_MechCannon"}
  local NormalMinionList = {"Red_Minion_Wizard", "Blue_Minion_Wizard", "Red_Minion_Basic", "Blue_Minion_Basic"}

  if source.type == Obj_AI_Turret then
    if table.contains(SiegeMinionList, target.charName) then
      amount = amount * 0.7
    elseif table.contains(NormalMinionList, target.charName) then
      amount = amount * 1.14285714285714
    end
  end
  if source.type == Obj_AI_Hero then 
    if target.type == Obj_AI_Hero then
      if (GetItemSlot(source, 3036) > 0 or GetItemSlot(source, 3034) > 0) and source.maxHealth < target.maxHealth and damageType == 1 then
        amount = amount * (1 + math.min(target.maxHealth - source.maxHealth, 500) / 50 * (GetItemSlot(source, 3036) > 0 and 0.015 or 0.01))
      end
    end
  end
  return amount
end

local DamageLibTable = {
  ["Aatrox"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.6 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 110, 145, 180, 215})[level] + 0.6 * source.ap + 0.6 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + source.ap end},
  },

  ["Ahri"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.35 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 3, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.35 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({12, 19.5, 27, 34.5, 42})[level] + 0.12 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.50 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150})[level] + 0.3 * source.ap end},
  },

  ["Akali"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({35, 55, 75, 95, 115})[level] + 0.4 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({45, 70, 95, 120, 145})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 0.6 * source.ap + 0.8 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 100, 150})[level] + 0.35 * source.ap end},
  },

  ["Alistar"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 110, 165, 220, 275})[level] + 0.7 * source.ap end},
  },

  ["Amumu"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({8, 12, 16, 20, 24})[level] + (({0.01, 0.015, 0.02, 0.025, 0.03})[level] + 0.01 * source.ap / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 100, 125, 150, 175})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.8 * source.ap end},
  },

  ["Anivia"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.4 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] * 2 + source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({50, 75, 100, 125, 150})[level] + 0.5 * source.ap) * (GotBuff(target, "chilled") and 2 or 1) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80})[level] + 0.125 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({120, 180, 240})[level] + 0.375 * source.ap end},
  },

  ["Annie"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.8 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.85 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({210, 365, 520})[level] + 0.9 * source.ap end},
  },

  ["Ashe"] = {
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 425, 600})[level] + source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({200, 400, 600})[level] + source.ap) / 2 end},
  },

  ["AurelionSol"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.65 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },
  
  ["Azir"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 85, 105, 125, 145})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 60, 75, 80, 90})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.6 * source.ap end},
  },

  ["Blitzcrank"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 375, 500})[level] + source.ap end},
  },

  ["Bard"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.65 * source.ap end},
  },

  ["Brand"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.55 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 120, 165, 210, 255})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 90, 110, 130, 150})[level] + 0.35 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.25 * source.ap end},
  },

  ["Braum"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.025 * source.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.6 * source.ap end},
  },

  ["Caitlyn"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 70, 110, 150, 190})[level] + ({1.3, 1.4, 1.5, 1.6, 1.7})[level] * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({250, 475, 700})[level] + 2 * source.totalDamage end},
  },

  ["Cassiopeia"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 120, 165, 210, 255})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + 0.15 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return 48 + 4 * source.levelData.lvl + 0.1 * source.ap + (target.isPoisoned and ({10, 40, 70, 100, 130})[level] + 0.35 * source.ap or 0) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.5 * source.ap end},
  },

  ["Chogath"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 305})[level] + source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 125, 175, 225, 275})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({300, 475, 650})[level] + 0.5 * source.ap end},
  },

  ["Corki"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 150, 205, 250})[level] + 0.5 * source.ap + 0.5 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Stage = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + (1.5 * source.totalDamage) + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 32, 44, 56, 68})[level] + 0.4 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 100, 125})[level] + 0.2 * source.ap + ({0.15, 0.45, 0.75})[level] * source.totalDamage end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({150, 200, 250})[level] + 0.4 * source.ap + ({0.3, 0.90, 1.5})[level] * source.totalDamage end},
  },

  ["Darius"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + (({0.5, 1.1, 1.2, 1.3, 1.4})[level] * source.totalDamage) end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.4 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({100, 200, 300})[level] + 0.75 * source.totalDamage end},
  },

  ["Diana"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({22, 34, 46, 58, 70})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 160, 220})[level] + 0.6 * source.ap end},
  },

  ["DrMundo"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) if target.type == Obj_AI_Minion then return math.min(({300, 350, 400, 450, 500})[level],math.max(({80, 130, 180, 230, 280})[level], ({15, 17.5, 20, 22.5, 25})[level] / 100 * target.health)) end; return math.max(({80, 130, 180, 230, 280})[level],({15, 17.5, 20, 22.5, 25})[level] / 100 * target.health) end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({35, 50, 65, 80, 95})[level] + 0.2 * source.ap end}
  },

  ["Draven"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 35, 40, 45, 50})[level] + ({65, 75, 85, 95, 105})[level] / 100 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.5 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({175, 275, 375})[level] + 1.1 * source.totalDamage end},
  },

  ["Ekko"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 75, 90, 105, 120})[level] + 0.3 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 195, 240, 285, 330})[level] + 0.8 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 300, 450})[level] + 1.5 * source.ap end}
  },

  ["Elise"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + (0.08 + 0.03 / 100 * source.ap) * target.health end},
    {Slot = "QM", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + (0.08 + 0.03 / 100 * source.ap) * (target.maxHealth - target.health) end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 125, 175, 225, 275})[level] + 0.8 * source.ap end},
  },

  ["Evelynn"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 50, 60, 70, 80})[level] + ({35, 40, 45, 50, 55})[level] / 100 * source.ap + ({50, 55, 60, 65, 70})[level] / 100 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + source.ap + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({0.15, 0.20, 0.25})[level] + 0.01 / 100 * source.ap) * target.health end},
  },

  ["Ezreal"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({35, 55, 75, 95, 115})[level] + 0.4 * source.ap + 1.1 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.8 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 125, 175, 225, 275})[level] + 0.75 * source.ap + 0.5 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({350, 500, 650})[level] + 0.9 * source.ap + source.totalDamage end},
  },

  ["Fiddlesticks"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 105, 130, 155, 180})[level] + 0.45 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 85, 105, 125, 145})[level] + 0.45 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({125, 225, 325})[level] + 0.45 * source.ap end},
  },

  ["Fiora"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 75, 85, 95, 105})[level] + ({0.95, 1, 1.05, 1.1, 1.15})[level] * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 130, 170, 210, 250})[level] + source.ap end},
  },

  ["Fizz"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 25, 40, 55, 70})[level] + 0.35 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + 0.75 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({225, 325, 425})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 3, DamageType = 2, Damage = function(source, target, level) return ({300, 400, 500})[level] + 1.2 * source.ap end},
  },

  ["Galio"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({360, 540, 720})[level] + source.ap end},
  },

  ["Gangplank"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({35, 60, 85})[level] + 0.1 * source.ap end},
  },

  ["Garen"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 55, 80, 105, 130})[level] + 1.4 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 45, 70, 95, 120})[level] + ({70, 80, 90, 100, 110})[level] / 100 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({175, 350, 525})[level] + ({28.57, 33.33, 40})[level] / 100 * (target.maxHealth - target.health) end},
  },

  ["Gnar"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({5, 35, 65, 95, 125})[level] + 1.15 * source.totalDamage end},
    {Slot = "QM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({5, 45, 85, 125, 165})[level] + 1.2 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 20, 30, 40, 50})[level] + source.ap + ({6, 8, 10, 12, 14})[level] / 100 * target.maxHealth end},
    {Slot = "WM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({25, 45, 65, 85, 105})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 60, 100, 140, 180})[level] + source.maxHealth * 0.06 end},
    {Slot = "EM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({20, 60, 100, 140, 180})[level] + source.maxHealth * 0.06 end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 300, 400})[level] + 0.5 * source.ap + 0.2 * source.totalDamage end},
  },

  ["Gragas"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 50, 80, 110, 140})[level] + 8 / 100 * target.maxHealth + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + 0.7 * source.ap end},
  },

  ["Graves"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 70, 85, 100, 115})[level] + 0.75 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + ({0.4, 0.6, 0.8, 1, 1.2})[level] * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({250, 400, 550})[level] + 1.5 * source.totalDamage end},
  },

  ["Hecarim"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 85, 120, 155, 190})[level] + 0.6 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 30, 40, 50, 60})[level] + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + 0.5 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + source.ap end},
  },

  ["Heimerdinger"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.45 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({135, 180, 225})[source:GetSpellData(_R).level] + 0.45 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({150, 200, 250})[source:GetSpellData(_R).level] + 0.6 * source.ap end},
  },

  ["Irelia"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 50, 80, 110, 140})[level] + 1.2 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({15, 30, 45, 60, 75})[level] end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 120, 160})[level] + 0.5 * source.ap + 0.7 * source.totalDamage end},
  },

  ["Janna"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 85, 110, 135, 160})[level] + 0.35 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 115, 170, 225, 280})[level] + 0.5 * source.ap end},
  },

  ["JarvanIV"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 1.2 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 325, 450})[level] + 1.5 * source.totalDamage end},
  },

  ["Jax"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + source.totalDamage + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + 0.5 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 160, 220})[level] + 0.7 * source.ap end},
  },

  ["Jayce"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 120, 170, 220, 270, 320})[level] + 1.2 * source.totalDamage end},
    {Slot = "QM", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({35, 70, 105, 140, 175, 210})[level] + source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85, 100})[level] + 0.25 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({8, 10.4, 12.8, 15.2, 17.6, 20})[level] / 100) * target.maxHealth + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 60, 100, 140})[level] + 0.25 * source.bonusDamage end},
  },

  ["Jhin"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + ({0.3, 0.35, 0.4, 0.45, 0.5})[level] * source.totalDamage + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 85, 120, 155, 190})[level] + 0.5 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 80, 140, 200, 260})[level] + 1.20 * source.totalDamage + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 100, 160})[level] + 0.2 * source.totalDamage * (1 + (100 - GetPercentHP(target)) * 1.025) end},
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({40, 100, 160})[level] + 0.2 * source.totalDamage * (1 + (100 - GetPercentHP(target)) * 1.025) * 2 end}, -- GetCritDamage..
  },

  ["Jinx"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.1 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 60, 110, 160, 210})[level] + 1.4 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 35, 45})[level] + ({25, 30, 35})[level] / 100 * (target.maxHealth - target.health) + 0.15 * source.totalDamage end},
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({250, 350, 450})[level] + ({25, 30, 35})[level] / 100 * (target.maxHealth - target.health) + 1.5 * source.totalDamage end},
  },

  ["Karma"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.6 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + ({25, 75, 125, 175})[source:GetSpellData(_R).level] + 0.9 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.9 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.9 * source.ap end},
  },

  ["Karthus"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({40, 60, 80, 100, 120})[level] + 0.3 * source.ap) * 2 end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 50, 70, 90, 110})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 400, 550})[level] + 0.6 * source.ap end},
  },

  ["Kassadin"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 95, 125, 155, 185})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return 20 + 0.1 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 105, 130, 155, 180})[level] + 0.7 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 100, 120})[level] + 0.02 * source.maxMana end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({40, 50, 60})[level] + 0.01 * source.maxMana end},
  },

  ["Katarina"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 105, 135, 165, 195})[level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + 0.25 * source.ap + 0.5 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 37.5, 50})[level] + 0.22 * source.bonusDamage + 0.19 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({375, 562.5, 750})[level] + 3.3 * source.bonusDamage + 2.85 * source.ap end},
  },

  ["Kayle"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + source.totalDamage + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return source.range > 500 and ({20, 30, 40, 50, 60})[level] + 0.30 * source.ap or ({10, 15, 20, 25, 30})[level] + 0.15 * source.ap end},
  },

  ["Kennen"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 115, 155, 195, 235})[level] + 0.75 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 50, 60, 70, 80})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({65, 95, 125, 155, 185})[level] + 0.55 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({85, 125, 165, 205, 245})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110})[level] + 0.2 * source.ap end},
  },

  ["Khazix"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 1.2 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({105, 142.5, 180, 217.5, 255})[level] + 1.56 * source.totalDamage end},
    {Slot = "Q", Stage = 3, DamageType = 1, Damage = function(source, target, level) return ({70, 95, 120, 145, 170})[level] + 2.24 * source.totalDamage + 10 * source.levelData.lvl end},
    {Slot = "Q", Stage = 4, DamageType = 1, Damage = function(source, target, level) return ({105, 142.5, 180, 217.5, 255})[level] + 2.6 * source.totalDamage + 10 * source.levelData.lvl end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 100, 135, 170, 205})[level] + 0.2 * source.totalDamage end},
  },

  ["Kogmaw"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) local dmg = (({0.03, 0.04, 0.05, 0.06, 0.07})[level] + (0.01*source.ap)) * target.maxHealth ; if target.type == Obj_AI_Minion and dmg > 100 then dmg = 100 end ; return dmg end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({100, 140, 180})[level] + 0.65 * source.totalDamage + 0.25 * source.ap) * (GetPercentHP(target) < 25 and 3 or (GetPercentHP(target) < 50 and 2 or 1)) end},
  },

  ["Kalista"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 70, 130, 190, 250})[level] + source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({12, 14, 16, 18, 20})[level] / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) local count = GotBuff(target, "kalistaexpungemarker") if count > 0 then return (({20, 30, 40, 50, 60})[level] + 0.6* (source.totalDamage)) + ((count - 1)*(({10, 14, 19, 25, 32})[level]+({0.2, 0.225, 0.25, 0.275, 0.3})[level] * (source.totalDamage))) end; return 0 end},
  },

  ["Kindred"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({55, 75, 95, 115, 135})[level] + source.totalDamage * 0.2 end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 30, 35, 40, 45})[level] + source.totalDamage * 0.4 end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + source.totalDamage * 0.2 + target.maxHealth * 0.05 end},
  },

  ["Leblanc"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 90, 125, 160, 195})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({85, 125, 165, 205, 245})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + 0.5 * source.ap end},
  },

  ["LeeSin"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.9 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.9 * source.totalDamage + 0.08 * (target.maxHealth - target.health) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 300, 450})[level] + 2 * source.totalDamage end},
  },

  ["Leona"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 55, 80, 105, 130})[level] + 0.3 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 175, 250})[level] + 0.8 * source.ap end},
  },

  ["Lissandra"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },

  ["Lucian"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + ({0.6, 0.7, 0.8, 0.9, 1})[level] * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.9 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 50, 60})[level] + 0.1 * source.ap + 0.25 * source.totalDamage end},
  },

  ["Lulu"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.4 * source.ap end},
  },

  ["Lux"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 100, 150, 200, 250})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 400, 500})[level] + 0.75 * source.ap end},
  },

  ["Malphite"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 120, 170, 220, 270})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 38, 46, 54, 62})[level] / 100 * source.totalDamage + 0.15 * source.bonusArmor end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.3 * source.armor + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 300, 400})[level] + source.ap end},
  },

  ["Malzahar"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({4, 4.5, 5, 5.5, 6})[level] / 100 + 0.01 / 100 * source.ap) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.7 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return 2.5 * (({6, 8, 10})[level] / 100 + 0.015 * source.ap / 100) * target.maxHealth end},
  },

  ["Maokai"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({9, 10, 11, 12, 13})[level] / 100 + 0.03 / 100 * source.ap) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 150, 200})[level] + 0.5 * source.ap end},
  },

  ["MasterYi"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 60, 95, 130, 165})[level] + source.totalDamage + 0.6 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({10, 12.5, 15, 17.5, 20})[level] / 100 * source.totalDamage + ({14, 23, 32, 41, 50})[level] end},
  },

  ["MissFortune"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + 0.35 * source.ap + 0.85 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.5 * source.ap + source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return 0.06 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 115, 150, 185, 220})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return 0.75 * source.totalDamage + 0.2 * source.ap end},
  },

  ["MonkeyKing"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] + 0.1 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.8 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 110, 200})[level] + 1.1 * source.totalDamage end},
  },

  ["Mordekaiser"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + source.totalDamage + 0.4 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({24, 38, 52, 66, 80})[level] + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({24, 29, 34})[level] / 100 + 0.04 / 100 * source.ap) * target.maxHealth end},
  },

  ["Morgana"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 135, 190, 245, 300})[level] + 0.9 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({8, 16, 24, 32, 40})[level] + 0.11 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.7 * source.ap end},
  },

  ["Nami"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 130, 185, 240, 295})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({25, 40, 55, 70, 85})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.6 * source.ap end},
  },

  ["Nasus"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return GetBuffData(source, "nasusqstacks").Stacks + ({30, 50, 70, 90, 110})[level] end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 95, 135, 175, 215})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({11, 19, 27, 35, 43})[level] + 0.12 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({3, 4, 5})[level] / 100 + 0.01 / 100 * source.ap) * target.maxHealth end},
  },

  ["Nautilus"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.75 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 40, 50, 60, 70})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 325, 450})[level] + 0.8 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({125, 175, 225})[level] + 0.4 * source.ap end},
  },

  ["Nidalee"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 85, 100, 115, 130})[level] + 0.4 * source.ap end},
    {Slot = "QM", Stage = 2, DamageType = 2, Damage = function(source, target, level) local dmg = (({5, 30, 55, 80})[source:GetSpellData(_R).level] + 0.4 * source.ap + 0.75 * source.totalDamage) * ((target.maxHealth - target.health) / target.maxHealth * 1.5 + 1) dmg = dmg * (GotBuff(target, "nidaleepassivehunted") > 0 and 1.4 or 1) return dmg end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 80, 120, 160, 200})[level] + 0.2 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210})[source:GetSpellData(_R).level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({70, 130, 190, 250})[source:GetSpellData(_R).level] + 0.45 * source.ap end},
  },

  ["Nocturne"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.75 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 260})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 250, 350})[level] + 1.2 * source.totalDamage end},
  },

  ["Nunu"] = {
    {Slot = "Q", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({400, 550, 700, 850, 1000})[level] end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({85, 130, 175, 225, 275})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({625, 875, 1125})[level] + 2.5 * source.ap end},
  },

  ["Olaf"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.55 * source.bonusDamage end},
    {Slot = "E", Stage = 1, DamageType = 3, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.4 * source.totalDamage end},
  },

  ["Orianna"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 225, 300})[level] + 0.7 * source.ap end},
  },

  ["Pantheon"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({65, 105, 145, 185, 225})[level] + 1.4 * source.totalDamage) * ((target.health / target.maxHealth < 0.15) and 2 or 1) end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({13, 23, 33, 43, 53})[level] + 0.6 * source.totalDamage) * ((target.type == Obj_AI_Hero) and 2 or 1) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({400, 700, 1000})[level] + source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({400, 700, 1000})[level] + source.ap) * 0.5 end},
  },

  ["Poppy"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({35, 55, 75, 95, 115})[level] + 0.80 * source.totalDamage + 0.07 * target.maxHealth end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 1.6 * source.totalDamage + 0.14 * target.maxHealth end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 70, 90, 110, 130})[level] + 0.5 * source.totalDamage end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({100, 140, 180, 220, 260})[level] + source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({100, 150, 200})[level] + 0.45 * source.bonusDamage end},
  },

  ["Quinn"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) local damage = (({20, 45, 70, 95, 120})[level] + ({0.8, 0.9, 1.0, 1.1, 1.2})[level] * source.totalDamage) + 0.35 * source.ap ; damage = damage + damage * ((100 - GetPercentHP(target)) / 100) ; return damage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.2 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return source.totalDamage end},
  },

  ["Rammus"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 150, 200, 250, 300})[level] + source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({15, 25, 35, 45, 55})[level] + 0.1 * source.armor end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 130, 195})[level] + 0.3 * source.ap end},
  },

  ["Renekton"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.8 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.8 * source.totalDamage * 1.5 end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 30, 50, 70, 90})[level] + 1.5 * source.totalDamage end},
    {Slot = "W", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({10, 30, 50, 70, 90})[level] + 1.5 * source.totalDamage * 1.5 end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] + 0.9 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] + 0.9 * source.totalDamage * 1.5 end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 80, 120})[level] + 0.1 * source.ap end},
  },

  ["Rengar"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + ({30, 40, 50, 60, 70})[level] / 100 * source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({60, 68, 76, 82, 88, 94, 100, 108, 116, 124, 132, 140, 148, 156, 164, 172, 180, 188, 196})[source.levelData.lvl] + 1.1 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + 0.8 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 100, 150, 200, 250})[level] + 0.7 * source.totalDamage end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({50, 65, 80, 95, 110, 125, 140, 155, 170, 185, 200, 215, 230, 245, 260, 275, 290, 305})[source.levelData.lvl] + 0.7 * source.totalDamage end},
  },

  ["Riven"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 30, 50, 70, 90})[level] + (source.totalDamage / 100) * ({40, 45, 50, 55, 60})[level] end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({100, 150, 200})[level] + 0.6 * source.bonusDamage) * math.max(0.04 * math.min(100 - GetPercentHP(target), 75), 1) end},
  },

  ["Rumble"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 135, 195, 255, 315})[level] + source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({112.5, 202.5, 292.5, 382.5, 472.5})[level] + 1.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({45, 70, 95, 120, 145})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({67.5, 105, 142.5, 180, 217.5})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({130, 185, 240})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({650, 925, 1200})[level] + 1.5 * source.ap end},
  },

  ["Ryze"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({60, 85, 110, 135, 160, 185})[level] + 0.45 * source.ap + 0.03 * source.maxMana) * (1 + (GotBuff(target, "RyzeE") > 0 and ({40, 55, 70, 85, 100, 100})[level] / 100 or 0)) end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 100, 120, 140, 160})[level] + 0.2 * source.ap + 0.01 * source.maxMana end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + 0.3 * source.ap + 0.02 * source.maxMana end},
  },

  ["Sejuani"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({4, 4.5, 5, 5.5, 6})[level] / 100 * target.maxHealth end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({10, 17.5, 25, 32.5, 40})[level] + (({4, 6, 8, 10, 12})[level] / 100) * source.maxHealth + 0.15 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.8 * source.ap end},
  },

  ["Shaco"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 35, 50, 65, 80})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({35, 50, 65, 80, 95})[level] + 0.2 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({5, 35, 65, 95, 125})[level] + ({3, 4, 5, 6, 7, 8})[level] / 100 * (target.maxHealth - target.health) + 0.9 * source.ap + 0.85 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 450, 600})[level] + source.ap end},
  },

  ["Shen"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) local dmg = (({2, 2.5, 3, 3.5, 4})[level] + 0.015 * source.ap) * target.maxHealth / 100; if target.type == Obj_AI_Hero then return dmg end; return math.min(({30, 50, 70, 90, 110})[level]+dmg, ({75, 100, 125, 150, 175})[level]) end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) local dmg = (({4, 4.5, 5, 5.5, 6})[level] + 0.02 * source.ap) * target.maxHealth / 100; if target.type == Obj_AI_Hero then return dmg end; return math.min(({30, 50, 70, 90, 110})[level]+dmg, ({75, 100, 125, 150, 175})[level]) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 85, 120, 155, 190})[level] + 0.5 * source.ap end},
  },

  ["Shyvana"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 85, 90, 95, 100})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({20, 32, 45, 57, 70})[level] + 0.2 * source.totalDamage + 0.1 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 100, 140, 180, 220})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },

  ["Singed"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({22, 34, 46, 58, 70})[level] + 0.3 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 65, 80, 95, 110})[level] + 0.75 * source.ap + ({4, 5.5, 7, 8.5, 10})[level] / 100 * target.maxHealth end},
  },

  ["Sion"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + 0.6 * source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({60, 120, 180, 240, 300})[level] + 1.8 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.4 * source.ap + ({10, 11, 12, 13, 14})[level] / 100 * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({70, 105, 140, 175, 210})[level] + 0.4 * source.ap) * 1.5 end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 300, 450})[level] + 0.4 * source.totalDamage end},
    {Slot = "R", Stage = 2, DamageType = 1, Damage = function(source, target, level) return (({150, 300, 450})[level] + 0.4 * source.totalDamage) * 2 end},
  },

  ["Sivir"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({25, 45, 65, 85, 105})[level] + ({70, 80, 90, 100, 110})[level] / 100 * source.totalDamage + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 65, 70, 75, 80})[level] / 100 * source.totalDamage end},
  },

  ["Skarner"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 30, 40, 50, 60})[level] + 0.4 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 75, 110, 145, 180})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({20, 60, 100})[level] + 0.5 * source.ap) + (0.60 * source.totalDamage) end},
  },

  ["Sona"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.5 * source.ap end},
  },

  ["Soraka"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.35 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.4 * source.ap end},
  },

  ["Swain"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 47.5, 65, 82.5, 100})[level] + 0.3 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 80, 110, 140, 170})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 70, 90})[level] + 0.2 * source.ap end},
  },

  ["Syndra"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({50, 95, 140, 185, 230})[level] + 0.75 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 115, 160, 205, 250})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({270, 405, 540})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 135, 180})[level] + 0.2 * source.ap end},
  },

  ["Talon"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 100, 120, 140, 160})[level] + source.bonusDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({120, 150, 180, 210, 240})[level] + 1.5 * source.bonusDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 60, 70, 80, 90})[level] + 0.4 * source.bonusDamage end},
    {Slot = "W", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.7 * source.bonusDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({80, 120, 160})[level] + 0.8 * source.bonusDamage end},
  },

  ["Taliyah"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.4 * source.ap end},
    {Slot = "Q", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({180, 240, 300, 360, 420})[level] + 1.2 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 90, 110, 130, 150})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({160, 210, 260, 310, 360})[level] + 0.8 * source.ap end},
  },

  ["Taric"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 80, 120, 160, 200})[level] + 0.2 * source.armor end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 70, 100, 130, 160})[level] + 0.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.5 * source.ap end},
  },

  ["TahmKench"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.7 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return target.type == Obj_AI_Minion and ({400, 450, 500, 550, 600})[level] or (({0.20, 0.23, 0.26, 0.29, 0.32})[level] + 0.02 * source.ap / 100) * target.maxHealth end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({100, 150, 200, 250, 300})[level] + 0.6 * source.ap end},
  },


  ["Teemo"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 125, 170, 215, 260})[level] + 0.8 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({34, 68, 102, 136, 170})[level] + 0.7 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({10, 20, 30, 40, 50})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 325, 450})[level] + 0.5 * source.ap end},
  },

  ["Thresh"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({65, 95, 125, 155, 185})[level] + 0.4 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({250, 400, 550})[level] + source.ap end},
  },

  ["Tristana"] = {
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 110, 160, 210, 260})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({60, 70, 80, 90, 100})[level] + ({0.5, 0.65, 0.8, 0.95, 1.10})[level] * source.totalDamage + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 400, 500})[level] + source.ap end},
  },

  ["Trundle"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + ({0, 0.5, 0.1, 0.15, 0.2})[level] * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return (({20, 24, 28})[level] / 100 + 0.02 * source.ap / 100) * target.maxHealth end},
  },

  ["Tryndamere"] = {
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 1.2 * source.totalDamage + source.ap end},
  },

  ["TwistedFate"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 60, 80, 100, 120})[level] + source.totalDamage + 0.5 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + source.totalDamage + 0.5 * source.ap end},
    {Slot = "W", Stage = 3, DamageType = 2, Damage = function(source, target, level) return ({15, 22.5, 30, 37.5, 45})[level] + source.totalDamage + 0.5 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 80, 105, 130, 155})[level] + 0.5 * source.ap end},
  },

  ["Twitch"] = {
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (GotBuff(target, "twitchdeadlyvenom") * ({15, 20, 25, 30, 35})[level] + 0.2 * source.ap + 0.25 * source.totalDamage) + ({20, 35, 50, 65, 80})[level] end},
    {Slot = "E", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({15, 20, 25, 30, 35})[level] + 0.2 * source.ap + 0.25 * source.totalDamage + ({20, 35, 50, 65, 80})[level] end},
  },

  ["Udyr"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 80, 130, 180, 230})[level] + (({120, 130, 140, 150, 160})[level] / 100) * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 20, 30, 40, 50})[level] + 0.25 * source.ap end},

  },

  ["Urgot"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 40, 70, 100, 130})[level] + 0.85 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({75, 130, 185, 240, 295})[level] + 0.6 * source.totalDamage end},
  },

  ["Varus"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({10, 47, 83, 120, 157})[level] + source.totalDamage end},
    {Slot = "Q", Stage = 2, DamageType = 1, Damage = function(source, target, level) return ({15, 70, 125, 180, 235})[level] + 1.6 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({10, 14, 18, 22, 26})[level] + 0.25 * source.ap end},
    {Slot = "W", Stage = 2, DamageType = 2, Damage = function(source, target, level) return (({2, 2.75, 3.5, 4.25, 5})[level] / 100 + 0.02 * source.ap / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 100, 135, 170, 205})[level] + 0.6 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 175, 250})[level] + source.ap end},
  },

  ["Vayne"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 35, 40, 45, 50})[level] / 100 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 3, Damage = function(source, target, level) return math.max(({40, 60, 80, 100, 120})[level], (({6, 7.5, 9, 10.5, 12})[level] / 100) * target.maxHealth) end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({45, 80, 115, 150, 185})[level] + 0.5 * source.totalDamage end},
  },

  ["Veigar"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 150, 200, 250, 300})[level] + source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) local dmg = GetPercentHP(target) > 33.3 and ({175, 250, 325})[level] + 0.75 * source.ap or ({350, 500, 650})[level] + 1.5 * source.ap; return dmg+((0.015 * dmg) * (100 - ((target.health / target.maxHealth) * 100))) end},
  },

  ["Velkoz"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.6 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 50, 70, 90, 110})[level] + ({45, 75, 105, 135, 165})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 100, 130, 160, 190})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 3, Damage = function(source, target, level) return (GotBuff(target, "velkozresearchedstack") > 0 and ({450, 625, 800})[level] + 1.25* source.ap or CalcMagicalDamage(source, target, ({450, 625, 800})[level] + 1.25 * source.ap)) end},
  },

  ["Vi"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({50, 75, 100, 125, 150})[level] + 0.8 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({4, 5.5, 7, 8.5, 10})[level] / 100 + 0.01 * source.totalDamage / 35) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({5, 20, 35, 50, 65})[level] + 1.15 * source.totalDamage + 0.7 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({150, 300, 450})[level] + 1.4 * source.totalDamage end},
  },

  ["Viktor"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] + 0.4 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.5 * source.ap end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({90, 170, 250, 330, 410})[level] + 1.2 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({100, 175, 250})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.6 * source.ap end},
  },

  ["Vladimir"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 90, 105, 120, 135})[level] + 0.55 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 80, 100, 120, 140})[level] end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({30, 45, 60, 75, 90})[level] + 0.5 * source.ap + 0.3 * source.maxHealth end},
    {Slot = "E", Stage = 2, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + source.ap + 0.6 * source.maxHealth end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 0.7 * source.ap end},
  },

  ["Volibear"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] end},
    {Slot = "W", Stage = 1, DamageType = 1, Damage = function(source, target, level) return (({60, 110, 160, 210, 260})[level]) * ((target.maxHealth - target.health) / target.maxHealth + 1) end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 105, 150, 195, 240})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 115, 155})[level] + 0.3 * source.ap end},
  },

  ["Warwick"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return math.max(({75, 125, 175, 225, 275})[level],(({8, 10, 12, 14, 16})[level] / 100  * target.maxHealth) + source.ap) end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({150, 250, 350})[level] + 2 * source.totalDamage end},
  },

  ["Xerath"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 120, 160, 200, 240})[level] + 0.75 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 90, 120, 150, 180})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 110, 140, 170, 200})[level] + 0.45 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({200, 230, 260})[level] + 0.43 * source.ap end},
  },

  ["XinZhao"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({15, 30, 45, 60, 75})[level] + 0.2 * source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({75, 175, 275})[level] + source.totalDamage + 0.15 * target.health end},
  },

  ["Yasuo"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({20, 40, 60, 80, 100})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 70, 80, 90, 100})[level] + 0.2 * source.bonusDamage + 0.6 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({200, 300, 400})[level] + 1.5 * source.totalDamage end},
  },

  ["Yorick"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({30, 60, 90, 120, 150})[level] + 1.2 * source.totalDamage end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({55, 85, 115, 145, 175})[level] + source.totalDamage end},
  },

  ["Zac"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 110, 150, 190, 230})[level] + 0.5 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 55, 70, 85, 100})[level] + (({4, 5, 6, 7, 8})[level] / 100 + 0.02 * source.ap / 100) * target.maxHealth end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({80, 130, 180, 230, 280})[level] + 0.7 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({140, 210, 280})[level] + 0.4 * source.ap end},
  },

  ["Zed"] = {
    {Slot = "Q", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + source.totalDamage end},
    {Slot = "E", Stage = 1, DamageType = 1, Damage = function(source, target, level) return ({65, 90, 115, 140, 165})[level] + 0.8 * source.totalDamage end},
    {Slot = "R", Stage = 1, DamageType = 1, Damage = function(source, target, level) return source.totalDamage end},
  },

  ["Ziggs"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({75, 120, 165, 210, 255})[level] + 0.65 * source.ap end},
    {Slot = "W", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({70, 105, 140, 175, 210})[level] + 0.35 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({40, 65, 90, 115, 140})[level] + 0.3 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({300, 450, 600})[level] + 1.1 * source.ap end},
  },

  ["Zilean"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({90, 145, 200, 260, 320})[level] + 0.9 * source.ap end},
  },

  ["Zyra"] = {
    {Slot = "Q", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.6 * source.ap end},
    {Slot = "E", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({60, 95, 130, 165, 200})[level] + 0.5 * source.ap end},
    {Slot = "R", Stage = 1, DamageType = 2, Damage = function(source, target, level) return ({180, 265, 350})[level] + 0.7 * source.ap end},
  }

}


function getdmg(spell,target,source,stage,level)
  local source = source or myHero
  local stage = stage or 1
  local swagtable = {}
  local k = 0
  if stage > 4 then stage = 4 end
  if spell == "Q" or spell == "W" or spell == "E" or spell == "R" or spell == "QM" or spell == "WM" or spell == "EM" then
    local level = level or source:GetSpellData(({["Q"] = _Q, ["QM"] = _Q, ["W"] = _W, ["WM"] = _W, ["E"] = _E, ["EM"] = _E, ["R"] = _R})[spell]).level
    if level <= 0 then return 0 end
    if level > 5 then level = 5 end
    if DamageLibTable[source.charName] then
      for i, spells in pairs(DamageLibTable[source.charName]) do
        if spells.Slot == spell then
          table.insert(swagtable, spells)
        end
      end
      if stage > #swagtable then stage = #swagtable end
      for v = #swagtable, 1, -1 do
        local spells = swagtable[v]
        if spells.Stage == stage then
          if spells.DamageType == 1 then
            return CalcPhysicalDamage(source, target, spells.Damage(source, target, level))
          elseif spells.DamageType == 2 then
            return CalcMagicalDamage(source, target, spells.Damage(source, target, level))
          elseif spells.DamageType == 3 then
            return spells.Damage(source, target, level)
          end
        end
      end
    end
  end
  if spell == "AA" then
    return CalcPhysicalDamage(source, target, source.totalDamage)
  end
  if spell == "IGNITE" then
    return 50+20*source.levelData.lvl - (target.hpRegen*3)
  end
  if spell == "SMITE" then
    if Smite then
      if target.type == Obj_AI_Hero then
        if source:GetSpellData(Smite).name == "s5_summonersmiteplayerganker" then
          return 20+8*source.levelData.lvl
        end
        if source:GetSpellData(Smite).name == "s5_summonersmiteduel" then
          return 54+6*source.levelData.lvl
        end
      end
      return ({390, 410, 430, 450, 480, 510, 540, 570, 600, 640, 680, 720, 760, 800, 850, 900, 950, 1000})[source.levelData.lvl]
    end
  end
  if spell == "BILGEWATER" then
    return CalcMagicalDamage(source, target, 100)
  end
  if spell == "BOTRK" then
    return CalcPhysicalDamage(source, target, target.maxHealth*0.1)
  end
  if spell == "HEXTECH" then
    return CalcMagicalDamage(source, target, 150+0.4*source.ap)
  end
  return 0
end
