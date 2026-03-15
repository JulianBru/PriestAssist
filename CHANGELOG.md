# Priest Assist

## [1.0](https://github.com/Slothpala/PIMG/tree/1.0) (2026-03-15)

- Added an option to hide the minimap button
- Set the addon version to `1.0` for release

## [1.2.9](https://github.com/Slothpala/PIMG/tree/1.2.9) (2026-03-15)

- Renamed the visible addon name from `PIMG` to `Priest Assist`
- Added `/passist` and `/pras` as additional slash command aliases while keeping `/pim`
- Updated the config window title, reminder title, minimap tooltip, and macro name to match the new branding

## [1.2.8](https://github.com/Slothpala/PIMG/tree/1.2.8) (2026-03-15)

- Switched back to the externally installed `AbstractFramework` as the primary UI backend
- Added a built-in fallback UI so PIMG still loads and remains configurable when `AbstractFramework` is not installed
- Removed the embedded framework loader from the TOC

## [1.2.7](https://github.com/Slothpala/PIMG/tree/1.2.7) (2026-03-15)

- Embedded the required AbstractFramework files under `Libs/AbstractFramework`
- Removed the external `AbstractFramework` addon dependency from the TOC
- Patched the embedded framework to initialize inside `PIMG` and load its media from the embedded library path

## [1.2.6](https://github.com/Slothpala/PIMG/tree/1.2.6) (2026-03-15)

- Replaced deprecated `SendChatMessage` usage with `C_ChatInfo.SendChatMessage` and kept a fallback for older clients

## [1.2.5](https://github.com/Slothpala/PIMG/tree/1.2.5) (2026-03-15)

- Deferred macro updates and instance reminder checks until combat ends
- Added a combat-safe queue so raid and dungeon logic only executes outside of combat lockdown
- Split the addon into smaller Lua files for data, macro logic, reminder UI, config UI, minimap, and core bootstrapping

## [1.2.4](https://github.com/Slothpala/PIMG/tree/1.2.4) (2026-03-15)

- Limited combat potion fallback lines in the Voidform macro to the prioritized quality only
- Keeps the Voidform variant within the WoW macro length limit more reliably

## [1.2.3](https://github.com/Slothpala/PIMG/tree/1.2.3) (2026-03-15)

- Added configurable combat potion support with potion selection and preferred quality ordering
- Macro generation now inserts `/use item:<itemid>` lines for the selected potion before the Power Infusion lines

## [1.2.2](https://github.com/Slothpala/PIMG/tree/1.2.2) (2026-03-15)

- Updated the AbstractFramework UI theme to a Void-inspired purple accent palette
- Recolored the config window title and action buttons to match the Void theme

## [1.2.1](https://github.com/Slothpala/PIMG/tree/1.2.1) (2026-03-15)

- Added an optional target announcement that is off by default
- Announces the selected Power Infusion target to raid or party chat depending on the current instance type

## [1.2.0](https://github.com/Slothpala/PIMG/tree/1.2.0) (2026-03-15)

- Rebuilt the reminder widget and config window on top of AbstractFramework
- Replaced the custom font picker with an AbstractFramework dropdown that scrolls automatically
- Added AbstractFramework as a required dependency for the addon

## [1.1.0](https://github.com/Slothpala/PIMG/tree/1.1.0) (2026-03-15)

- Added a raid and dungeon reminder frame with configurable duration, strata, font size and font selection
- Added a movable minimap button that runs `/pim` on left-click and opens the config menu on right-click
- Added standalone and Voidform macro variants while keeping `/pim add` support
- Migrated saved variables from the legacy string format to a settings table

## [1.0.3](https://github.com/Slothpala/PIMG/tree/1.0.3) (2024-08-29)
[Full Changelog](https://github.com/Slothpala/PIMG/compare/1.0.2...1.0.3) 

- Updated to 110002  
- Moved from the now removed API call GetSpellInfo to C\_Spell.GetSpellInfo  

