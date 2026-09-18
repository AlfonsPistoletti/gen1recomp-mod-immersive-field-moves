return function(mod)

    mod.options:define({{
        key = "vanilla_move_order",
        type = "toggle",
        label = "VANILLA MOVE ORDER",
        default = false
    }})

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

    local function loadWhitelist(relPath)
        local set = {}
        for _, species in ipairs(loadDataFile(relPath)) do
            set[species] = true
        end
        return set
    end

    local CUT_WHITELIST = loadWhitelist("assets/move_whitelists/cut_whitelist.lua")
    local FLASH_WHITELIST = loadWhitelist("assets/move_whitelists/flash_whitelist.lua")
    local DIG_WHITELIST = loadWhitelist("assets/move_whitelists/dig_whitelist.lua")
    local TELE_WHITELIST = loadWhitelist("assets/move_whitelists/teleport_whitelist.lua")
    local STRENGTH_ATTACK_THRESHOLD = 100
    local STRENGTH_WEIGHT_THRESHOLD = 100

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

    -- Pokedex-listed weight in pounds, for the STRENGTH weight requirement
    local function weightLbs(data, species)
        local def = data.pokemon[species]
        local e = def and def.dexEntry
        if not e or not e.weight then
            return 0
        end
        return e.weight / 10
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

    -- Single source of truth for every field move: the menu
    -- row it adds, its badge gate (if any), and the species/type/stat rule
    -- that lets a mon use it without knowing the TM/HM move outright. Both
    -- the menu-display hook and the execution-eligibility hook below read
    -- from this same table so they can never disagree about who qualifies.
    local MOVES = {
        CUT = {
            label = "CUT",
            action = "cut",
            badge = "CASCADEBADGE",
            check = function(game, mon) return CUT_WHITELIST[mon.species] end
        },
        FLY = {
            label = "FLY",
            action = "fly",
            badge = "THUNDERBADGE",
            check = function(game, mon) return isFlyingType(game.data, mon.species) end
        },
        SURF = {
            label = "SURF",
            action = "surf",
            badge = "SOULBADGE",
            check = function(game, mon) return isWaterType(game.data, mon.species) end
        },
        STRENGTH = {
            label = "STRENGTH",
            action = "strength",
            badge = "RAINBOWBADGE",
            check = function(game, mon)
                return mon.stats.attack > STRENGTH_ATTACK_THRESHOLD and weightLbs(game.data, mon.species) >= STRENGTH_WEIGHT_THRESHOLD
            end
        },
        FLASH = {
            label = "FLASH",
            action = "flash",
            badge = "BOULDERBADGE",
            check = function(game, mon) return FLASH_WHITELIST[mon.species] end
        },
        DIG = {
            label = "DIG",
            action = "escape",
            move = "DIG",
            check = function(game, mon) return DIG_WHITELIST[mon.species] end
        },
        TELEPORT = {
            label = "TELEPORT",
            action = "escape",
            move = "TELEPORT",
            check = function(game, mon) return TELE_WHITELIST[mon.species] end
        }
    }
    local MOVE_ORDER = { "CUT", "FLY", "SURF", "STRENGTH", "FLASH", "DIG", "TELEPORT" }

    -- Does `mon` currently qualify to use `moveId` in the field, badge and
    -- all? Works with either a `game` table (from ui.party.submenu) or a
    -- `ctx` table (from fieldmove.eligibility) since both expose .save/.data.
    local function qualifies(gameOrCtx, mon, moveId)
        local def = MOVES[moveId]
        if not def then
            return false
        end
        if def.badge and not gameOrCtx.save.inventory[def.badge] then
            return false
        end
        return def.check(gameOrCtx, mon) or knowsMove(mon, moveId)
    end

    -- The party member whose submenu is currently (or was last) open in the
    -- overworld. Set below whenever ui.party.submenu builds a non-battle
    -- submenu; fieldmove.eligibility prefers this mon so that using CUT/SURF
    -- credits whoever's submenu the player actually opened, instead of
    -- always resolving to the first qualifying party slot.
    local pendingMon = nil

    -- Display Field Move in menu
    mod.hooks:wrap("ui.party.submenu", function(orig, game, items, mon, ctx)
        items = orig(game, items, mon, ctx)

        -- Field moves only belong in the overworld submenu; the same hook
        -- also fires for the in-battle SWITCH/STATS/CANCEL submenu, which
        -- must stay untouched.
        for _, moveId in ipairs(MOVE_ORDER) do
            local def = MOVES[moveId]
            for i = #items, 1, -1 do
                if items[i].action == def.action then
                    table.remove(items, i)
                end
            end
        end

        if not ctx.battle then
            pendingMon = mon
            for _, moveId in ipairs(MOVE_ORDER) do
                local def = MOVES[moveId]
                if qualifies(game, mon, moveId) then
                    insertMove(items, { label = def.label, action = def.action, move = def.move })
                end
            end
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
        if not MOVES[moveId] then
            return orig(moveId, ctx)
        end

        if pendingMon and qualifies(ctx, pendingMon, moveId) then
            return pendingMon
        end

        for _, partyMon in ipairs(ctx.save.party) do
            if qualifies(ctx, partyMon, moveId) then
                return partyMon
            end
        end
        return nil
    end)
end
