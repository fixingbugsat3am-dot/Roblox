# Roblox

A Roblox LocalScript for a dark, mobile-friendly macOS-style player tools UI.

## Script

- `DarkMacOSPlayerTools.client.lua` should be placed in `StarterPlayerScripts` in your own Roblox experience.
- The UI uses the requested custom font:

```lua
TextLabel.FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium)
```

## Features

- Animated loading screen with a searching/progress bar.
- Dark macOS-style draggable window with mobile-friendly scaling.
- Fly toggle with flight speed slider capped at `1000`.
- Noclip button that toggles noclip on and off.
- Player highlight toggle with name tags for every other player.
- Speed modifier toggle with WalkSpeed slider capped at `250`.
- Jump modifier toggle with JumpPower/JumpHeight slider capped at `250`.
