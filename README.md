# SkyHUD

An immersive fighter HUD for first person flying.

(Includes the atlas for the Settlers myDU server.)

## Features
### Basics
* Engines shut off when landing gear are deployed
* Vertical boosters shut off when close to the ground
* Auto sets hover height to max when retracting landing gear and sets it to zero when they are deployed
### Hud
* Stall orb: tells you how large your angle of attack is.
* Crosshair: point this where you want to go.
* Speed ladder: *highway to the... **dangerzone***
* Altitude ladder: *up, up and awaaaay!*
* Destiantion tape: this will point left/right depending on your orientation to your destination along with a distance in km.
* Space Capture Box: This box will activate in space and will highlight your destination in 3D space.
### Left MFD
* Speed warning: uses your sustenation speed to tell you when you are going to slow.
* Altitude warning: for when you are under 500m altitude.
* Destination info: the name, lat/lon and altitude of your destination.
* Brake info: your brake time and brake distance.
### Right MFD
* Fuel warnings: for bingo space/atmo fuel.
* Fuel gauges: displaying time remaining, amount remaining, and usage over time for currently active fuel.
* Time of Arrical: An estimated countdown to when you will arrive at your destination.
### Navigation
* Paste destination coords into lua chat to set your destination immediately.
* Prefix the destination with a single worded name to save that destination to the databank.
* Type the name of a destination to recall it.
* Type "list" to recall all known destinations.
### Autopilot
There are two autopilot features, they only work in space and you must have a destination set for them to work.
* Auto Brake - Alt+1 - crosshair will turn red when activated, will stop your ship so you arrive 10km from either your destination or the atmopshere of your destination's planet.
* Auto Align - Alt+2 - the destination 3D marker will turn red when activated, your ship will automatically turn to point directly at your destination by overriding pitch and yaw controls.
A third autopilot feature has been added, this one will keep your pitch level when near celestial objects.
* Auto Stable - Alt+3 - the ship will take control of pitch and aim to keep the nose pointed perpendicular to the ground.

## Compiling
* Run du-lua build to output the .conf file for use in control units, in-game.

## Setup
* Bingo fuel and sustenation speed need to be set in the lua paramters before takeoff.
* Your ship must contain a:
  * Gyroscope
  * Databank
  * Telemeter
  * (at least one) Landing Gear
* (Optional):
  * Manual Switch - this must be linked manually and be named "switch" in the lua editor.
    * Will automatically toggle on when piloting and off when exiting the ship.

#### Super thanks to
* [DU-LuaC](https://github.com/wolfe-labs/DU-LuaC)'s interactive CLI
and
* EasternGamer's [AR-Library](https://github.com/EasternGamer/AR-Library)