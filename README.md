# 📦 PUG = Physics Un-Griefer
> A modular solution to prop griefing and physics exploits!

<div align="center">
<img src="https://github.com/NanoAi/gm_pug/blob/dev/assets/gm_pug.png?raw=true" alt="gm_pug logo" width="256px"/>
<hr/><br/>
<img src="https://i.imgur.com/gvcznDV.png" alt="Menu Preview"/>
<br/><br/>
</div>

---

## 🛠️ FEATURES
### # Ghosting 👻👻
 - Limit object interactions to reduce abuse.
 - Most notably objects appear faded and will phase through players.
 - Supports fading doors!
### # Ghost Buster 👻🚫
 - Ghosted objects will try to unghost automatically.
 - Configure how fast you'd like objects to try to unghost.
### # Lag Detection 🤖⏳
 - Attempts to sample your servers tickrate and trigger cleanups during abnormal rates with adjustable tolerance.
### # Limit Physics Collisions ⚡🚫
 - Tracks object collisions and freezes them if they collide too much.
 - Effectively a pure Lua implementation of `MaxCollisionsPerObjectPerTimestep`.
### # Physgun Control ⚡🔦
 - [OPTION] Stop players from unfreezing objects.
 - [OPTION] Stop players from throwing objects.
 - [OPTION] Stop players from unfreezing everything on their screen (using the physgun reload feature).
 - [OPTION] Stop players from picking up vehicles.
### # Physics 💡⚡
 - Multiple options to modify how physics behave on your server including but not limited to preventing prop damage.
 - 
### # Stacks 📚
 - Attempts to remove large stacks of objects to reduce server timeouts raised due to having too many collisions at once.
### # Tools ⚙️
 - Allows you to control how tools are used on your server including but not limited to blocking tool gun spam, and preventing usage on world.
 - [OPTION] Adds compatibility to fading doors to `Ghosting` and `Stacks` via the `PUG.FadingDoorToggle` hook.