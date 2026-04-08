if getgenv and getgenv().FischCleanup then
    pcall(getgenv().FischCleanup)
    task.wait(0.3)
end

if getgenv and getgenv().FischRunning then
    error("[Fisch] Already running! Previous instance cleaned up, run again.")
end

if getgenv then
    getgenv().FischRunning = true
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    local t = os.clock()
    repeat task.wait(0.5); LocalPlayer = Players.LocalPlayer
    until LocalPlayer or os.clock() - t > 30
    if not LocalPlayer then error("[Fisch] LocalPlayer not found") end
end

local Mouse = LocalPlayer:GetMouse()
local Camera = workspace.CurrentCamera

local V2 = Vector2.new
local C3 = Color3.fromRGB
local floor = math.floor
local max = math.max
local min = math.min
local clock = os.clock
local insert = table.insert
local DrawNew = Drawing.new

local Colors = {
    BarBg = C3(16, 16, 20),
    BarBorder = C3(36, 38, 46),
    BarGlow = C3(55, 200, 180),
    TabNormal = C3(16, 16, 20),
    TabHover = C3(28, 30, 38),
    TabActive = C3(22, 24, 32),
    IconNormal = C3(100, 105, 120),
    IconActive = C3(55, 200, 180),
    TextNormal = C3(90, 95, 108),
    TextActive = C3(220, 225, 235),
    Indicator = C3(55, 200, 180),
    PanelBg = C3(12, 12, 16),
    PanelBorder = C3(36, 38, 46),
    PanelHeader = C3(220, 225, 235),
    PanelText = C3(110, 115, 130),
    Separator = C3(34, 36, 44),
    SepAccent = C3(55, 200, 180),
    ToggleOn = C3(45, 185, 160),
    ToggleOff = C3(42, 44, 54),
    ToggleKnob = C3(235, 238, 245),
    BtnBg = C3(28, 30, 40),
    BtnBorder = C3(46, 48, 60),
    Danger = C3(230, 60, 60),
    DangerDim = C3(80, 25, 25),
    Success = C3(45, 210, 140),
    Warning = C3(245, 195, 55),
    Accent = C3(55, 200, 180),
    AccentDim = C3(30, 100, 90),
    DimText = C3(58, 62, 74),
    InfoLabel = C3(85, 90, 105),
    InfoValue = C3(185, 190, 205),
    RarityRare = C3(80, 145, 255),
    RarityLegend = C3(255, 170, 30),
    RarityMythical = C3(190, 85, 235),
    RarityShiny = C3(255, 230, 50),
}

local Config = {
    BarWidth = 300, BarHeight = 56,
    TabWidth = 88, TabGap = 0,
    IconCenterY = 18, TextY = 36, GlowH = 3,
    PanelWidth = 280, PanelGap = 6, PanelPad = 14, HeaderH = 46,
    ToggleW = 34, ToggleH = 16, RowHeight = 30,
    InfoLabelW = 78, InfoSpacing = 18,
    BtnH = 30, WarpBtnH = 30, WarpGap = 4,
    SectionGapTop = 10, SectionGapBot = 14,
    DropdownItemH = 22,
}

local screenSize = Camera and Camera.ViewportSize or V2(1920, 1080)
Config.BarX = floor((screenSize.X - Config.BarWidth) / 2)
Config.BarY = 20
Config.TabGap = floor((Config.BarWidth - 3 * Config.TabWidth) / 4)

local Settings = {
    Enabled = false,
    AutoShake = true, AutoReel = true, AutoCast = true,
    ShakeDelay = 0.05, ReelPollRate = 0.003,
    MemorySize = 10, PredictionFrames = 3,
    SlideCompensation = 8, ErrorMemorySize = 5,
    ErrorPredictionTime = 0.05, DirectionChangeCooldown = 2,
    AutoTotem = false, DayTotem = "None", NightTotem = "None",
    AutoPerfectCast = false, PerfectCastHoldTime = 1.2,
}

local isReeling = false
local isShaking = false
local isHolding = false

local fishMemory = {}
local barMemory = {}
local fishVelocity = 0
local fishAccel = 0
local barVelocity = 0
local predictedFishX = 0
local errorMemory = {}
local errorVelocity = 0
local lastDirection = nil
local directionCooldown = 0

local lastReelSeen = 0

local reelVersion = 0
local castVersion = 0
local totemVersion = 0
local lastFishScanTime = 0

local threadHeartbeats = { reel = 0, cast = 0, shake = 0 }
local HEARTBEAT_TIMEOUT = 8

local currentRod = nil
local rodStats = { Name = "None", Control = 0.2, Resilience = 0, Source = "default" }

local currentFish = { Name = "None", Rarity = "-" }

local Stats = {
    SessionStart = os.clock(), TotalCatches = 0,
    ShinyCount = 0, MutationCount = 0, BestCatch = "None",
}

local toggleVK = 0x75
local VK_F5 = 0x74
local VK_MOUSE1 = 0x01

local availableTotems = {
    "None", "Sundial Totem", "Meteor Totem", "Smokescreen Totem",
    "Windset Totem", "Tempest Totem", "Eclipse Totem", "Avalanche Totem",
    "Aurora Totem", "Starfall Totem", "Cursed Storm Totem", "Blue Moon Totem",
    "Blizzard Totem", "Frost Moon Totem", "Poseidon's Wrath Totem",
    "Zeus's Storm Totem", "Clear Cast Totem",
}
local lastTotemUse = 0
local lastCycleWasDay = nil
local dayTotemIndex = 1
local nightTotemIndex = 1
local dayDropOpen = false
local nightDropOpen = false

local TeleportLocations = {
    {Name = "Moosewood",          Position = Vector3.new(583, 135, 177),      Cat = "Surface"},
    {Name = "Roslit Bay",         Position = Vector3.new(-1685, 338, 439),    Cat = "Surface"},
    {Name = "Mushgrove",          Position = Vector3.new(2697, 164, -757),    Cat = "Surface"},
    {Name = "Snowcap",            Position = Vector3.new(2834, -113, 2662),   Cat = "Surface"},
    {Name = "Terrapin",           Position = Vector3.new(57, 149, 1939),      Cat = "Surface"},
    {Name = "Ancient Isle",       Position = Vector3.new(5942, 327, 338),     Cat = "Surface"},
    {Name = "Lost Jungle",        Position = Vector3.new(-2761, 165, -2110),  Cat = "Surface"},
    {Name = "Forsaken Shores",    Position = Vector3.new(-2849, 394, 1627),   Cat = "Surface"},
    {Name = "Sunstone",           Position = Vector3.new(-1049, 232, -1166),  Cat = "Surface"},
    {Name = "Northern Expedition",Position = Vector3.new(19824, 190, 5292),   Cat = "Surface"},
    {Name = "Boreal Pines",       Position = Vector3.new(21606, 478, 3996),   Cat = "Surface"},
    {Name = "Treasure Island",    Position = Vector3.new(8384, 154, -17250),  Cat = "Surface"},

    {Name = "The Depths",         Position = Vector3.new(999, -749, 1307),    Cat = "Deep"},
    {Name = "Atlantis",           Position = Vector3.new(-4190, -694, 1700),  Cat = "Deep"},
    {Name = "Tidefall",           Position = Vector3.new(3692, -1092, 950),   Cat = "Deep"},
    {Name = "Keepers Altar",      Position = Vector3.new(1368, -766, -77),    Cat = "Deep"},
    {Name = "Desolate Deep",      Position = Vector3.new(-1642, -182, -2843), Cat = "Deep"},
    {Name = "Crystal Cove",       Position = Vector3.new(1370, -587, 2398),   Cat = "Deep"},
    {Name = "Challenger's Deep",  Position = Vector3.new(-619, -3396, -785),  Cat = "Deep"},
    {Name = "Mineshaft",          Position = Vector3.new(-478, -808, -139),   Cat = "Deep"},
    {Name = "Vertigo",            Position = Vector3.new(-271, -718, 1403),   Cat = "Deep"},
    {Name = "Sunstone Rift",      Position = Vector3.new(-947, -567, -1319),  Cat = "Deep"},

    {Name = "Forgotten Temple",   Position = Vector3.new(-5107, -1710, -9860),Cat = "Special"},
    {Name = "Calm Zone",          Position = Vector3.new(-4350, -11280, 2400),Cat = "Special"},
    {Name = "Abyssal Zenith",     Position = Vector3.new(-12433, -11210, -30),Cat = "Special"},
    {Name = "Veil of Forsaken",   Position = Vector3.new(-2256, -11376, 6873),Cat = "Special"},
    {Name = "Cultist Lair",       Position = Vector3.new(4346, -2036, -4675), Cat = "Special"},
    {Name = "Volcanic Vents",     Position = Vector3.new(-3272, -2312, 3807), Cat = "Special"},
    {Name = "The Void",           Position = Vector3.new(-32103, 10005, -23311),Cat = "Special"},
}

