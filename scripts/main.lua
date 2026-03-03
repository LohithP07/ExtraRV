-- ExtraRV - main.lua v1.8.0
-- Spawns an extra RV (Winnebago) in RV There Yet via UE4SS Lua mod.
--
-- MULTIPLAYER COMPATIBLE + REPLICATED (visible/driveable by all players).
-- Does NOT use summon/CheatManager. Does NOT corrupt the replication channel.
--
-- CONSOLE COMMANDS (open with ~ or ` in-game):
--   scanrv              - Scan actors and print vehicle class names.
--   spawnrv             - Spawn an RV (side=300, height=500 cm defaults).
--   spawnrv 300         - Custom horizontal side-offset in cm.
--   spawnrv 300 200     - Custom side AND drop-height. Lower = less fall damage.
--                         Flat ground: try spawnrv 300 100
--                         Hilly area:  try spawnrv 300 1500
--
-- KEYBINDS:
--   F6 = scanrv    F7 = spawnrv (300, 500)

local MOD_NAME     = "ExtraRV"
local RV_FULLPATH  = "/Game/Ride/Vehicle/Blueprints/BP_Vehicle_Winnebago_01.BP_Vehicle_Winnebago_01_C"
local RV_SHORTNAME = "BP_Vehicle_Winnebago_01_C"

local function log(msg) print(string.format("[%s] %s", MOD_NAME, tostring(msg))) end

log("Loaded v1.8.0 (MP compatible + replicated)")

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────────────────

local function safe(fn)
    local ok, v = pcall(fn)
    return ok and v or nil
end

local function isvalid(obj)
    if not obj then return false end
    local ok, v = pcall(function() return obj:IsValid() end)
    return ok and (v == true)
end

local function get_pawn()
    local pc = safe(function()
        return require("UEHelpers").GetPlayerController()
    end)
    if isvalid(pc) then
        local pawn = safe(function() return pc.Pawn end)
        if isvalid(pawn) then return pawn end
    end
    local pcs = safe(function() return FindAllOf("PlayerController") end)
    if pcs then
        for _, p in ipairs(pcs) do
            if isvalid(p) then
                local pawn = safe(function() return p.Pawn end)
                if isvalid(pawn) then return pawn end
            end
        end
    end
    return nil
end

local function get_rv_class()
    -- Full asset path first (avoids "Short type name" Unreal warning)
    local cls = safe(function() return StaticFindObject(RV_FULLPATH) end)
    if isvalid(cls) then log("Class: full path OK.") ; return cls end

    cls = safe(function() return FindFirstOf(RV_SHORTNAME) end)
    if isvalid(cls) then log("Class: short name OK.") ; return cls end

    -- Last resort: grab class from a live actor already in the world
    local actors = safe(function() return FindAllOf("Actor") end)
    if actors then
        for _, a in ipairs(actors) do
            local fn = safe(function()
                return a and a:IsValid() and a:GetFullName() or nil
            end)
            if fn and string.find(string.lower(fn), "winnebago") then
                cls = safe(function() return a:GetClass() end)
                if isvalid(cls) then log("Class: live actor OK.") ; return cls end
            end
        end
    end
    return nil
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SCAN
-- ─────────────────────────────────────────────────────────────────────────────
local function do_scan()
    log("=== ACTOR SCAN START ===")
    ExecuteInGameThread(function()
        local actors = safe(function() return FindAllOf("Actor") end)
        if not actors then log("No actors found.") ; return end
        local count = 0
        for _, a in ipairs(actors) do
            local fn = safe(function()
                return a and a:IsValid() and a:GetFullName() or nil
            end)
            if fn then
                for _, kw in ipairs({"rv","vehicle","camper","motorhome","winnebago","van"}) do
                    if string.find(string.lower(fn), kw) then
                        log("FOUND: " .. fn)
                        count = count + 1
                        break
                    end
                end
            end
        end
        log(count == 0 and "None found. Load a save first."
                       or  ("Done: " .. count .. " actor(s) found."))
        log("=== ACTOR SCAN END ===")
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- SPAWN  (MP safe + replicated)
--
-- REPLICATION STRATEGY:
--   • Strategy 1 (deferred): set bReplicates/bAlwaysRelevant/bReplicateMovement
--     as PROPERTY ASSIGNMENTS only, BEFORE FinishSpawningActor. This is the
--     correct UE pattern — the replication channel opens during FinishSpawning
--     and picks up whatever bReplicates was at that moment.
--     We do NOT call SetReplicates() / SetReplicateMovement() APIs post-spawn —
--     those can corrupt an active MP session.
--   • Strategy 2 (SpawnActor): the Blueprint defaults already set bReplicates=true
--     (it's a multiplayer game actor). We just call ForceNetUpdate to push it.
-- ─────────────────────────────────────────────────────────────────────────────
local function do_spawn_rv(sideOffset, zHeight)
    sideOffset = tonumber(sideOffset) or 300
    local Z_BOOST = tonumber(zHeight) or 500

    ExecuteInGameThread(function()

        local rvClass = get_rv_class()
        if not rvClass then
            log("ERROR: RV class not found. Run 'scanrv' while in-game.")
            return
        end

        local spawnLoc = { X = 0.0, Y = 0.0, Z = Z_BOOST }
        local pawn = get_pawn()
        if pawn then
            local loc = safe(function() return pawn:K2_GetActorLocation() end)
            if loc then
                spawnLoc = {
                    X = loc.X + sideOffset,
                    Y = loc.Y + sideOffset,
                    Z = loc.Z + Z_BOOST,
                }
            end
        else
            log("WARNING: Player pawn not found; using world origin+height.")
        end

        local spawnRot = { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 }

        log(string.format("Spawn at (%.0f, %.0f, %.0f) side=%d height=%d",
            spawnLoc.X, spawnLoc.Y, spawnLoc.Z, sideOffset, Z_BOOST))

        local spawnedOk = false

        -- ── STRATEGY 1: Deferred spawn — correct MP replication pattern ───────
        if not spawnedOk then
            local ok1, e1 = pcall(function()
                local gs = require("UEHelpers").GetGameplayStatics()
                if isvalid(gs) then
                    local a = gs:BeginDeferredActorSpawnFromClass(
                        rvClass, spawnLoc, spawnRot, nil, 3)
                    if isvalid(a) then
                        -- Property assignments only (NO API calls like SetReplicates).
                        -- Must happen BEFORE FinishSpawningActor so the channel
                        -- opens with the correct replication state.
                        pcall(function() a.bReplicates = true end)
                        pcall(function() a.bAlwaysRelevant = true end)
                        pcall(function() a.bReplicateMovement = true end)
                        -- Finish init — replication channel opens here
                        gs:FinishSpawningActor(a, spawnLoc, spawnRot)
                        -- Safe post-spawn nudge — does NOT change replication state
                        pcall(function() a:ForceNetUpdate() end)
                        log("SUCCESS (S1 deferred). All players should see the RV!")
                        spawnedOk = true
                    else
                        log("S1: BeginDeferred returned nil.")
                    end
                else
                    log("S1: GameplayStatics unavailable.")
                end
            end)
            if not ok1 then log("S1 error: " .. tostring(e1)) end
        end

        -- ── STRATEGY 2: Direct SpawnActor — Blueprint defaults handle replication
        if not spawnedOk then
            local ok2, e2 = pcall(function()
                local world = safe(function() return FindFirstOf("World") end)
                if isvalid(world) then
                    local a = world:SpawnActor(rvClass, spawnLoc, spawnRot)
                    if isvalid(a) then
                        -- Blueprint already has bReplicates=true; just nudge the net.
                        pcall(function() a:ForceNetUpdate() end)
                        log("SUCCESS (S2 SpawnActor). All players should see the RV!")
                        spawnedOk = true
                    else
                        log("S2: nil actor (collision?). Try: spawnrv "
                            .. sideOffset .. " " .. (Z_BOOST + 800))
                    end
                else
                    log("S2: World not found.")
                end
            end)
            if not ok2 then log("S2 error: " .. tostring(e2)) end
        end

        if not spawnedOk then
            log("ERROR: Both strategies failed.")
            log("Try more height: spawnrv " .. sideOffset .. " " .. (Z_BOOST + 1000))
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CONSOLE COMMANDS
-- ─────────────────────────────────────────────────────────────────────────────
local consoleOk = pcall(function()
    RegisterConsoleCommandHandler("scanrv", function(_, _, _)
        do_scan() ; return true
    end)
    RegisterConsoleCommandHandler("spawnrv", function(_, params, _)
        do_spawn_rv(params and params[1], params and params[2]) ; return true
    end)
    log("Commands ready: scanrv | spawnrv [side] [height]")
end)
if not consoleOk then log("WARNING: Console commands unavailable. Use F6/F7.") end

-- ─────────────────────────────────────────────────────────────────────────────
-- KEYBIND FALLBACKS
-- ─────────────────────────────────────────────────────────────────────────────
pcall(function()
    RegisterKeyBind(Key.F6, {}, function() do_scan()             end)
    RegisterKeyBind(Key.F7, {}, function() do_spawn_rv(300, 500) end)
    log("Keybinds: F6=scan, F7=spawn")
end)