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
### Left MFD
* Speed warning: uses your sustenation speed to tell you when you are going to slow.
* Altitude warning: for when you are under 500m altitude.
* Destination info: the name, lat/lon and altitude of your destination.
* Brake info: your brake time and brake distance.
### Right MFD
* Fuel warnings: for bingo space/atmo fuel.
* Fuel gauges: displaying time remaining, amount remaining, and usage over time for space/atmo.
### Navigation
* Paste destination coords into lua chat to set your destination immediately.
* Prefix the destination with a single worded name to save that destination to the databank.
* Type the name of a destination to recall it.
* Type "list" to recall all known destinations.

## Compiling
* Run du-lua build to output the .conf file for use in control units, in-game.

## Setup
* Bingo fuel and sustenation speed need to be set in the lua paramters before takeoff.
* Your ship must contain a:
  * Gyroscope
  * Databank
  * Telemeter

Super thanks to
* [DU-LuaC](https://github.com/wolfe-labs/DU-LuaC)'s interactive CLI
and
* EasternGamer's [AR-Library](https://github.com/EasternGamer/AR-Library)