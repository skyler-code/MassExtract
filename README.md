Keybinds for MassExtract can be found in the AddOns category

Prospecting macro:
#showtooltip Prospecting
/click MassExtractProspecting
or
#showtooltip Prospecting
/run MassExtract:Setup("prospecting")
/click MassExtract


Milling macro:
#showtooltip Prospecting
/click MassExtractMilling
or
#showtooltip Milling
/run MassExtract:Setup("milling")
/click MassExtract


Lockpicking macro:
#showtooltip Prospecting
/click MassExtractPickLock
or
#showtooltip Pick Lock
/run MassExtract:Setup("pick lock")
/click MassExtract


Disenchanting macro:
#showtooltip Disenchant
/cast Disenchant
/click MassExtractDisenchant
or
#showtooltip Disenchant
/cast Disenchant
/run MassExtract:Setup("disenchant")
/click MassExtract


To localize you could do the following for prospecting:
#showtooltip Prospecting
/run MassExtract:Setup(GetSpellInfo(31252))
/click MassExtract
