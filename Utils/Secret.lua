local ADDON_NAME, ns = ...

-- ─── Secret values ───────────────────────────────────────────────────────────
-- Since 12.0 the client hands out values that may be held and passed on but
-- never read. `find`, `match`, indexing and even a boolean test throw at once,
-- and the type is no help: a secret string still answers "string" to `type`,
-- and a secret boolean exists too. `issecretvalue` is the only safe question.
--
-- Loaded before every other file in the addon, because there is no useful
-- order in which a safety check comes second.
function ns.IsSecretValue(value)
    return issecretvalue ~= nil and issecretvalue(value)
end
