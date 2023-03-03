local mq = require('mq')

function ppReady()
    return mq.TLO.Me.AbilityReady("Fishing")()
end

local i

while(1) do
    mq.cmdf("/autoinventory")
    mq.cmdf('/exchange "fishing pole" mainhand')
    mq.cmdf('/doability "Fishing"')
    print("Fishing=",mq.TLO.Me.Skill("Fishing"))
    local j
    mq.delay("5s")
	while mq.TLO.Cursor.ID() do
        mq.cmdf("/autoinventory")
        mq.delay("1s")
    end
	mq.delay("100s", ppReady)
end