--
--  The Soil Management and Growth Control Project - version 2 (FS15)
--
-- @author  Decker_MMIV - fs-uk.com, forum.farming-simulator.com, modhoster.com
-- @date    2015-02-xx
--

fmcModifySprayers = {}
--
local modItem = ModsUtil.findModItemByModName(g_currentModName);
fmcModifySprayers.version = (modItem and modItem.version) and modItem.version or "?.?.?";
--

--
function fmcModifySprayers.setup()
    if not fmcModifySprayers.initialized then
        fmcModifySprayers.initialized = true
        -- Change functionality, so 'fillType' is also used/sent.
        fmcModifySprayers.overwriteSprayerAreaEvent()
        fmcModifySprayers.overwriteSprayer1()
        fmcModifySprayers.overwriteSprayer2_FS15()
        fmcModifySprayers.overwriteSprayer3_FS15()
    end
    --
    fmcModifySprayers.soilModFillTypes = nil;    
end

--
function fmcModifySprayers.teardown()
end


-- Event to change the currentFillType --

ChangeFillTypeEvent = {};
ChangeFillTypeEvent_mt = Class(ChangeFillTypeEvent, Event);

InitEventClass(ChangeFillTypeEvent, "ChangeFillTypeEvent");

function ChangeFillTypeEvent:emptyNew()
    local self = Event:new(ChangeFillTypeEvent_mt);
    self.className="ChangeFillTypeEvent";
    return self;
end;

function ChangeFillTypeEvent:new(vehicle, action)
    local self = ChangeFillTypeEvent:emptyNew()
    self.vehicle = vehicle;
    self.action = action;
    return self;
end;

function ChangeFillTypeEvent:readStream(streamId, connection)
    self.vehicle = networkGetObject(streamReadInt32(streamId));
    self.action  = streamReadInt8(streamId);
    self:run(connection);
end;

function ChangeFillTypeEvent:writeStream(streamId, connection)
    streamWriteInt32(streamId, networkGetObjectId(self.vehicle));
    streamWriteInt8(streamId, self.action);
end;

function ChangeFillTypeEvent:run(connection)
    if self.vehicle ~= nil then
        Sprayer.changeFillType(self.vehicle, self.action, connection:getIsServer());
    end
end;

function ChangeFillTypeEvent.sendEvent(vehicle, action, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(ChangeFillTypeEvent:new(vehicle, action), nil, nil, vehicle);
        else
            g_client:getServerConnection():sendEvent(ChangeFillTypeEvent:new(vehicle, action));
        end;
    end;
end;


--
--


function fmcModifySprayers.overwriteSprayerAreaEvent()
  logInfo("Overwriting SprayerAreaEvent functions, to take extra argument; 'augmentedFillType'.")

  SprayerAreaEvent.new = function(self, cuttingAreas
--#### DECKER_MMIV ############################################################
  , augmentedFillType
--#############################################################################
  )
      local self = SprayerAreaEvent:emptyNew()
      self.cuttingAreas = cuttingAreas;
--#### DECKER_MMIV ############################################################
--  FS15
      -- Fix "adjustment" for not being able to access the internals of Sprayer.updateTick() method.
      if augmentedFillType == nil then
        augmentedFillType = Utils.getNoNil(SprayerAreaEvent.fmcSprayerCurrentFillType, Fillable.FILLTYPE_UNKNOWN)
      end
--FS15]]
      self.augmentedFillType = augmentedFillType
--#############################################################################
      return self;
  end;
  
  SprayerAreaEvent.readStream = function(self, streamId, connection)
--#### DECKER_MMIV ############################################################
      local augmentedFillType = streamReadUIntN(streamId, fmcSoilMod.fillTypeSendNumBits)
--#############################################################################
      local numAreas = streamReadUIntN(streamId, 4);
      local refX = streamReadFloat32(streamId);
      local refY = streamReadFloat32(streamId);
      local values = Utils.readCompressed2DVectors(streamId, refX, refY, numAreas*3-1, 0.01, true);
      for i=1,numAreas do
          local vi = i-1;
          local x = values[vi*3+1].x;
          local z = values[vi*3+1].y;
          local x1 = values[vi*3+2].x;
          local z1 = values[vi*3+2].y;
          local x2 = values[vi*3+3].x;
          local z2 = values[vi*3+3].y;
--#### DECKER_MMIV ############################################################
          -- Utils.updateSprayArea(x, z, x1, z1, x2, z2);
          Utils.updateSprayArea(x, z, x1, z1, x2, z2, augmentedFillType);
