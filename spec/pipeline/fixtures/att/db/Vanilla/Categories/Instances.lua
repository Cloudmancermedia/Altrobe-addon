-- Hand-written fixture in the upstream shape of db/Vanilla/Categories/Instances.lua.
local appName, _ = ...
_.AddEventHandler("OnBuildDataCache", function(categories)
local e,h,inst,s,x=_.CreateEncounter,_.CreateCustomHeader,_.CreateInstance,_.CreateItemSource,_.CreateExpansion;
categories.Instances=h(-75,{g={x(1,{g={
inst(741,{isRaid=1,zoneTextAreaID=2717,maps={232},g={e(1519,{npcID=12118,g={s(301,3001,{b=1,c={9},lvl=60,q=4})}})}}),
inst(760,{isRaid=1,zoneTextAreaID=2159,g={e(1084,{g={s(999,9999,{q=4})}})}}),
}})}})
end)
