local ADDON_NAME, ns = ...

-- The buddy frame's glow, split out under 6.7. One export and one caller:
-- the cheapest cut in the file, and the reason it was worth making at all.

-- ─── Marching ants ───────────────────────────────────────────────────────────
--
-- A dashed border that scrolls around the icon while the aura is up. The
-- approach is EllesmereUI's, from EllesmereUI_Glows.lua, and it exists because
-- the obvious libraries do not work here: LibCustomGlow's PixelGlow drives
-- itself from an OnUpdate that reads IsShown() every frame, and that read is
-- forbidden on an aura button's subtree, so it freezes mid-march.
--
-- Everything below is therefore C-side. Four Translation animations, started
-- once inside the creation window, then never touched again -- no per-frame Lua
-- to be blocked, in restricted content or out of it.
local DASH_H = "Interface\\AddOns\\PriestAssist\\Media\\glow-dash-h.tga"
local DASH_V = "Interface\\AddOns\\PriestAssist\\Media\\glow-dash-v.tga"
local DASH_MASK = "Interface\\Buttons\\WHITE8X8"

-- Glow colours the panel offers. They are palette names, so the value stored in
-- the database is looked up rather than trusted -- an unknown one falls back to
-- gold instead of colouring the border with whatever GetColorRGB makes of it.
--
-- "accent" used to be here and was removed: the theme registers white over the
-- palette's accent, so it had become a second White.
-- Public because BuddyFrame.lua validates the stored name against it before
-- asking for the colour; the table moved here with the glow, the check did not.
ns.GLOW_COLORS = {
    gold   = true,
    white  = true,
    danger = true,
}

local ANT_COUNT = 8      -- dashes distributed around the whole perimeter
local ANT_THICKNESS = 2
local ANT_PERIOD = 4     -- seconds for one full lap

-- Each edge gets a strip one dash-cycle longer than the edge itself, a mask
-- clipping it back to the edge, and a translation of exactly one cycle. The
-- strip snaps back where the pattern repeats, so the loop is invisible and the
-- march is seamless.
--
-- The per-edge texture coordinates carry the running perimeter position, which
-- is what keeps the dashes continuous around the corners instead of each edge
-- starting its own pattern.
function ns.StartMarchingAnts(host, size, r, g, b)
    local perimeter = 4 * size
    local cycle = perimeter / ANT_COUNT       -- pixels per dash
    local step = ANT_PERIOD / ANT_COUNT       -- seconds per dash
    local span = (size + cycle) / cycle       -- strip length in texture repeats

    -- Clockwise from the top. `base` is where this edge sits along the
    -- perimeter, measured in dashes.
    local edges = {
        { tex = DASH_H, dx =  cycle, dy = 0,      vertical = false, base = 0 },
        { tex = DASH_V, dx = 0,      dy = -cycle, vertical = true,  base = size / cycle },
        { tex = DASH_H, dx = -cycle, dy = 0,      vertical = false, base = 2 * size / cycle },
        { tex = DASH_V, dx = 0,      dy =  cycle, vertical = true,  base = 3 * size / cycle },
    }

    for index, edge in ipairs(edges) do
        local mask = host:CreateMaskTexture()
        mask:SetTexture(DASH_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

        local strip = host:CreateTexture(nil, "OVERLAY", nil, 7)
        strip:SetTexture(edge.tex, "REPEAT", "REPEAT")
        strip:SetVertexColor(r, g, b, 1)
        strip:AddMaskTexture(mask)

        if edge.vertical then
            mask:SetSize(ANT_THICKNESS, size)
            strip:SetSize(ANT_THICKNESS, size + cycle)
            strip:SetTexCoord(0, 1, edge.base, edge.base + span)

            if index == 2 then
                mask:SetPoint("TOPRIGHT")
                strip:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, cycle)
            else
                mask:SetPoint("BOTTOMLEFT")
                strip:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", 0, -cycle)
            end
        else
            mask:SetSize(size, ANT_THICKNESS)
            strip:SetSize(size + cycle, ANT_THICKNESS)
            strip:SetTexCoord(edge.base, edge.base + span, 0, 1)

            if index == 1 then
                mask:SetPoint("TOPLEFT")
                strip:SetPoint("TOPLEFT", host, "TOPLEFT", -cycle, 0)
            else
                mask:SetPoint("BOTTOMLEFT")
                strip:SetPoint("BOTTOMLEFT")
            end
        end

        local group = strip:CreateAnimationGroup()
        group:SetLooping("REPEAT")

        local translation = group:CreateAnimation("Translation")
        translation:SetSmoothing("NONE")
        translation:SetOffset(edge.dx, edge.dy)
        translation:SetDuration(step)

        group:Play()
    end
end