--#############################################################################
      end;
  end;
  
  SprayerAreaEvent.writeStream = function(self, streamId, connection)
--#### DECKER_MMIV ############################################################
      streamWriteUIntN(streamId, self.augmentedFillType, fmcSoilMod.fillTypeSendNumBits)
--#############################################################################
      local numAreas = table.getn(self.cuttingAreas);
      streamWriteUIntN(streamId, numAreas, 4);
      local refX, refY;
      local values = {};
      for i=1, numAreas do
          local d = self.cuttingAreas[i];
          if i==1 then
              refX = d[1];
              refY = d[2];
              streamWriteFloat32(streamId, d[1]);
              streamWriteFloat32(streamId, d[2]);
          else
              table.insert(values, {x=d[1], y=d[2]});
          end;
          table.insert(values, {x=d[3], y=d[4]});
          table.insert(values, {x=d[5], y=d[6]});
      end;
      assert(table.getn(values) == numAreas*3 - 1);
      Utils.writeCompressed2DVectors(streamId, refX, refY, values, 0.01);
  end;
  
  SprayerAreaEvent.runLocally = function(cuttingAreas
--#### DECKER_MMIV ############################################################
  , augmentedFillType
  )
--  FS15
      -- Fix "adjustment" for not being able to access the internals of Sprayer.updateTick() method.
      if augmentedFillType == nil then
        augmentedFillType = Utils.getNoNil(SprayerAreaEvent.fmcSprayerCurrentFillType, Fillable.FILLTYPE_UNKNOWN)
      end
--FS15]]
--#############################################################################
      local numAreas = table.getn(cuttingAreas);
      local refX, refY;
      local values = {};
      for i=1, numAreas do
          local d = cuttingAreas[i];
          if i==1 then
              refX = d[1];
              refY = d[2];
          else
              table.insert(values, {x=d[1], y=d[2]});
          end;
          table.insert(values, {x=d[3], y=d[4]});
          table.insert(values, {x=d[5], y=d[6]});
      end;
      assert(table.getn(values) == numAreas*3 - 1);
  
      local values = Utils.simWriteCompressed2DVectors(refX, refY, values, 0.01, true);
  
      for i=1, numAreas do
          local vi = i-1;
          local x = values[vi*3+1].x;
          local z = values[vi*3+1].y;
          local x1 = values[vi*3+2].x;
          local z1 = values[vi*3+2].y;
          local x2 = values[vi*3+3].x;
          local z2 = values[vi*3+3].y;
--#### DECKER_MMIV ############################################################
          -- Utils.updateSprayArea(x, z, x1, z1, x2, z2);
          Utils.updateSprayArea(x, z, x1, z1, x2, z2, augmentedFillType);
--#############################################################################
      end;
  end;
end


function fmcModifySprayers.getSoilModFillTypes(fillTypes)
    fillTypes = Utils.getNoNil(fillTypes, {})

    if Fillable.FILLTYPE_FERTILIZER  then table.insert(fillTypes, Fillable.FILLTYPE_FERTILIZER ); end;
    if Fillable.FILLTYPE_FERTILIZER2 then table.insert(fillTypes, Fillable.FILLTYPE_FERTILIZER2); end;
    if Fillable.FILLTYPE_FERTILIZER3 then table.insert(fillTypes, Fillable.FILLTYPE_FERTILIZER3); end;
    
    if Fillable.FILLTYPE_HERBICIDE   then table.insert(fillTypes, Fillable.FILLTYPE_HERBICIDE  ); end;
    if Fillable.FILLTYPE_HERBICIDE2  then table.insert(fillTypes, Fillable.FILLTYPE_HERBICIDE2 ); end;
    if Fillable.FILLTYPE_HERBICIDE3  then table.insert(fillTypes, Fillable.FILLTYPE_HERBICIDE3 ); end;
    if Fillable.FILLTYPE_HERBICIDE4  then table.insert(fillTypes, Fillable.FILLTYPE_HERBICIDE4 ); end;
    if Fillable.FILLTYPE_HERBICIDE5  then table.insert(fillTypes, Fillable.FILLTYPE_HERBICIDE5 ); end;
    if Fillable.FILLTYPE_HERBICIDE6  then table.insert(fillTypes, Fillable.FILLTYPE_HERBICIDE6 ); end;

    if Fillable.FILLTYPE_KALK        then table.insert(fillTypes, Fillable.FILLTYPE_KALK       ); end;
    if Fillable.FILLTYPE_WATER       then table.insert(fillTypes, Fillable.FILLTYPE_WATER      ); end;

    if Fillable.FILLTYPE_PLANTKILLER then table.insert(fillTypes, Fillable.FILLTYPE_PLANTKILLER); end;
    
    return fillTypes
