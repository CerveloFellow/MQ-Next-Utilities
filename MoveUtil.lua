local mq = require('mq')

MoveUtil = { }

--[[
    Utility to move your character to a location or a target.

    This utility requires MQ2MoveUtils or MQ2Nav

    This will prioritize /nav over /moveto if /nav is available and meshes are loaded

    Sample propertiesTable setup:
        local testTarget = mq.TLO.Spawn("Merchant")
        local prop0 = { target=mq.TLO.Spawn("Merchant"), timeToWait="5s", arrivalDistance=15}
        local prop1 = { Y=-320, X=924, Z=-91, timeToWait="10s", arrivalDistance=25}
        local prop2 = { target=testTarget }

    Sample invocation
        local instance = MoveUtil.new(prop1)
        instance.moveToLocation()

        local instance = MoveUtil.new(prop0)
        instance.moveToTarget()
]]
function MoveUtil.new (propertiesTable)
    local self = {}
    local target
    local X
    local Y
    local Z
    local timeToWait
    local arrivalDistance

    if mq.TLO.Plugin("MQ2MoveUtils").IsLoaded() or mq.TLO.Plugin("MQ2Nav").IsLoaded() then
        self.target = propertiesTable.target
        self.X = propertiesTable.target==nil and propertiesTable.X or tonumber(tostring(propertiesTable.target.X))
        self.Y = propertiesTable.target==nil and propertiesTable.Y or tonumber(tostring(propertiesTable.target.Y))
        self.Z = propertiesTable.target==nil and propertiesTable.Z or tonumber(tostring(propertiesTable.target.Z))
        self.timeToWait = propertiesTable.timeToWait or "10s" --time to wait to get to destination before stopping
        self.arrivalDistance = propertiesTable.arrivalDistance or 15 --distance from target to be considered at your location
    else
        print("You do not have the required plugins loaded to use this module.")
    end

    -- The calback function for the mq.delay.  If you arrive at your destination before the time has elapsed 
    -- the delay will end and processing resumes.
    function moveCallback()
        return self.distanceFromDestination() <= tonumber(self.arrivalDistance)
    end

    -- Do you have one of the movement plugsins loaded required to use this?
    function self.pluginsLoaded()
        if mq.TLO.Plugin("MQ2MoveUtils").IsLoaded() or mq.TLO.Plugin("MQ2Nav").IsLoaded() then
            return true
        else
            return false
        end
    end

    -- Derives the distance to your destination
    function self.distanceFromDestination()
        if self.X ~= nil and self.Y ~= nil then
            return mq.TLO.Math.Distance(self.Y, self.X)()
        else
            return nil
        end
    end

    -- uses MQ2Nav to try and nav to a location
    function nav()
        mq.cmdf("/nav locxy %s %s", self.X, self.Y)

        -- Some interrupt logic here for the casting module if you're Casting and not a bard... not implementing this yet
        if mq.TLO.Me.Casting.ID() and mq.TLO.Me.Class.ShortName() ~= "BRD" then
            -- interrupt
        end

        mq.delay(string.format("%s",self.timeToWait), moveCallback)
        mq.cmdf("/nav stop")

        if not atDestion() then
            print(string.format("Unable to nav to destination within the time allocated(%s)", timeToWait))
        end
    end

    -- Am I within <arrivalDistance> of my destination?
    function atDestion()
        return self.distanceFromDestination() <= tonumber(self.arrivalDistance)
    end

    -- uses MQ2MoveUtils to try and move to a location
    function move()
        mq.cmdf("/moveto loc %s %s dist %s", self.Y, self.X, self.arrivalDistance)

        -- Some interrupt logic here for the casting module if you're Casting and not a bard... not implementing this yet
        if mq.TLO.Me.Casting.ID() and mq.TLO.Me.Class.ShortName ~= "BRD" then
            -- interrupt
        end

        --Wait for character to move to destination
        mq.delay(string.format("%s",self.timeToWait), moveCallback)
        mq.cmdf("/moveto off")

        if not atDestion() then
            print(string.format("Unable to move to destination within the time allocated(%s)", timeToWait))
        end
    end

    -- This will move to the locaton in the X,Y coordinate.  No target needs to be provided in the propertiesTable
    function self.moveToLocation()
        if self.X == nil or self.Y==nil then
            print("No location provided.")
        else
            if mq.TLO.Plugin("MQ2MoveUtils").IsLoaded() then
                move()
            else
                nav()
            end
        end
    end

    -- This will derive X,Y coordinates frmo the target and move to that location.  No X,Y coordinates need to be provided in the propertiesTable
    function self.moveToTarget()
        if self.target == nil then
            print("No target provided.")
        else
            if mq.TLO.Plugin("MQ2MoveUtils").IsLoaded() then
                move()
            else
                nav()
            end
        end
    end

    -- Mostly for debugging purposes
    function self.PrintProperties()
        print("target=",self.target)
        print("X=",self.X)
        print("Y=",self.Y)
        print("Z=",self.Z)
        print("timeToWait=",self.timeToWait)
        print("arrivalDistance",self.arrivalDistance)
    end

    return self
end