local L = LibStub("AceLocale-3.0"):NewLocale("ChonkyBirb", "enUS", true)
if not L then return end

-- Resource names
L["Health"] = true
L["Mana"] = true
L["Rage"] = true
L["Energy"] = true
L["Focus"] = true
L["Runic Power"] = true
L["Runes"] = true
L["Astral Power"] = true
L["Soul Shards"] = true
L["Soul Fragments"] = true
L["Holy Power"] = true
L["Chi"] = true
L["Insanity"] = true
L["Maelstrom"] = true
L["Fury"] = true
L["Combo Points"] = true
L["Arcane Charges"] = true
L["Essence"] = true
L["Stagger"] = true
L["Stagger Colors"] = true
L["Light"] = true
L["Moderate"] = true
L["Heavy"] = true
L["Maelstrom Weapon"] = true

-- Tabs / sections
L["General"] = true
L["Bars"] = true
L["Profiles"] = true

-- General options
L["Unlock"] = true
L["Lock"] = true
L["Unlock bars to drag and position them; every bar is shown while unlocked."] = true
L["Link bars"] = true
L["Drag one bar and they all move together."] = true
L["Move group"] = true
L["Bars unlocked — drag or use the sliders to move them."] = true

-- Global defaults (font / border / background for all bars; per-bar settings override)
L["Default appearance (all bars)"] = true
L["Default Font"] = true
L["Default Border"] = true
L["Default Background"] = true
L["Reset to default"] = true
L["Clear this bar's border & background overrides so they follow the global defaults."] = true
L["Clear this text's font overrides so it follows the global default font."] = true
L["Strata"] = true
L["Display layer. A bar on a higher strata fully covers a lower one (text included)."] = true
L["Copy settings from"] = true
L["Copy another bar's look + position onto this one. Tags, visibility and the enabled state are kept."] = true
L["Cast Prediction"] = true
L["Predict cast generation"] = true
L["While casting, preview the resource the cast will generate as a ghost segment."] = true
L["Prediction Color"] = true
L["Color and opacity of the cast-prediction ghost."] = true
L["Bar Color + Opacity"] = true
L["Custom Color"] = true
L["Opacity"] = true

-- Value markers
L["Markers"] = true
L["Marker"] = true
L["Add Marker"] = true
L["Value"] = true
L["Position of the marker, in resource value."] = true
L["Marker thickness."] = true
L["Bar Height"] = true
L["Custom Height"] = true
L["Marker Color"] = true
L["Marker color and opacity."] = true
L["All spells are known"] = true
L["At least one spell is known"] = true
L["No spell is known"] = true
L["Add Spell"] = true
L["Spell ID, name, or a shift-clicked talent link."] = true
L["Marker Type"] = true
L["Static Value"] = true
L["Spell Cost"] = true
L["Spell"] = true
L["Count"] = true
L["Places markers at 1x, 2x, 3x... the spell's cost."] = true
L["Cost:"] = true
L["No flat cost found for this bar's resource."] = true

-- Per-bar options
L["Enabled"] = true
L["Width"] = true
L["Height"] = true
L["Position"] = true
L["Position X"] = true
L["Position Y"] = true
L["Scale"] = true
L["Bar Texture"] = true
L["Bar Color"] = true
L["Background Texture"] = true
L["Background Color"] = true
L["Border Texture"] = true
L["Border Size"] = true
L["Border Color"] = true
L["Fill Direction"] = true
L["Segment Spacing"] = true
L["Gap between segments, in pixels."] = true
L["Inactive Segments"] = true
L["Inactive Segment Color"] = true
L["Color + Opacity"] = true
L["Recharge Display"] = true
L["Recharge Color"] = true

-- Color by percent
L["Color Mode"] = true
L["Static"] = true
L["By Percent"] = true
L["The bar recolors based on its fill percentage."] = true
L["Color by percent"] = true
L["Curve Type"] = true
L["Sharp Steps"] = true
L["Smooth Gradient"] = true
L["Add Color"] = true
L["Color"] = true
L["Font"] = true
L["Font Size"] = true
L["Outline"] = true
L["Font Color"] = true

-- Fill directions
L["Left to Right"] = true
L["Right to Left"] = true
L["Bottom to Top"] = true
L["Top to Bottom"] = true

-- Font outline / shadow
L["None"] = true
L["Outline"] = true
L["Thick Outline"] = true
L["Shadow"] = true
L["Shadow Color"] = true
L["Shadow X"] = true
L["Shadow Y"] = true

-- Text fields
L["Text"] = true
L["Texts"] = true
L["Add Text"] = true
L["Remove"] = true
L["Anchor"] = true
L["X"] = true
L["Y"] = true
L["Tags"] = true

-- Text tags: bar-relative, name + mouseover description
L["Current Value"] = true
L["Max Value"] = true
L["Current / Max"] = true
L["Percent"] = true
L["Deficit"] = true
L["Current (full)"] = true
L["Max (full)"] = true
L["Current / Max (full)"] = true
L["Resource Name"] = true
L["Current value of this bar's resource (short form)."] = true
L["Maximum value of this bar's resource (short form)."] = true
L["Current and maximum, shown as cur/max (short form)."] = true
L["Current value as a percentage (0-100%)."] = true
L["Missing amount (max minus current)."] = true
L["Current value, full number (not abbreviated)."] = true
L["Maximum value, full number (not abbreviated)."] = true
L["Current and maximum as cur/max, full numbers."] = true
L["Name of the resource (e.g. Energy)."] = true

-- Text tags: absolute class resources
L["Current number of combo points."] = true
L["Current number of soul shards."] = true
L["Current holy power."] = true
L["Current number of Chi."] = true
L["Current number of arcane charges."] = true
L["Current number of ready runes."] = true
L["Current runic power."] = true
L["Current number of essence."] = true
L["Current insanity."] = true
L["Current maelstrom."] = true
L["Current astral power."] = true
L["Current fury."] = true
L["Current mana."] = true

-- Visibility
L["Visibility"] = true
L["Show"] = true
L["Always"] = true
L["Automatic"] = true
L["Never"] = true
L["Custom"] = true
L["Automatic shows the bar only while its resource is relevant (forms, spec)."] = true
L["The bar shows when any checked condition is true."] = true
L["Auto-hide all bars while"] = true
L["In Vehicle"] = true
L["Pet Battle"] = true
L["Blizzard frames"] = true
L["Hide Blizzard Resource Bars"] = true
L["Hide Blizzard's detached resource bars."] = true

-- Visibility condition sections
L["Combat & Target"] = true
L["PvP"] = true
L["Mount"] = true
L["Druid Forms"] = true

-- Visibility conditions
L["In Combat"] = true
L["Has Target"] = true
L["Hostile Target"] = true
L["Attackable Target"] = true
L["Friendly Target"] = true
L["Group"] = true
L["Instance"] = true
L["In Any Group"] = true
L["In Raid Group"] = true
L["In Instance"] = true
L["In Dungeon"] = true
L["In Raid"] = true
L["In Battleground"] = true
L["In Arena"] = true
L["PvP Flagged"] = true
L["War Mode"] = true
L["Mounted"] = true
L["Flying"] = true
L["Cat Form"] = true
L["Bear Form"] = true
L["Moonkin Form"] = true
L["Travel Form (Stag)"] = true
L["Aquatic Form"] = true
L["Flight Form"] = true
L["Swift Flight Form"] = true
L["Travel Form (Any)"] = true
L["Humanoid Form"] = true