end


function fmcModifySprayers.isSoilModFillType(fillType)
    if not fmcModifySprayers.soilModFillTypes then
        fmcModifySprayers.soilModFillTypes = {}
        local fillTypes = fmcModifySprayers.getSoilModFillTypes();
        for _,fType in pairs(fillTypes) do
            fmcModifySprayers.soilModFillTypes[fType] = true;
        end
    end
    return fmcModifySprayers.soilModFillTypes[fillType];
end


function fmcModifySprayers.overwriteSprayer1()

    -- Due to the vanilla sprayers only spray 'fertilizer', this modification will
    -- force addition of extra fill-types to be sprayed.
    logInfo("Prepending to Fillable.postLoad, for adding extra fill-types")
    Fillable.postLoad = Utils.prependedFunction(Fillable.postLoad, function(self, xmlFile)
        if Fillable.FILLTYPE_KALK ~= nil then
            -- Fix for modded equipment, so if they allow spraying with lime, then mark it as a solid-material sprayer.
            for fillType,accepts in pairs(self.fillTypes) do
                if fillType == Fillable.FILLTYPE_KALK and accepts then
                    self.fmcSprayerSolidMaterial = true
                    break
                end
            end
        end

        -- Only consider tools that can spread/spray 'fertilizer'.
        if self.fillTypes[Fillable.FILLTYPE_FERTILIZER] then
            -- However if tool already accepts at least one for SoilMods spray-types, then do NOT add any extra
            for fillType,accepts in pairs(self.fillTypes) do
                if fillType ~= Fillable.FILLTYPE_FERTILIZER and accepts and fmcModifySprayers.isSoilModFillType(fillType) then
                    return
                end
            end
            
            --
            local addFillTypes = {}
            if hasXMLProperty(xmlFile, "vehicle.turnedOnRotationNodes") then
                -- Simple check, if tool has <turnedOnRotationNodes> then it is most likely a 'solid spreader'.
                logInfo("Adding more filltypes (solid spreader - turnedOnRotationNodes)")
                addFillTypes = {
                    Fillable.FILLTYPE_FERTILIZER2
                    ,Fillable.FILLTYPE_FERTILIZER3
                    ,Fillable.FILLTYPE_KALK
                }
                self.fmcSprayerSolidMaterial = true
            elseif  hasXMLProperty(xmlFile, "vehicle.spinners") then
                -- Some 'solid spreaders' may use a <spinners> section
                logInfo("Adding more filltypes (solid spreader - spinners)")
                addFillTypes = {
                    Fillable.FILLTYPE_FERTILIZER2
                    ,Fillable.FILLTYPE_FERTILIZER3
                    ,Fillable.FILLTYPE_KALK
                }
                self.fmcSprayerSolidMaterial = true
            else
                logInfo("Adding more filltypes (liquid sprayer)")
                addFillTypes = {
                    Fillable.FILLTYPE_FERTILIZER2
                    ,Fillable.FILLTYPE_FERTILIZER3
                    ,Fillable.FILLTYPE_HERBICIDE
                    ,Fillable.FILLTYPE_HERBICIDE2
                    ,Fillable.FILLTYPE_HERBICIDE3
                    ,Fillable.FILLTYPE_HERBICIDE4
                    ,Fillable.FILLTYPE_HERBICIDE5
                    ,Fillable.FILLTYPE_HERBICIDE6
                    ,Fillable.FILLTYPE_WATER
                    ,Fillable.FILLTYPE_PLANTKILLER
                }
                self.fmcSprayerSolidMaterial = false
            end
            for _,fillType in pairs(addFillTypes) do
                if fillType then
                    self.fillTypes[fillType] = true
                end
            end
        end
    end);

    -- Set up spray usage.
    logInfo("Appending to Sprayer.postLoad, to set spray-usages for spray-types - incl. fix for mrLight mod.")
    Sprayer.postLoad = Utils.appendedFunction(Sprayer.postLoad, function(self)
        if not self.sprayLitersPerSecond or self.defaultSprayLitersPerSecond == 0 then
            return
        end
        --
        local baseLPS = math.max(Utils.getNoNil(self.sprayLitersPerSecond[Fillable.FILLTYPE_FERTILIZER], self.defaultSprayLitersPerSecond), 0.01)
        local factorSqm = baseLPS / math.max(Utils.getNoNil(Sprayer.sprayTypeIndexToDesc[Sprayer.SPRAYTYPE_FERTILIZER].litersPerSqmPerSecond, 0), 1)
        log(self.name,": base-LPS=",baseLPS," (factor ",factorSqm,")")
        
        for fillType,accepted in pairs(self.fillTypes) do
            --log("  ft=",fillType," ",Fillable.fillTypeIntToName[fillType]," / sp=",Sprayer.fillTypeToSprayType[fillType])
            if accepted and fillType ~= Fillable.FILLTYPE_UNKNOWN and Sprayer.fillTypeToSprayType[fillType] ~= nil then
                if Utils.getNoNil(self.sprayLitersPerSecond[fillType], 0) == 0 then
                    local sprayType = Sprayer.fillTypeToSprayType[fillType]
                    self.sprayLitersPerSecond[fillType] = factorSqm * Sprayer.sprayTypeIndexToDesc[sprayType].litersPerSqmPerSecond
                    log(self.name,": forced liters-per-sec for ",Fillable.fillTypeIntToName[fillType],"=",self.sprayLitersPerSecond[fillType])
                else
                    log(self.name,": exist  liters-per-sec for ",Fillable.fillTypeIntToName[fillType],"=",self.sprayLitersPerSecond[fillType])
                end
            end
        end
        
        -- Work-around for 'mrLight' to make it "not fail"
        if self.sprayLitersPerHectare ~= nil then
            for fillType,accepted in pairs(self.fillTypes) do
                if accepted and fillType ~= Fillable.FILLTYPE_UNKNOWN then
                    if self.sprayLitersPerHectare[fillType] == nil then
                        self.sprayLitersPerHectare[fillType] = self.sprayLitersPerHectare[Fillable.FILLTYPE_FERTILIZER]
                    end
                end
            end
        end
    end);

    -- Add possibility to 'change fill-type'.
    -- TODO: This should be changed, once there are better support for spreaders/sprayers fill-types, and stations in maps where to refill.
    Sprayer.changeFillType = function(self, action, noEventSend)
        -- Only the server can determine what the next currentFillType should be
        if action < 0 then
            if g_server ~= nil then
                local nextTypes = fmcModifySprayers.getSoilModFillTypes()
                for i,fillType in ipairs(nextTypes) do
                    if fillType ~= nil and fillType == self.currentFillType then
                        for k=0,table.getn(nextTypes) do
                            i = (i % table.getn(nextTypes))+1
                            if nextTypes[i] and self.fillTypes[nextTypes[i]] then
                                action = nextTypes[i]
                                break
                            end
                        end
                        break
                    end
                end
            end
        end
        if action >= 0 then
            if self.isServer then
                -- Adjust money, if possible
                if  self.currentFillType ~= Fillable.FILLTYPE_UNKNOWN
                and action               ~= Fillable.FILLTYPE_UNKNOWN
                then
                    local priceDiff 
                        = (Fillable.fillTypeIndexToDesc[self.currentFillType].pricePerLiter * self.fillLevel)
                        - (Fillable.fillTypeIndexToDesc[action].pricePerLiter * self.fillLevel)
                    g_currentMission:addSharedMoney(priceDiff, "other")
                end
            end
        
            self.currentFillType = action
            log("Changed currentFillType to: ",Fillable.fillTypeIntToName[self.currentFillType],"(",self.currentFillType,")"
                --,", spray-usage: ",self.sprayLitersPerSecond[self.currentFillType]
                --,", default: ",self.defaultSprayLitersPerSecond
            );
        end
        --
        ChangeFillTypeEvent.sendEvent(self, action, noEventSend)
    end
    
    logInfo("Appending to Sprayer.update, to let player change fill-type (but only near fertilizer tanks)")
    Sprayer.update = Utils.appendedFunction(Sprayer.update, function(self, dt)
        if self.isClient then
            if (self.allowsSpraying or self.isSprayerTank) and self.fillTypes[Fillable.FILLTYPE_FERTILIZER] and self:getIsActiveForInput() then
                self.fmcSoilModAllowChangeSprayType = (not self.isFilling) and (table.getn(self.fillTriggers) > 0) -- Only allow changing fill-type when near a fill-trigger
                if InputBinding.hasEvent(InputBinding.IMPLEMENT_EXTRA3) then -- Using same input-binding as sowingMachine's "select seed"
                    if self.fmcSoilModAllowChangeSprayType then
                        Sprayer.changeFillType(self, -1) -- 'Next available fillType' = -1
                    else
                        if self.isFilling then
                            g_currentMission:showBlinkingWarning(g_i18n:getText("NotWhileRefilling"), 2000)
                        else
                            g_currentMission:showBlinkingWarning(g_i18n:getText("OnlyNearSprayerFillTrigger"), 2000)
                        end
                    end;
                end
            end;
        end;
    end);

    logInfo("Appending to Sprayer.draw, to draw action in F1 help box");
    Sprayer.draw = Utils.appendedFunction(Sprayer.draw, function(self)
        if self.isClient then
            if self.fmcSoilModAllowChangeSprayType and self:getIsActiveForInput(true) then
                g_currentMission:addHelpButtonText(g_i18n:getText("SelectSprayType"), InputBinding.IMPLEMENT_EXTRA3); -- Using same input-binding as sowingMachine's "select seed"
            end
--[[FS2013            
            -- Show the hud icon, now that a spreader/sprayer can have different fill-types.
            if self.currentFillType ~= Fillable.FILLTYPE_UNKNOWN then
                g_currentMission:setFillTypeOverlayFillType(self.currentFillType)
            end
--FS2013]]
        end
    end);
