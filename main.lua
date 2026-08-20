return function(mod)

    mod.options:define({{
        key = "vanilla_move_order",
        type = "toggle",
        label = "VANILLA MOVE ORDER",
        default = false
    }})

    local BADGE_REQUIREMENTS = {
        CUT = "CASCADEBADGE",
        FLASH = "BOULDERBADGE",
        SURF = "SOULBADGE",
        FLY = "THUNDERBADGE",
        STRENGTH = "RAINBOWBADGE"
    }

    local function insertMove(items, entry)
        if mod.options:get("vanilla_move_order") then
            local insertAt = #items + 1
            for i, it in ipairs(items) do
                if it.action == "stats" or it.action == "switch" then
                    insertAt = i
                    break
                end
            end
            table.insert(items, insertAt, entry)
        else
            table.insert(items, entry)
        end
    end

    local function loadDataFile(relPath)
        local text = mod:read(relPath)
        local chunk = assert(load(text, "@" .. relPath))
        return chunk()
    end

    -- Get CUT Whitelist
    local cutList = loadDataFile("assets/move_whitelists/cut_whitelist.lua")
    local CUT_WHITELIST = {}
    for _, species in ipairs(cutList) do
        CUT_WHITELIST[species] = true
    end

    -- Get FLASH Whitelist
    local flashList = loadDataFile("assets/move_whitelists/flash_whitelist.lua")
    local FLASH_WHITELIST = {}
    for _, species in ipairs(flashList) do
        FLASH_WHITELIST[species] = true
    end

    -- Get DIG Whitelist
    local digList = loadDataFile("assets/move_whitelists/dig_whitelist.lua")
    local DIG_WHITELIST = {}
    for _, species in ipairs(digList) do
        DIG_WHITELIST[species] = true
    end

    -- Get TELEPORT Whitelist
    local teleportList = loadDataFile("assets/move_whitelists/teleport_whitelist.lua")
    local TELE_WHITELIST = {}
    for _, species in ipairs(teleportList) do
        TELE_WHITELIST[species] = true
    end

    local function hasType(data, species, typeId)
        local def = data.pokemon[species]
        if not def or not def.types then
            return false
        end
        for _, t in ipairs(def.types) do
            if t == typeId then
                return true
            end
        end
        return false
    end

    -- Check if selected species is a water type
    local function isWaterType(data, species)
        return hasType(data, species, "WATER")
    end

    -- Check if selected species is a flying type
    local function isFlyingType(data, species)
        return hasType(data, species, "FLYING")
    end

    -- Vanilla-Check: Does the species know the move
    local function knowsMove(mon, moveId)
        for _, mv in ipairs(mon.moves) do
            if mv.id == moveId then
                return true
            end
        end
        return false
    end

    -- Display Field Move in menu
    mod.hooks:wrap("ui.party.submenu", function(orig, game, items, mon, ctx)
        items = orig(game, items, mon, ctx)

        local hasBadge = game.save.inventory

        -- CUT
        for i = #items, 1, -1 do
            if items[i].action == "cut" then
                table.remove(items, i)
            end
        end
        if hasBadge[BADGE_REQUIREMENTS.CUT] and (CUT_WHITELIST[mon.species] or knowsMove(mon, "CUT")) then
            insertMove(items, {
                label = "CUT",
                action = "cut"
            })
        end

        -- FLY
        for i = #items, 1, -1 do
            if items[i].action == "fly" then
                table.remove(items, i)
            end
        end
        if hasBadge[BADGE_REQUIREMENTS.FLY] and (isFlyingType(game.data, mon.species) or knowsMove(mon, "FLY")) then
            insertMove(items, {
                label = "FLY",
                action = "fly"
            })
        end

        -- SURF
        for i = #items, 1, -1 do
            if items[i].action == "surf" then
                table.remove(items, i)
            end
        end
        if hasBadge[BADGE_REQUIREMENTS.SURF] and (isWaterType(game.data, mon.species) or knowsMove(mon, "SURF")) then
            insertMove(items, {
                label = "SURF",
                action = "surf"
            })
        end

        -- STRENGTH
        for i = #items, 1, -1 do
            if items[i].action == "strength" then
                table.remove(items, i)
            end
        end
        if hasBadge[BADGE_REQUIREMENTS.STRENGTH] and (mon.stats.attack > 55 or knowsMove(mon, "STRENGTH")) then
            insertMove(items, {
                label = "STRENGTH",
                action = "strength"
            })
        end

        -- FLASH
        for i = #items, 1, -1 do
            if items[i].action == "flash" then
                table.remove(items, i)
            end
        end
        if hasBadge[BADGE_REQUIREMENTS.FLASH] and (FLASH_WHITELIST[mon.species] or knowsMove(mon, "FLASH")) then
            insertMove(items, {
                label = "FLASH",
                action = "flash"
            })
        end

        -- DIG & TELEPORT
        for i = #items, 1, -1 do
            if items[i].action == "escape" then
                table.remove(items, i)
            end
        end
        if (DIG_WHITELIST[mon.species] or knowsMove(mon, "DIG")) then
            insertMove(items, {
                label = "DIG",
                action = "escape",
                move = "DIG"
            })
        end
        if (TELE_WHITELIST[mon.species] or knowsMove(mon, "TELEPORT")) then
            insertMove(items, {
                label = "TELEPORT",
                action = "escape",
                move = "TELEPORT"
            })
        end

        -- SOFTBOILED: vanilla
        for i = #items, 1, -1 do
            if items[i].action == "softboiled" then
                local entry = table.remove(items, i)
                insertMove(items, entry)
                break
            end
        end

        return items
    end)

    -- Override Field Move eligibility check
    mod.hooks:wrap("fieldmove.eligibility", function(orig, moveId, ctx)
        local badge = BADGE_REQUIREMENTS[moveId]
        if badge and not ctx.save.inventory[badge] then
            return nil
        end

        if moveId == "CUT" then
            for _, partyMon in ipairs(ctx.save.party) do
                if CUT_WHITELIST[partyMon.species] or knowsMove(partyMon, "CUT") then
                    return partyMon
                end
            end
            return nil
        end

        if moveId == "FLY" then
            for _, partyMon in ipairs(ctx.save.party) do
                if isFlyingType(ctx.data, partyMon.species) or knowsMove(partyMon, "FLY") then
                    return partyMon
                end
            end
            return nil
        end

        if moveId == "SURF" then
            for _, partyMon in ipairs(ctx.save.party) do
                if isWaterType(ctx.data, partyMon.species) or knowsMove(partyMon, "SURF") then
                    return partyMon
                end
            end
            return nil
        end

        if moveId == "STRENGTH" then
            for _, partyMon in ipairs(ctx.save.party) do
                if partyMon.stats.attack > 55 or knowsMove(partyMon, "STRENGTH") then
                    return partyMon
                end
            end
            return nil
        end

        if moveId == "FLASH" then
            for _, partyMon in ipairs(ctx.save.party) do
                if FLASH_WHITELIST[partyMon.species] or knowsMove(partyMon, "FLASH") then
                    return partyMon
                end
            end
            return nil
        end

        return orig(moveId, ctx)
    end)
end
