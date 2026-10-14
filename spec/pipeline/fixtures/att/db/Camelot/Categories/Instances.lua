-- Hand-written fixture in the upstream shape of db/Camelot/Categories/Instances.lua.
local appName, _ = ...
_.AddEventHandler("OnBuildDataCache", function(categories)
local e,h,i,inst,n,q,s,x=_.CreateEncounter,_.CreateCustomHeader,_.CreateItem,_.CreateInstance,_.CreateNPC,_.CreateQuest,_.CreateItemSource,_.CreateExpansion;
categories.Instances=h(-75,{g={
h(-318,{q(1,{g={s(900,9000,{})}})}),
inst(2959,{awp=16001,icon=_.asset("x"),OnTooltip=_.OnTooltipDB.Foo,zoneTextAreaID=16544,g={
h(-45,{q(500,{r=2,g={s(101,1001,{})}}),q(501,{r=1,g={s(101,1001,{})}})}),
h(-63,{s(102,1002,{})}),
h(-46,{e(3310)}),
e(3311,{npcID=247126,g={s(103,1003,{f=33}),s(104,1004,{c={8},lvl=20}),i(1005,{})}}),
n(4887,{g={s(105,1006,{})}}),
h(-58,{n(999,{g={s(106,1007,{})}})}),
e(3312,{g={s(107,1008,{u=2}),s(108,1009,{awp=20001}),s(109,1010,{rwp=10903})}}),
e(3313,{g={s(103,1003,{}),s(110,1011,{awp=100107,rwp=20001})}}),
}}),
x(1,{awp=10100,g={
inst(760,{isRaid=1,zoneTextAreaID=2159,mapID=248,maps={249,248},g={e(1084,{npcID=10184,g={s(201,2001,{})}})}}),
inst(742,{isRaid=1,zoneTextAreaIDs={2677},g={e(1529,{g={s(202,2002,{})}})}}),
inst(78789,{awp=16001,isRaid=1,g={}}),
}}),
}})
end)