end


function fmcModifySprayers.overwriteSprayer2_FS15()
-- Due to requirement of 'fill-type' to be send to SprayerAreaEvent/Utils.updateSprayArea,
-- the sprayer's updateTick() function is "adjusted" in a 'this-needs-to-be-done-better-once-the-FS15-scripts-becomes-public' way.

    logInfo("Prepending to Sprayer.updateTick function, so fill-type can be accessed by SprayerAreaEvent.")
    Sprayer.updateTick = Utils.prependedFunction(Sprayer.updateTick, 
        function(self, dt)
            -- Tell the SprayerAreaEvent what fill-type is currently "selected", since we can't access the internals of the updateTick() method.
            -- The first time the sprayer is turned on, it will probably change 'self.currentFillType'.
            -- Also: If the GIANTS game-engine suddently decides to execute scripts concurrently, this "adjustment" will most likely cause a race-condition.
            
            if self.needsTankActivation == true and self.attacherVehicle ~= nil then
                -- This is probably the zunhammerZunidisc, so we need to get the current-fill-type from its attacher-vehicle
                SprayerAreaEvent.fmcSprayerCurrentFillType = self.attacherVehicle.currentFillType
            else
                SprayerAreaEvent.fmcSprayerCurrentFillType = self.currentFillType 
                                                        + ((true == self.fmcSprayerSolidMaterial) and fmcSoilMod.fillTypeAugmented or 0); -- If solid-sprayer/spreader, then 'augment' the fill-type value.
            end
        end
    )