local GUI = {
    Elements = {}, PanelElements = {}, Clickables = {},
    Visible = true, SelectedTab = nil,
    Dragging = false, DragOffsetX = 0, DragOffsetY = 0,
    WasMouseDown = false, Tabs = {}, InfoRefs = {},
}

local warpCatIndex = 1
local warpCategories = {"Surface", "Deep", "Special"}
local warpCatIcons = { Surface = "~", Deep = "v", Special = "*" }

local function getPlayerGui()
    return LocalPlayer:FindFirstChildOfClass("PlayerGui")
end

local function addToMemory(memory, value, maxSize)
    table.insert(memory, value)
    while #memory > maxSize do
        table.remove(memory, 1)
    end
end

local function calculateVelocity(memory)
    if #memory < 2 then return 0 end
    local total = 0
    for i = 2, #memory do
        total = total + (memory[i] - memory[i - 1])
    end
    return total / (#memory - 1)
end

local function calculateAcceleration(memory)
    if #memory < 3 then return 0 end
    local vel1 = memory[#memory] - memory[#memory - 1]
    local vel2 = memory[#memory - 1] - memory[#memory - 2]
    return vel1 - vel2
end

local function predictPosition(pos, vel, accel, frames)
    return pos + (vel * frames) + (0.5 * accel * frames * frames)
end

local function resetMemory()
    fishMemory = {}
    barMemory = {}
    fishVelocity = 0
    fishAccel = 0
    barVelocity = 0
    predictedFishX = 0
    errorMemory = {}
    errorVelocity = 0
    lastDirection = nil
    directionCooldown = 0
end

local function formatTime(seconds)
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local RodDatabase = {

    {p = "tryhard",       Control = -0.37, Resilience = -500},
    {p = "duskwire",      Control = -0.20, Resilience = 175},
    {p = "long",          Control = -0.10, Resilience = 20},
    {p = "firefly",       Control = -0.01, Resilience = 25},

    {p = "flimsy",        Control = 0.00,  Resilience = 0},
    {p = "plastic",       Control = 0.00,  Resilience = 10},
    {p = "fabulous",      Control = 0.00,  Resilience = 50},

    {p = "carbon",        Control = 0.05,  Resilience = 10},
    {p = "fast",          Control = 0.05,  Resilience = -5},
    {p = "magnet",        Control = 0.05,  Resilience = 0},
    {p = "trident",       Control = 0.05,  Resilience = 0},
    {p = "mythical",      Control = 0.05,  Resilience = 15},
    {p = "frost warden",  Control = 0.05,  Resilience = 15},
    {p = "steady",        Control = 0.05,  Resilience = 30},
    {p = "astral",        Control = 0.05,  Resilience = 5},
    {p = "event horizon", Control = 0.05,  Resilience = 5},
    {p = "frog",          Control = 0.05,  Resilience = 5},
    {p = "stone",         Control = 0.05,  Resilience = 5},

    {p = "wind elemental",Control = 0.055, Resilience = 55},
    {p = "aurora",        Control = 0.06,  Resilience = 16},
    {p = "lucky",         Control = 0.07,  Resilience = 7},
    {p = "ruinous",       Control = 0.08,  Resilience = 25},

    {p = "luminescent",   Control = 0.10,  Resilience = 12},
    {p = "reinforced",    Control = 0.10,  Resilience = 15},
    {p = "requiem",       Control = 0.10,  Resilience = 63},
    {p = "sunken",        Control = 0.15,  Resilience = 15},
    {p = "kings",         Control = 0.15,  Resilience = 35},
    {p = "great dreamer", Control = 0.17,  Resilience = 17},
    {p = "wildflower",    Control = 0.17,  Resilience = 17},
    {p = "onirifalx",     Control = 0.17,  Resilience = 0},

    {p = "training",      Control = 0.20,  Resilience = 20},
    {p = "destiny",       Control = 0.20,  Resilience = 10},
    {p = "kraken",        Control = 0.20,  Resilience = 15},
    {p = "celestial",     Control = 0.21,  Resilience = 25},
    {p = "no%-life",      Control = 0.23,  Resilience = 10},
    {p = "dreambreaker",  Control = 0.23,  Resilience = 66},
    {p = "astraeus",      Control = 0.30,  Resilience = 20},

    {p = "bamboo",        Control = 0.05,  Resilience = 5},
    {p = "wooden",        Control = 0.05,  Resilience = 5},
    {p = "starter",       Control = 0.05,  Resilience = 5},
    {p = "stabilizer",    Control = 0.10,  Resilience = 20},
    {p = "enchanted",     Control = 0.10,  Resilience = 15},
    {p = "rod of",        Control = 0.15,  Resilience = 15},
    {p = "sanguine",      Control = 0.10,  Resilience = 15},
    {p = "chrysalis",     Control = 0.10,  Resilience = 15},
    {p = "polaris",       Control = 0.10,  Resilience = 15},
    {p = "eternal",       Control = 0.15,  Resilience = 20},
    {p = "poseidon",      Control = 0.15,  Resilience = 20},
    {p = "evil",          Control = 0.10,  Resilience = 10},
    {p = "pitchfork",     Control = 0.10,  Resilience = 10},
    {p = "shadow",        Control = 0.10,  Resilience = 15},
    {p = "wingripper",    Control = 0.10,  Resilience = 15},
    {p = "sword",         Control = 0.10,  Resilience = 10},
    {p = "rainbow",       Control = 0.10,  Resilience = 15},
    {p = "coral",         Control = 0.10,  Resilience = 15},
    {p = "brine",         Control = 0.10,  Resilience = 15},
    {p = "cursed",        Control = -0.05, Resilience = 10},
    {p = "corrupted",     Control = -0.05, Resilience = 10},
    {p = "infernal",      Control = 0.05,  Resilience = 10},
    {p = "gingerbread",   Control = 0.05,  Resilience = 10},
    {p = "candy cane",    Control = 0.05,  Resilience = 10},
    {p = "fischmas",      Control = 0.05,  Resilience = 10},
    {p = "jinglestar",    Control = 0.05,  Resilience = 10},
    {p = "north%-star",   Control = 0.05,  Resilience = 10},
    {p = "brick",         Control = 0.05,  Resilience = 10},
    {p = "adventurer",    Control = 0.05,  Resilience = 10},
    {p = "antler",        Control = 0.05,  Resilience = 10},
    {p = "brothers",      Control = 0.05,  Resilience = 10},
    {p = "buddy",         Control = 0.05,  Resilience = 10},
    {p = "fixer",         Control = 0.05,  Resilience = 10},
    {p = "superstar",     Control = 0.05,  Resilience = 10},
    {p = "patriot",       Control = 0.05,  Resilience = 10},
    {p = "demon",         Control = 0.10,  Resilience = 15},
    {p = "experimental",  Control = 0.10,  Resilience = 15},
    {p = "mission",       Control = 0.05,  Resilience = 10},
    {p = "paleontolog",   Control = 0.05,  Resilience = 10},
    {p = "frostfire",     Control = 0.05,  Resilience = 15},
    {p = "smurf",         Control = 0.05,  Resilience = 10},
    {p = "divine",        Control = 0.15,  Resilience = 20},
    {p = "masterline",    Control = 0.15,  Resilience = 20},
    {p = "zeus",          Control = 0.15,  Resilience = 20},
}

local function detectEquippedRod()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Tool")
end

local function readRodStats(rod)
    if not rod then
        return {Name = "None", Control = 0.2, Resilience = 0, Source = "default"}
    end

    local stats = {Name = rod.Name or "Unknown", Control = 0.2, Resilience = 0, Source = "default"}

    pcall(function()
        local attrs = rod:GetAttributes()
        if attrs then
            local ctrl = attrs.Control or attrs.control or attrs.ControlLevel
            if ctrl then
                stats.Control = tonumber(ctrl) or 0.2
                stats.Source = "attribute"
            end
        end
    end)
    if stats.Source == "attribute" then return stats end

    pcall(function()
        for _, child in ipairs(rod:GetChildren()) do
            local cname = string.lower(child.Name or "")
            if cname == "control" or cname == "controllevel" or cname == "controlstat" then
                if child:IsA("NumberValue") or child:IsA("IntValue") then
                    stats.Control = child.Value
                    stats.Source = "child_value"
                end
            end
        end
    end)
    if stats.Source == "child_value" then return stats end

    pcall(function()
        local paths = {
            ReplicatedStorage:FindFirstChild("Rods"),
            ReplicatedStorage:FindFirstChild("rods"),
            ReplicatedStorage:FindFirstChild("RodData"),
            ReplicatedStorage:FindFirstChild("Items"),
            ReplicatedStorage:FindFirstChild("Config"),
        }
        for _, folder in ipairs(paths) do
            if folder then
                local data = folder:FindFirstChild(rod.Name)
                if data then
                    local ctrl = data:FindFirstChild("Control") or data:FindFirstChild("control")
                    if ctrl and (ctrl:IsA("NumberValue") or ctrl:IsA("IntValue")) then
                        stats.Control = ctrl.Value
                        stats.Source = "replicated"
                        return
                    end
                    local ac = nil
                    pcall(function() ac = data:GetAttribute("Control") or data:GetAttribute("control") end)
                    if ac then
                        stats.Control = tonumber(ac) or 0.2
                        stats.Source = "replicated"
                        return
                    end
                end
            end
        end
    end)
    if stats.Source == "replicated" then return stats end

    local nameLower = ""
    pcall(function() nameLower = string.lower(rod.Name) end)
    for _, entry in ipairs(RodDatabase) do
        if string.find(nameLower, entry.p) then
            stats.Control = entry.Control
            stats.Resilience = entry.Resilience or 0
            stats.Source = "database"
            return stats
        end
    end

    stats.Source = "default"
    return stats
end

local function isUIActive(element)
    if not element then return false end
    local ok, pos = pcall(function() return element.AbsolutePosition end)
    return ok and pos and (pos.X > 0 or pos.Y > 0)
end

local function findActiveReel()
    local pg = getPlayerGui()
    if not pg then return nil, nil, nil, nil end
    local reelGui = pg:FindFirstChild("reel")
    if reelGui then
        local bar = reelGui:FindFirstChild("bar")
        if bar and isUIActive(bar) then
            local playerbar = bar:FindFirstChild("playerbar")
            local fish = bar:FindFirstChild("fish")
            local progress = bar:FindFirstChild("progress")
            if playerbar and fish then return playerbar, fish, bar, progress end
        end
    end
    return nil, nil, nil, nil
end

local function scanCurrentFish()
    pcall(function()
        local pg = getPlayerGui()
        if not pg then return end
        local reelGui = pg:FindFirstChild("reel")
        if not reelGui then return end

        local fishLabel = reelGui:FindFirstChild("fish")
        if fishLabel and fishLabel:IsA("TextLabel") then
            currentFish.Name = fishLabel.Text or "Unknown"
        end

        local bar = reelGui:FindFirstChild("bar")
        if bar then
            for _, obj in ipairs(bar:GetDescendants()) do
                local n = string.lower(obj.Name or "")
                if string.find(n, "spark") or string.find(n, "shiny") then
                    currentFish.Rarity = "Shiny"; return
                elseif string.find(n, "mutat") then
                    currentFish.Rarity = "Mutation"; return
                end
            end
            local fishElem = bar:FindFirstChild("fish")
            if fishElem and fishElem.BackgroundColor3 then
                local c = fishElem.BackgroundColor3
                if c.R > 0.8 and c.G < 0.3 and c.B < 0.3 then currentFish.Rarity = "Legendary"
                elseif c.R > 0.5 and c.G < 0.3 and c.B > 0.5 then currentFish.Rarity = "Mythical"
                elseif c.B > 0.6 and c.R < 0.3 then currentFish.Rarity = "Rare"
                elseif c.G > 0.6 and c.R < 0.4 and c.B < 0.4 then currentFish.Rarity = "Uncommon"
                else currentFish.Rarity = "Common" end
            end
        end
    end)
end

local function teleportTo(position)
    pcall(function()
        local character = LocalPlayer.Character
        if not character then
            local t = os.clock()
            repeat task.wait(0.1); character = LocalPlayer.Character
            until character or os.clock() - t > 10
        end
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            local t = os.clock()
            repeat task.wait(0.1); hrp = character:FindFirstChild("HumanoidRootPart")
            until hrp or os.clock() - t > 5
        end
        if hrp then hrp.Position = Vector3.new(position.X, position.Y, position.Z) end
    end)
end

local function getGameClock()
    local ok, hour, timeStr = pcall(function()
        local world = ReplicatedStorage:FindFirstChild("world")
        if world then
            local cycle = world:FindFirstChild("cycle")
            if cycle and cycle:IsA("StringValue") then
                local v = string.lower(cycle.Value or "")
                if v == "day" then return 12, "Day" end
                if v == "night" then return 0, "Night" end
            end
        end
        local ct = Lighting.ClockTime
        if ct and type(ct) == "number" then
            local h = math.floor(ct)
            local m = math.floor((ct - h) * 60)
            return ct, string.format("%02d:%02d", h, m)
        end
        local tod = Lighting.TimeOfDay
        if tod and type(tod) == "string" and tod ~= "" then
            local h, mn = string.match(tod, "^(%d+):(%d+)")
            if h then return tonumber(h) + (tonumber(mn) or 0) / 60, string.format("%02d:%02d", h, mn) end
        end
        local mam = Lighting:GetMinutesAfterMidnight()
        if mam and type(mam) == "number" then
            local h = math.floor(mam / 60)
            local mn = math.floor(mam % 60)
            return mam / 60, string.format("%02d:%02d", h, mn)
        end
        return nil, "Unknown"
    end)
    if ok and hour then return hour, timeStr end
    return nil, "Unknown"
end

local function isDaytime()
    local hour = getGameClock()
    if hour == nil then return true end
    return hour >= 6 and hour < 18
end

local function findTotemHotbarSlot(totemName)
    if totemName == "None" then return nil end
    local search = string.lower(string.gsub(totemName, " Totem", ""))
    local pg = getPlayerGui()
    if not pg then return nil end
    local backpack = pg:FindFirstChild("backpack")
    if not backpack then return nil end
    local hotbar = backpack:FindFirstChild("hotbar")
    if not hotbar then return nil end
    local slot = 0
    for _, btn in ipairs(hotbar:GetChildren()) do
        if btn:IsA("ImageButton") and btn.Name == "ItemTemplate" then
            slot = slot + 1
            local label = btn:FindFirstChild("ItemName")
            if label and label:IsA("TextLabel") then
                if label.Text ~= "" and string.find(string.lower(label.Text), search) then
                    return slot
                end
            end
        end
    end
    return nil
end

local function useTotem(totemName)
    if totemName == "None" then return false end
    local slot = findTotemHotbarSlot(totemName)
    if not slot then return false end
    local success = false
    pcall(function()
        local keys = {[1]=0x31,[2]=0x32,[3]=0x33,[4]=0x34,[5]=0x35,[6]=0x36,[7]=0x37,[8]=0x38,[9]=0x39}
        local key = keys[slot]
        if not key then return end
        keypress(key); task.wait(0.15); keyrelease(key); task.wait(0.6)
        mouse1press(); task.wait(0.15); mouse1release(); task.wait(2.0)
        lastTotemUse = os.clock()
        success = true
    end)
    return success
end

local function switchToRod()
    pcall(function() keypress(0x31); task.wait(0.1); keyrelease(0x31); task.wait(0.5) end)
end

local handleAutoReel, handleAutoCast

local function handleAutoTotem(myVersion)
    while myVersion == totemVersion do
        if Settings.AutoTotem then
            local isDay = isDaytime()
            if lastCycleWasDay == nil or lastCycleWasDay ~= isDay then
                lastCycleWasDay = isDay
                local totem = isDay and Settings.DayTotem or Settings.NightTotem
                if totem and totem ~= "None" then
                    local wasEnabled = Settings.Enabled
                    if wasEnabled then
                        Settings.Enabled = false
                        reelVersion = reelVersion + 1; castVersion = castVersion + 1
                        if isHolding then pcall(mouse1release); isHolding = false end
                        task.wait(0.5)
                    end
                    useTotem(totem)
                    switchToRod()
                    if wasEnabled then
                        Settings.Enabled = true
                        reelVersion = reelVersion + 1; castVersion = castVersion + 1
                        local rv, cv = reelVersion, castVersion
                        if Settings.AutoReel then task.spawn(function() handleAutoReel(rv) end) end
                        if Settings.AutoCast then task.spawn(function() handleAutoCast(cv) end) end
                    end
                end
            end
        end
        task.wait(5)
    end
end

local lastShakeClick = 0
local shakeRunning = false
local function startShakeThread()
    if shakeRunning then return end
    shakeRunning = true
    task.spawn(function()
        while true do
            local ok, err = pcall(function()
                while true do
                    threadHeartbeats.shake = os.clock()
                    if Settings.Enabled and Settings.AutoShake and isrbxactive() then
                        local pg = getPlayerGui()
                        if pg then
                            local shakeGui = pg:FindFirstChild("shakeui")
                            if shakeGui and shakeGui:IsA("ScreenGui") then
                                local safezone = shakeGui:FindFirstChild("safezone")
                                if safezone then
                                    isShaking = true
                                    if os.clock() - lastShakeClick >= 0.08 then
                                        keypress(0x0D); task.wait(0.01); keyrelease(0x0D)
                                        lastShakeClick = os.clock()
                                        task.wait(0.1)
                                    end
                                else isShaking = false end
                            else isShaking = false end
                        end
                        task.wait(0.02)
                    else
                        isShaking = false
                        task.wait(0.2)
                    end
                end
            end)
            if not ok then warn("[Fisch] Shake crashed: " .. tostring(err)) end
            task.wait(1)
        end
    end)
end
startShakeThread()

handleAutoCast = function(myVersion)
    local crashes = 0
    while myVersion == castVersion do
        local ok, err = pcall(function()
            while Settings.AutoCast and myVersion == castVersion do
                threadHeartbeats.cast = os.clock()

                if not isReeling and not isShaking then
                    local character = LocalPlayer.Character
                    if character and character:FindFirstChildOfClass("Tool") then
                        local playerbar = findActiveReel()
                        local shakeActive = false
                        local pg = getPlayerGui()
                        if pg then
                            local sg = pg:FindFirstChild("shakeui")
                            if sg and sg:IsA("ScreenGui") and sg:FindFirstChild("safezone") then
                                shakeActive = true
                            end
                        end
                        if not playerbar and not shakeActive and not isReeling then
                            if isrbxactive() then
                                if Settings.AutoPerfectCast then
                                    pcall(mouse1press); task.wait(Settings.PerfectCastHoldTime); pcall(mouse1release)
                                else
                                    pcall(mouse1press); task.wait(0.5); pcall(mouse1release)
                                end
                                task.wait(2.5)
                            end
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
        if ok then break end
        crashes = crashes + 1
        warn("[Fisch] Cast crashed (#" .. crashes .. "): " .. tostring(err))
        if crashes > 50 then warn("[Fisch] Cast giving up"); break end
        task.wait(1)
    end
end

handleAutoReel = function(myVersion)
    isHolding = false
    resetMemory()
    local reelStartTime = 0
    local crashes = 0

    while myVersion == reelVersion do
        local ok, err = pcall(function()
            while Settings.AutoReel and myVersion == reelVersion do
                threadHeartbeats.reel = os.clock()
                local playerbar, fish, bar, progress = findActiveReel()

                if playerbar and fish then
                    lastReelSeen = os.clock()

                    if not isReeling then
                        isReeling = true
                        reelStartTime = os.clock()
                        currentFish = {Name = "Unknown", Rarity = "-"}
                        resetMemory()
                    end

                    if isReeling and (os.clock() - reelStartTime) > 180 then
                        warn("[Fisch] Reel stuck for 3min, force resetting")
                        isReeling = false
                        pcall(function() if isHolding then mouse1release(); isHolding = false end end)
                        resetMemory()
                        reelStartTime = os.clock()
                    end

                    if os.clock() - lastFishScanTime >= 0.5 then
                        scanCurrentFish()
                        lastFishScanTime = os.clock()
                    end

                    local playerCenterX = playerbar.AbsolutePosition.X + (playerbar.AbsoluteSize.X / 2)
                    local fishCenterX = fish.AbsolutePosition.X + (fish.AbsoluteSize.X / 2)

                    addToMemory(fishMemory, fishCenterX, Settings.MemorySize)
                    addToMemory(barMemory, playerCenterX, Settings.MemorySize)

                    fishVelocity = calculateVelocity(fishMemory)
                    fishAccel = calculateAcceleration(fishMemory)
                    barVelocity = calculateVelocity(barMemory)

                    predictedFishX = predictPosition(fishCenterX, fishVelocity, fishAccel, Settings.PredictionFrames)

                    local slideOffset = isHolding and Settings.SlideCompensation or -Settings.SlideCompensation / 2
                    local effectiveDiff = predictedFishX - (playerCenterX + slideOffset)

                    addToMemory(errorMemory, effectiveDiff, Settings.ErrorMemorySize)
                    errorVelocity = calculateVelocity(errorMemory)

                    local errorPredictionFrames = Settings.ErrorPredictionTime / Settings.ReelPollRate
                    local predictedError = effectiveDiff + (errorVelocity * errorPredictionFrames)

                    local controlError = predictedError
                    local dynamicDeadzone = math.max(1, math.min(10, math.abs(fishVelocity) * 0.5))

                    local desiredDirection = nil
                    if controlError > dynamicDeadzone then
                        desiredDirection = true
                    elseif controlError < -dynamicDeadzone then
                        desiredDirection = false
                    end

                    if desiredDirection ~= nil and lastDirection ~= nil and desiredDirection ~= lastDirection then
                        if directionCooldown > 0 then
                            desiredDirection = lastDirection
                            directionCooldown = directionCooldown - 1
                        else
                            directionCooldown = Settings.DirectionChangeCooldown
                        end
                    else
                        if directionCooldown > 0 then
                            directionCooldown = directionCooldown - 1
                        end
                    end

                    if isrbxactive() then
                        if desiredDirection == true then
                            if not isHolding then pcall(mouse1press); isHolding = true end
                        elseif desiredDirection == false then
                            if isHolding then pcall(mouse1release); isHolding = false end
                        end
                    elseif isHolding then
                        pcall(mouse1release); isHolding = false
                    end

                    if desiredDirection ~= nil then lastDirection = desiredDirection end

                else
                    if isReeling then
                        if os.clock() - lastReelSeen >= 0.5 then
                            isReeling = false
                            Stats.TotalCatches = Stats.TotalCatches + 1
                            if currentFish.Rarity == "Shiny" then Stats.ShinyCount = Stats.ShinyCount + 1
                            elseif currentFish.Rarity == "Mutation" then Stats.MutationCount = Stats.MutationCount + 1 end
                            if currentFish.Rarity ~= "-" and currentFish.Rarity ~= "Common" then
                                Stats.BestCatch = currentFish.Name .. " (" .. currentFish.Rarity .. ")"
                            end
                            currentFish = {Name = "None", Rarity = "-"}
                            if isHolding then pcall(mouse1release); isHolding = false end
                            resetMemory()
                        end
                    else
                        if isHolding then pcall(mouse1release); isHolding = false end
                    end
                end

                task.wait(Settings.ReelPollRate)
            end
        end)
        if ok then break end
        crashes = crashes + 1
        warn("[Fisch] Reel crashed (#" .. crashes .. "): " .. tostring(err))
        pcall(function() if isHolding then mouse1release(); isHolding = false end end)
        isReeling = false
        resetMemory()
        if crashes > 50 then warn("[Fisch] Reel giving up"); break end
        task.wait(0.3)
    end

    pcall(function() if isHolding then mouse1release(); isHolding = false end end)
    isReeling = false
    resetMemory()
end

local function emergencyStop()
    Settings.Enabled = false
    Settings.AutoReel = false
    Settings.AutoCast = false
    Settings.AutoTotem = false
    reelVersion = reelVersion + 1; castVersion = castVersion + 1; totemVersion = totemVersion + 1
    pcall(function() if isHolding then mouse1release(); isHolding = false end end)
    isReeling = false; isShaking = false
    resetMemory()
    print("[Fisch] EMERGENCY STOP")
end

local function toggleAutoFish()
    Settings.Enabled = not Settings.Enabled
    if Settings.Enabled then
        print("[Fisch] AutoFish ON")
        if Settings.AutoReel then
            reelVersion = reelVersion + 1
            task.spawn(function() handleAutoReel(reelVersion) end)
        end
        if Settings.AutoCast then
            castVersion = castVersion + 1
            task.spawn(function() handleAutoCast(castVersion) end)
        end
    else
        print("[Fisch] AutoFish OFF")
        reelVersion = reelVersion + 1; castVersion = castVersion + 1
        pcall(function() if isHolding then mouse1release(); isHolding = false end end)
        resetMemory()
    end
end

local function IsInside(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

local function MakeSquare(x, y, w, h, color, filled, zindex, vis)
    local s = DrawNew("Square")
    s.Position = V2(x, y); s.Size = V2(w, h)
    s.Color = color; s.Filled = filled; s.Transparency = 1
    s.Visible = vis ~= false; s.ZIndex = zindex or 1
    return s
end

local function MakeLine(x1, y1, x2, y2, color, thick, zindex)
    local l = DrawNew("Line")
    l.From = V2(x1, y1); l.To = V2(x2, y2)
    l.Color = color; l.Thickness = thick or 1; l.Visible = true; l.ZIndex = zindex or 1
    return l
end

local function MakeText(x, y, text, color, size, font, center, zindex)
    local t = DrawNew("Text")
    t.Position = V2(x, y); t.Text = text; t.Color = color
    t.Size = size or 13; t.Font = font or Drawing.Fonts.System
    t.Center = center or false; t.Outline = false; t.Visible = true; t.ZIndex = zindex or 1
    return t
end

local function MakeCircle(x, y, r, color, filled, zindex, sides)
    local c = DrawNew("Circle")
    c.Position = V2(x, y); c.Radius = r; c.Color = color
    c.Filled = filled ~= false; c.NumSides = sides or 20
    c.Visible = true; c.ZIndex = zindex or 1
    return c
end

local function P(obj)
    insert(GUI.PanelElements, obj)
    return obj
end

local function DrawFishIcon(cx, cy, color, z)
    local icons = {}
    local function L(a,b,c,d,th) insert(icons, MakeLine(a,b,c,d,color,th or 1.5,z)) end
    L(cx-10,cy,cx-5,cy-6); L(cx-5,cy-6,cx+3,cy-5); L(cx+3,cy-5,cx+7,cy-2)
    L(cx+7,cy-2,cx+11,cy-5); L(cx+7,cy+2,cx+11,cy+5); L(cx+7,cy-2,cx+7,cy+2)
    L(cx-10,cy,cx-5,cy+6); L(cx-5,cy+6,cx+3,cy+5); L(cx+3,cy+5,cx+7,cy+2)
    insert(icons, MakeCircle(cx-6,cy-1,1.5,color,true,z+1,8))
    return icons
end

local function DrawWarpIcon(cx, cy, color, z)
    local icons = {}
    local function L(a,b,c,d,th) insert(icons, MakeLine(a,b,c,d,color,th or 1.5,z)) end
    local circ = MakeCircle(cx,cy,9,color,false,z,20); circ.Thickness = 1.5
    insert(icons, circ)
    L(cx,cy-7,cx-3,cy+2,2); L(cx,cy-7,cx+3,cy+2,2)
    L(cx,cy+7,cx-2,cy+3,1); L(cx,cy+7,cx+2,cy+3,1)
    return icons
end

local function DrawTotemIcon(cx, cy, color, z)
    local icons = {}
    local function L(a,b,c,d,th) insert(icons, MakeLine(a,b,c,d,color,th or 1.5,z)) end
    L(cx,cy-9,cx-6,cy-1); L(cx,cy-9,cx+6,cy-1)
    L(cx-6,cy-1,cx-4,cy+8); L(cx+6,cy-1,cx+4,cy+8)
    L(cx-4,cy+8,cx,cy+10); L(cx+4,cy+8,cx,cy+10)
    L(cx-6,cy-1,cx+6,cy-1,1); L(cx,cy-9,cx,cy+10,1)
    return icons
end

local TabDefs = {
    { name = "Auto",  iconFn = DrawFishIcon },
    { name = "Warp",  iconFn = DrawWarpIcon },
    { name = "Totem", iconFn = DrawTotemIcon },
}

local function CreateTab(name, index, drawIconFn)
    local tab = {}
    local xOff = Config.BarX + Config.TabGap + (index - 1) * (Config.TabWidth + Config.TabGap)
    local yOff = Config.BarY

    tab.Name = name; tab.Index = index
    tab.X = xOff; tab.Y = yOff
    tab.Width = Config.TabWidth; tab.Height = Config.BarHeight

    tab.Background = MakeSquare(xOff, yOff, Config.TabWidth, Config.BarHeight, Colors.TabNormal, true, 3)
    insert(GUI.Elements, tab.Background)

    local icx = xOff + Config.TabWidth / 2
    local icy = yOff + Config.IconCenterY
    tab.Icons = drawIconFn(icx, icy, Colors.IconNormal, 5)
    for _, ic in ipairs(tab.Icons) do insert(GUI.Elements, ic) end

    tab.Text = MakeText(xOff + Config.TabWidth/2, yOff + Config.TextY, name, Colors.TextNormal, 12, Drawing.Fonts.System, true, 5)
    insert(GUI.Elements, tab.Text)

    tab.Indicator = MakeSquare(xOff + 20, yOff + Config.BarHeight - 3, Config.TabWidth - 40, 2, Colors.Indicator, true, 7, false)
    insert(GUI.Elements, tab.Indicator)

    return tab
end

local function ClearPanel()
    for _, el in ipairs(GUI.PanelElements) do pcall(function() el:Remove() end) end
    GUI.PanelElements = {}
    GUI.Clickables = {}
    GUI.InfoRefs = {}
end

local CreatePanel

local function DrawToggle(px, py, isOn, z)
    local tw, th = Config.ToggleW, Config.ToggleH
    local halfH = th / 2
    local bg = P(MakeSquare(px + halfH, py, tw - th, th, isOn and Colors.ToggleOn or Colors.ToggleOff, true, z))
    P(MakeCircle(px + halfH, py + halfH, halfH, isOn and Colors.ToggleOn or Colors.ToggleOff, true, z, 24))
    P(MakeCircle(px + tw - halfH, py + halfH, halfH, isOn and Colors.ToggleOn or Colors.ToggleOff, true, z, 24))
    local knobR = halfH - 2
    local knobX = isOn and (px + tw - halfH) or (px + halfH)
    P(MakeCircle(knobX, py + halfH, knobR, Colors.ToggleKnob, true, z+2, 24))
    return bg
end

local function DrawButton(px, py, w, h, text, bgColor, textColor, z)
    P(MakeSquare(px, py, w, h, bgColor or Colors.BtnBg, true, z))
    local bdr = P(MakeSquare(px, py, w, h, Colors.BtnBorder, false, z+1))
    bdr.Thickness = 1
    P(MakeText(px + w/2, py + floor((h - 13) / 2) + 1, text, textColor or Colors.TextActive, 13, Drawing.Fonts.SystemBold, true, z+2))
end

local function InfoRow(px, py, label, value, z, valColor)
    P(MakeText(px, py + 1, label, Colors.InfoLabel, 11, Drawing.Fonts.System, false, z))
    P(MakeText(px + Config.InfoLabelW - 12, py + 1, ":", Colors.Separator, 11, Drawing.Fonts.System, false, z))
    return P(MakeText(px + Config.InfoLabelW, py + 1, value, valColor or Colors.InfoValue, 11, Drawing.Fonts.Monospace, false, z))
end

local function SectionSep(px, py, w, z)
    P(MakeLine(px, py, px + w, py, Colors.Separator, 1, z))
    P(MakeSquare(px, py - 1, 4, 3, Colors.SepAccent, true, z + 1))
end

local function SectionLabel(px, py, text, z)
    P(MakeSquare(px, py + 1, 2, 10, Colors.Accent, true, z + 1))
    P(MakeText(px + 8, py, text, Colors.DimText, 10, Drawing.Fonts.SystemBold, false, z))
end

local function CreateAutoPanel(px, py)
    local pad = Config.PanelPad
    local y = py + Config.HeaderH
    local cw = Config.PanelWidth - pad * 2
    local rh = Config.RowHeight
    local is = Config.InfoSpacing
    local toggleX = px + Config.PanelWidth - pad - Config.ToggleW
    local refs = GUI.InfoRefs

    local badgeW, badgeH = 54, 18
    local badgeX = px + Config.PanelWidth - pad - badgeW
    local badgeY = py + floor((Config.HeaderH - 20) / 2) - 2
    refs.statusBg = P(MakeSquare(badgeX, badgeY, badgeW, badgeH, Settings.Enabled and Colors.AccentDim or Colors.DangerDim, true, 13))
    refs.statusTxt = P(MakeText(badgeX + badgeW / 2, badgeY + 3, Settings.Enabled and "ACTIVE" or "IDLE", Settings.Enabled and Colors.Success or Colors.Danger, 10, Drawing.Fonts.SystemBold, true, 14))

    local textOff = floor((rh - 12) / 2)
    local toggleOff = floor((rh - Config.ToggleH) / 2)

    local function ToggleRow(yy, label, isOn, onClick)
        P(MakeText(px + pad, yy + textOff, label, isOn and Colors.TextActive or Colors.PanelText, 12, Drawing.Fonts.System, false, 13))
        DrawToggle(toggleX, yy + toggleOff, isOn, 13)
        insert(GUI.Clickables, { x = toggleX - 12, y = yy, w = Config.ToggleW + 24, h = rh, onClick = onClick })
        P(MakeLine(px + pad, yy + rh - 1, px + Config.PanelWidth - pad, yy + rh - 1, Colors.Separator, 1, 11))
        return yy + rh
    end

    y = ToggleRow(y, "Auto Fish", Settings.Enabled, function() toggleAutoFish(); CreatePanel("Auto") end)
    y = ToggleRow(y, "Auto Cast", Settings.AutoCast, function()
        Settings.AutoCast = not Settings.AutoCast; castVersion = castVersion + 1
        if Settings.AutoCast and Settings.Enabled then task.spawn(function() handleAutoCast(castVersion) end) end
        CreatePanel("Auto")
    end)
    y = ToggleRow(y, "Auto Shake", Settings.AutoShake, function() Settings.AutoShake = not Settings.AutoShake; CreatePanel("Auto") end)
    y = ToggleRow(y, "Auto Reel", Settings.AutoReel, function()
        Settings.AutoReel = not Settings.AutoReel; reelVersion = reelVersion + 1
        if Settings.AutoReel and Settings.Enabled then task.spawn(function() handleAutoReel(reelVersion) end) end
        CreatePanel("Auto")
    end)
    y = ToggleRow(y, "Perfect Cast", Settings.AutoPerfectCast, function() Settings.AutoPerfectCast = not Settings.AutoPerfectCast; CreatePanel("Auto") end)
    y = y + Config.SectionGapTop; SectionSep(px + pad, y, cw, 12); y = y + Config.SectionGapBot
    SectionLabel(px + pad, y, "ROD INFO", 13); y = y + 20
    refs.rodName    = InfoRow(px + pad, y, "Rod",     rodStats.Name or "None", 13); y = y + is
    refs.rodControl = InfoRow(px + pad, y, "Control", string.format("%.3f", rodStats.Control or 0.2), 13); y = y + is

    y = y + Config.SectionGapTop; SectionSep(px + pad, y, cw, 12); y = y + Config.SectionGapBot
    SectionLabel(px + pad, y, "STATUS", 13); y = y + 20
    refs.fishName   = InfoRow(px + pad, y, "Fish",     currentFish.Name or "None", 13); y = y + is
    refs.fishRarity = InfoRow(px + pad, y, "Rarity",   currentFish.Rarity or "-", 13); y = y + is
    refs.catches    = InfoRow(px + pad, y, "Catches",  tostring(Stats.TotalCatches), 13); y = y + is
    refs.specials   = InfoRow(px + pad, y, "Specials", Stats.ShinyCount .. "S / " .. Stats.MutationCount .. "M", 13); y = y + is
    refs.uptime     = InfoRow(px + pad, y, "Uptime",   formatTime(clock() - Stats.SessionStart), 13); y = y + is

    y = y + Config.SectionGapTop
    DrawButton(px + pad, y, cw, Config.BtnH, "EMERGENCY STOP", Colors.DangerDim, Colors.Danger, 13)
    insert(GUI.Clickables, { x = px + pad, y = y, w = cw, h = Config.BtnH, onClick = function() emergencyStop(); CreatePanel("Auto") end })
    y = y + Config.BtnH + 10

    P(MakeText(px + Config.PanelWidth / 2, y, "F6 Toggle  |  F5 Hide", Colors.DimText, 9, Drawing.Fonts.System, true, 13))
    y = y + 16
    return y - py + pad
end

local function CreateWarpPanel(px, py)
    local pad = Config.PanelPad
    local y = py + Config.HeaderH
    local cw = Config.PanelWidth - pad * 2
    local catName = warpCategories[warpCatIndex]
    local catIcon = warpCatIcons[catName] or ""

    local selH = 24
    P(MakeSquare(px + pad, y - 2, cw, selH + 4, Colors.BtnBg, true, 11))
    local selBdr = P(MakeSquare(px + pad, y - 2, cw, selH + 4, Colors.BtnBorder, false, 11))
    selBdr.Thickness = 1

    P(MakeText(px + pad + 10, y + 3, "<", Colors.Accent, 14, Drawing.Fonts.SystemBold, false, 14))
    insert(GUI.Clickables, { x = px + pad, y = y - 2, w = 30, h = selH + 4, onClick = function()
        warpCatIndex = warpCatIndex - 1; if warpCatIndex < 1 then warpCatIndex = #warpCategories end; CreatePanel("Warp")
    end })

    P(MakeText(px + Config.PanelWidth / 2, y + 4, catIcon .. "  " .. catName, Colors.Accent, 13, Drawing.Fonts.SystemBold, true, 14))

    P(MakeText(px + Config.PanelWidth - pad - 16, y + 3, ">", Colors.Accent, 14, Drawing.Fonts.SystemBold, false, 14))
    insert(GUI.Clickables, { x = px + Config.PanelWidth - pad - 30, y = y - 2, w = 30, h = selH + 4, onClick = function()
        warpCatIndex = warpCatIndex + 1; if warpCatIndex > #warpCategories then warpCatIndex = 1 end; CreatePanel("Warp")
    end })

    y = y + selH + 8
    SectionSep(px + pad, y, cw, 12)
    y = y + 10

    local gap = Config.WarpGap
    local colW = floor((cw - gap) / 2)
    local col1X = px + pad
    local col2X = px + pad + colW + gap
    local col = 0
    local btnH = Config.WarpBtnH

    for _, loc in ipairs(TeleportLocations) do
        if loc.Cat == catName then
            local bx = col == 0 and col1X or col2X
            local by = y

            P(MakeSquare(bx, by, colW, btnH, Colors.BtnBg, true, 12))
            local bdr = P(MakeSquare(bx, by, colW, btnH, Colors.BtnBorder, false, 12))
            bdr.Thickness = 1
            P(MakeCircle(bx + 9, by + btnH / 2, 2.5, Colors.Accent, true, 13, 10))

            local dn = loc.Name
            if #dn > 13 then dn = dn:sub(1, 12) .. ".." end
            P(MakeText(bx + 16, by + floor((btnH - 11) / 2), dn, Colors.TextActive, 11, Drawing.Fonts.System, false, 13))

            local lp = loc.Position
            insert(GUI.Clickables, { x = bx, y = by, w = colW, h = btnH, onClick = function() teleportTo(lp) end })

            col = col + 1
            if col >= 2 then col = 0; y = y + btnH + gap end
        end
    end
    if col == 1 then y = y + btnH + gap end
    return y - py + pad
end

local function DrawDropdown(px, py, cw, selectedText, isOpen, items, onSelect, onToggle)
    local selH = 24
    local z = 20

    P(MakeSquare(px, py, cw, selH, Colors.BtnBg, true, z))
    local bdr = P(MakeSquare(px, py, cw, selH, Colors.BtnBorder, false, z))
    bdr.Thickness = 1

    local label = selectedText
    if #label > 22 then label = label:sub(1, 21) .. ".." end
    P(MakeText(px + 10, py + 5, label, Colors.TextActive, 12, Drawing.Fonts.System, false, z + 1))
    P(MakeText(px + cw - 18, py + 5, isOpen and "^" or "v", Colors.Accent, 12, Drawing.Fonts.SystemBold, false, z + 1))

    insert(GUI.Clickables, { x = px, y = py, w = cw, h = selH, onClick = onToggle })

    local totalH = selH
    if isOpen then
        local itemH = Config.DropdownItemH
        local count = #items
        local listH = count * itemH
        local listY = py + selH + 2

        P(MakeSquare(px, listY, cw, listH, Colors.PanelBg, true, z + 2))
        local lbdr = P(MakeSquare(px, listY, cw, listH, Colors.BtnBorder, false, z + 2))
        lbdr.Thickness = 1

        for i = 1, count do
            local iy = listY + (i - 1) * itemH
            local name = items[i]
            local isSel = (name == selectedText)

            if isSel then
                P(MakeSquare(px + 1, iy, cw - 2, itemH, Colors.AccentDim, true, z + 3))
            end

            local dn = name
            if #dn > 24 then dn = dn:sub(1, 23) .. ".." end
            P(MakeText(px + 10, iy + 4, dn, isSel and Colors.Accent or Colors.PanelText, 11, Drawing.Fonts.System, false, z + 4))

            insert(GUI.Clickables, { x = px, y = iy, w = cw, h = itemH, onClick = function()
                onSelect(i, name)
            end })
        end

        totalH = selH + 2 + listH
    end
    return totalH
end

local function CreateTotemPanel(px, py)
    local pad = Config.PanelPad
    local y = py + Config.HeaderH
    local cw = Config.PanelWidth - pad * 2
    local rh = Config.RowHeight
    local is = Config.InfoSpacing
    local toggleX = px + Config.PanelWidth - pad - Config.ToggleW
    local refs = GUI.InfoRefs

    local textOff = floor((rh - 12) / 2)
    local toggleOff = floor((rh - Config.ToggleH) / 2)
    P(MakeText(px + pad, y + textOff, "Auto Totem", Settings.AutoTotem and Colors.TextActive or Colors.PanelText, 12, Drawing.Fonts.System, false, 13))
    DrawToggle(toggleX, y + toggleOff, Settings.AutoTotem, 13)
    insert(GUI.Clickables, { x = toggleX - 12, y = y, w = Config.ToggleW + 24, h = rh, onClick = function()
        Settings.AutoTotem = not Settings.AutoTotem; totemVersion = totemVersion + 1
        if Settings.AutoTotem then task.spawn(function() handleAutoTotem(totemVersion) end) end
        CreatePanel("Totem")
    end })
    y = y + rh + 6

    SectionSep(px + pad, y, cw, 12); y = y + Config.SectionGapBot
    SectionLabel(px + pad, y, "DAY TOTEM", 13); y = y + 20

    local dayH = DrawDropdown(px + pad, y, cw, Settings.DayTotem, dayDropOpen, availableTotems,
        function(idx, name)
            dayTotemIndex = idx
            Settings.DayTotem = name
            dayDropOpen = false
            CreatePanel("Totem")
        end,
        function()
            dayDropOpen = not dayDropOpen
            if dayDropOpen then nightDropOpen = false end
            CreatePanel("Totem")
        end
    )
    y = y + dayH + 8

    SectionSep(px + pad, y, cw, 12); y = y + Config.SectionGapBot
    SectionLabel(px + pad, y, "NIGHT TOTEM", 13); y = y + 20

    local nightH = DrawDropdown(px + pad, y, cw, Settings.NightTotem, nightDropOpen, availableTotems,
        function(idx, name)
            nightTotemIndex = idx
            Settings.NightTotem = name
            nightDropOpen = false
            CreatePanel("Totem")
        end,
        function()
            nightDropOpen = not nightDropOpen
            if nightDropOpen then dayDropOpen = false end
            CreatePanel("Totem")
        end
    )
    y = y + nightH + 8

    SectionSep(px + pad, y, cw, 12); y = y + Config.SectionGapBot
    SectionLabel(px + pad, y, "GAME TIME", 13); y = y + 20

    local isDay = isDaytime()
    local _, timeStr = getGameClock()
    refs.totemCycle = InfoRow(px + pad, y, "Cycle", isDay and "DAY" or "NIGHT", 13, isDay and Colors.Warning or Colors.Accent)
    y = y + is
    refs.totemTime = InfoRow(px + pad, y, "Time", timeStr or "--:--", 13)
    y = y + is
    return y - py + pad
end

CreatePanel = function(tabName)
    ClearPanel()
    if tabName ~= "Totem" then
        dayDropOpen = false; nightDropOpen = false
    end
    local pad = Config.PanelPad
    local panelX = Config.BarX + floor((Config.BarWidth - Config.PanelWidth) / 2)
    local panelY = Config.BarY + Config.BarHeight + Config.GlowH + Config.PanelGap
    local panelH = 400

    if tabName == "Auto"  then panelH = CreateAutoPanel(panelX, panelY)
    elseif tabName == "Warp"  then panelH = CreateWarpPanel(panelX, panelY)
    elseif tabName == "Totem" then panelH = CreateTotemPanel(panelX, panelY)
    end

    P(MakeSquare(panelX, panelY, Config.PanelWidth, panelH, Colors.PanelBg, true, 8))
    local bdr = P(MakeSquare(panelX, panelY, Config.PanelWidth, panelH, Colors.PanelBorder, false, 9))
    bdr.Thickness = 1

    P(MakeLine(panelX + 1, panelY + 1, panelX + Config.PanelWidth - 1, panelY + 1, C3(40, 42, 52), 1, 10))

    P(MakeText(panelX + pad, panelY + 14, tabName, Colors.PanelHeader, 14, Drawing.Fonts.SystemBold, false, 12))
    local underW = #tabName * 8 + 4
    P(MakeLine(panelX + pad, panelY + 34, panelX + pad + underW, panelY + 34, Colors.Accent, 2, 12))
    P(MakeLine(panelX + pad, panelY + 40, panelX + Config.PanelWidth - pad, panelY + 40, Colors.Separator, 1, 11))
end

local function UpdateTab(tab, isSelected, isHovered)
    if isSelected then
        tab.Background.Color = Colors.TabActive
        tab.Text.Color = Colors.TextActive
        tab.Indicator.Visible = true
        for _, ic in ipairs(tab.Icons) do ic.Color = Colors.IconActive end
    elseif isHovered then
        tab.Background.Color = Colors.TabHover
        tab.Text.Color = Colors.TextActive
        tab.Indicator.Visible = false
        for _, ic in ipairs(tab.Icons) do ic.Color = Colors.TextActive end
    else
        tab.Background.Color = Colors.TabNormal
        tab.Text.Color = Colors.TextNormal
        tab.Indicator.Visible = false
        for _, ic in ipairs(tab.Icons) do ic.Color = Colors.IconNormal end
    end
end

local function InitBar()
    insert(GUI.Elements, MakeSquare(Config.BarX, Config.BarY, Config.BarWidth, Config.BarHeight, Colors.BarBg, true, 1))
    local bdr = MakeSquare(Config.BarX, Config.BarY, Config.BarWidth, Config.BarHeight, Colors.BarBorder, false, 2)
    bdr.Thickness = 1; insert(GUI.Elements, bdr)

    insert(GUI.Elements, MakeLine(Config.BarX + 1, Config.BarY + 1, Config.BarX + Config.BarWidth - 1, Config.BarY + 1, C3(30, 32, 42), 1, 3))

    insert(GUI.Elements, MakeSquare(Config.BarX, Config.BarY + Config.BarHeight, Config.BarWidth, Config.GlowH, Colors.BarGlow, true, 2))

    for s = 1, #TabDefs - 1 do
        local sepX = Config.BarX + Config.TabGap + s * (Config.TabWidth + Config.TabGap)
        insert(GUI.Elements, MakeLine(sepX, Config.BarY + 16, sepX, Config.BarY + Config.BarHeight - 16, Colors.Separator, 1, 4))
    end

    GUI.Tabs = {}
    for i, def in ipairs(TabDefs) do GUI.Tabs[i] = CreateTab(def.name, i, def.iconFn) end
    for _, tab in ipairs(GUI.Tabs) do UpdateTab(tab, false, false) end
end

local function MoveBar(dx, dy)
    Config.BarX = Config.BarX + dx; Config.BarY = Config.BarY + dy
    for _, el in ipairs(GUI.Elements) do
        if el.Position then el.Position = V2(el.Position.X + dx, el.Position.Y + dy) end
        if el.From then el.From = V2(el.From.X + dx, el.From.Y + dy); el.To = V2(el.To.X + dx, el.To.Y + dy) end
    end
    for _, tab in ipairs(GUI.Tabs) do tab.X = tab.X + dx; tab.Y = tab.Y + dy end
    for _, el in ipairs(GUI.PanelElements) do
        if el.Position then el.Position = V2(el.Position.X + dx, el.Position.Y + dy) end
        if el.From then el.From = V2(el.From.X + dx, el.From.Y + dy); el.To = V2(el.To.X + dx, el.To.Y + dy) end
    end
    for _, c in ipairs(GUI.Clickables) do c.x = c.x + dx; c.y = c.y + dy end
end

InitBar()

task.spawn(function()
    local wasF5, wasF6 = false, false
    local infoTick = 0

    while true do
        pcall(function()
            local mx, my = Mouse.X, Mouse.Y
            local mouseDown = false
            pcall(function() mouseDown = ismouse1pressed() end)
            if not mouseDown then pcall(function() mouseDown = iskeypressed(VK_MOUSE1) end) end
            local justPressed = mouseDown and not GUI.WasMouseDown

            local f5 = false
            pcall(function() f5 = iskeypressed(VK_F5) end)
            if f5 and not wasF5 then
                GUI.Visible = not GUI.Visible
                for _, el in ipairs(GUI.Elements) do pcall(function() el.Visible = GUI.Visible end) end
                if not GUI.Visible then ClearPanel(); GUI.SelectedTab = nil
                elseif GUI.SelectedTab then CreatePanel(GUI.SelectedTab) end
            end
            wasF5 = f5

            local f6 = false
            pcall(function() f6 = iskeypressed(toggleVK) end)
            if f6 and not wasF6 then toggleAutoFish(); if GUI.SelectedTab == "Auto" then CreatePanel("Auto") end end
            wasF6 = f6

            if not GUI.Visible then GUI.WasMouseDown = mouseDown; return end

            local onBar = IsInside(mx, my, Config.BarX, Config.BarY, Config.BarWidth, Config.BarHeight)

            if GUI.Dragging then
                if mouseDown then
                    local ddx = mx - GUI.DragOffsetX - Config.BarX
                    local ddy = my - GUI.DragOffsetY - Config.BarY
                    if ddx ~= 0 or ddy ~= 0 then MoveBar(ddx, ddy) end
                else GUI.Dragging = false end
            end

            if justPressed then
                local handled = false
                for _, c in ipairs(GUI.Clickables) do
                    if IsInside(mx, my, c.x, c.y, c.w, c.h) then c.onClick(); handled = true; break end
                end
                if not handled and onBar and not GUI.Dragging then
                    local onTab = false
                    for _, tab in ipairs(GUI.Tabs) do
                        if IsInside(mx, my, tab.X, tab.Y, tab.Width, tab.Height) then
                            onTab = true
                            if GUI.SelectedTab == tab.Name then GUI.SelectedTab = nil; ClearPanel()
                            else GUI.SelectedTab = tab.Name; CreatePanel(tab.Name) end
                            break
                        end
                    end
                    if not onTab then
                        GUI.Dragging = true
                        GUI.DragOffsetX = mx - Config.BarX; GUI.DragOffsetY = my - Config.BarY
                    end
                end
            end

            for _, tab in ipairs(GUI.Tabs) do
                UpdateTab(tab, GUI.SelectedTab == tab.Name, IsInside(mx,my,tab.X,tab.Y,tab.Width,tab.Height) and not GUI.Dragging)
            end

            infoTick = infoTick + 1
            if infoTick >= 3 then
                infoTick = 0
                local refs = GUI.InfoRefs
                if GUI.SelectedTab == "Auto" and refs then
                    pcall(function()
                        if refs.statusBg then refs.statusBg.Color = Settings.Enabled and Colors.AccentDim or Colors.DangerDim end
                        if refs.statusTxt then
                            refs.statusTxt.Text = Settings.Enabled and "ACTIVE" or "IDLE"
                            refs.statusTxt.Color = Settings.Enabled and Colors.Success or Colors.Danger
                        end
                        if refs.rodName    then refs.rodName.Text = rodStats.Name or "None" end
                        if refs.rodControl then refs.rodControl.Text = string.format("%.3f", rodStats.Control or 0.2) end

                        if refs.fishName   then refs.fishName.Text = currentFish.Name or "None" end
                        if refs.fishRarity then
                            local r = currentFish.Rarity or "-"
                            refs.fishRarity.Text = r
                            refs.fishRarity.Color = r == "Shiny" and Colors.RarityShiny or r == "Mythical" and Colors.RarityMythical or r == "Legendary" and Colors.RarityLegend or r == "Rare" and Colors.RarityRare or Colors.InfoValue
                        end
                        if refs.catches  then refs.catches.Text = tostring(Stats.TotalCatches) end
                        if refs.specials then refs.specials.Text = Stats.ShinyCount .. "S / " .. Stats.MutationCount .. "M" end
                        if refs.uptime   then refs.uptime.Text = formatTime(clock() - Stats.SessionStart) end

                    end)
                elseif GUI.SelectedTab == "Totem" and refs then
                    pcall(function()
                        local isDay = isDaytime()
                        local _, ts = getGameClock()
                        if refs.totemCycle then refs.totemCycle.Text = isDay and "DAY" or "NIGHT"; refs.totemCycle.Color = isDay and Colors.Warning or Colors.Accent end
                        if refs.totemTime then refs.totemTime.Text = ts or "--:--" end
                    end)
                end
            end

            GUI.WasMouseDown = mouseDown
        end)
        task.wait(1/30)
    end
end)

local lastRodName = ""
task.spawn(function()
    while true do
        pcall(function()
            local rod = detectEquippedRod()
            local name = rod and rod.Name or "None"
            if name ~= lastRodName then
                lastRodName = name; currentRod = rod; rodStats = readRodStats(rod)
                print(string.format("[Fisch] Rod: %s | Control: %.3f (%s)", rodStats.Name, rodStats.Control, rodStats.Source))
            end
        end)
        task.wait(2)
    end
end)

task.spawn(function()
    task.wait(3)
    while true do
        pcall(function()
            if Settings.Enabled then
                local now = clock()
                if Settings.AutoReel and threadHeartbeats.reel > 0 and (now - threadHeartbeats.reel) > HEARTBEAT_TIMEOUT then
                    warn("[Watchdog] Reel dead, restarting"); reelVersion = reelVersion + 1; threadHeartbeats.reel = now
                    task.spawn(function() handleAutoReel(reelVersion) end)
                end
                if Settings.AutoCast and threadHeartbeats.cast > 0 and (now - threadHeartbeats.cast) > HEARTBEAT_TIMEOUT then
                    warn("[Watchdog] Cast dead, restarting"); castVersion = castVersion + 1; threadHeartbeats.cast = now
                    task.spawn(function() handleAutoCast(castVersion) end)
                end
                if Settings.AutoShake and threadHeartbeats.shake > 0 and (now - threadHeartbeats.shake) > HEARTBEAT_TIMEOUT then
                    warn("[Watchdog] Shake dead, restarting"); threadHeartbeats.shake = now; shakeRunning = false; startShakeThread()
                end
            end
        end)
        task.wait(5)
    end
end)

task.spawn(function()
    while true do pcall(collectgarbage, "step", 50); task.wait(5) end
end)

local function cleanup()
    Settings.Enabled = false; Settings.AutoTotem = false
    dayDropOpen = false; nightDropOpen = false
    reelVersion = reelVersion + 1; castVersion = castVersion + 1; totemVersion = totemVersion + 1
    pcall(function() if isHolding then mouse1release(); isHolding = false end end)
    for _, el in ipairs(GUI.PanelElements) do pcall(function() el:Remove() end) end
    for _, el in ipairs(GUI.Elements) do pcall(function() el:Remove() end) end
    GUI.PanelElements = {}; GUI.Elements = {}; GUI.Clickables = {}; GUI.Tabs = {}; GUI.InfoRefs = {}
    if getgenv then getgenv().FischRunning = false end
    print("[Fisch] Cleaned up")
end

if getgenv then getgenv().FischCleanup = cleanup end

print("[Fisch] Loaded | F5 Show/Hide | F6 Toggle")