end


function fmcModifySprayers.overwriteSprayer3_FS15()

    fmcModifySprayers.getFirstEnabledFillType = function(self)
        local foundFillType = Fillable.FILLTYPE_UNKNOWN
        if self.fillLevel > 0 or self.isSprayerTank then
            -- This sprayer (or sprayer-tank) is not empty, so do normal operation...
            for fillType, enabled in pairs(self.fillTypes) do
                if fillType ~= Fillable.FILLTYPE_UNKNOWN and enabled then
                    foundFillType = fillType;
                    break
                end
            end
        else
            -- Attempt to locate a sprayer-tank's current-fill-type, by looping though all possible filltypes this sprayer has enabled
            for fillType, enabled in pairs(self.fillTypes) do
                if fillType ~= Fillable.FILLTYPE_UNKNOWN and enabled then
                    local sprayerTank = Sprayer.findAttachedSprayerTank(self:getRootAttacherVehicle(), fillType);
                    if sprayerTank ~= nil then
                        foundFillType = fillType;
                        break
                    end
                end
            end
        end

        -- Tell the SprayerAreaEvent what fill-type is currently "selected", since we can't access the internals of the updateTick() method.
        -- The first time the sprayer is turned on, it will probably change 'self.currentFillType'.
        -- Also: If the GIANTS game-engine suddently decides to execute scripts concurrently, this "adjustment" will most likely cause a race-condition.
        SprayerAreaEvent.fmcSprayerCurrentFillType = foundFillType
                                                + ((true == self.fmcSprayerSolidMaterial) and fmcSoilMod.fillTypeAugmented or 0); -- If solid-sprayer/spreader, then 'augment' the fill-type value.

        return foundFillType;
    end

    logInfo("Appending to Sprayer.postLoad, for getting fill-type from sprayer-tanks.")
    Sprayer.postLoad = Utils.appendedFunction(Sprayer.postLoad, function(self, xmlFile)
        self.getFirstEnabledFillType = fmcModifySprayers.getFirstEnabledFillType;
    end);

end

print(string.format("Script loaded: fmcModifySprayers.lua (v%s)", fmcModifySprayers.version));
