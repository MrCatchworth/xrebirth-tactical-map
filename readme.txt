== Tactical Map Readme ==
Author: MegaJohnny
Egosoft Forums Thread: https://forum.egosoft.com/viewtopic.php?t=396379

This mod replaces the map menu with a new one. There are many new features to command your ships easily without leaving the map menu, and many UI additions to make it prettier and more informative.

This mod doesn't have any commands built-in, but instead it can load commands in using a system similar to Sidebar Extender. Make sure you download the Vanilla Commands companion as well, which adds a lot of vanilla commands to Tactical Map.

Tactical Map includes all the important features of the vanilla map, and many of the minor ones, but a couple of small things might still remain - if you see anything missing, get in touch at the forum thread above!


== Usage ==

Tactical Map behaves like the vanilla map for general usage. Its defining addition is its command system, which lets you select ships on the map and issue commands to them with a simple mouse-based interface. We'll go through the different aspects of that.

= Selecting Ships =

Tactical Map keeps track of which ship(s) you have selected for giving commands (the "command selection"), which is displayed underneath the object list, on the right. Any ship which can receive commands is marked with a yellow ">" by its name, and when you click on it, it becomes the command selection until it's destroyed or you select something else. The command selection is sticky and stays when you zoom in or out.

You can go into a multi-select mode to easily broadcast orders to multiple ships at once. To toggle it, click the button on the bottom right of the holomap, or press 5. In multi-select mode each commandable ship has a checkbox you can use to add or remove it from the command selection. You can use the X button on the command selection, or press 6, to clear the selection in multi-select mode. Be aware that some commands can't be given when you have multiple ships selected.

= Right Click Commands =

When you have a command selection, you can right click on the holomap to give a command based on what you clicked and what your command selection is. In multi-select mode it's possible some ships are valid for this command and some aren't. This is for quick access to simple commands like "fly to this point", "attack this enemy", "stop current task" and so on.

= Grid Commands =

Extra commands can be found in the button grid underneath the object list. There are three different types of grid command:

- Commands which don't require a target, and are given as soon as you press the button.
- Commands which do require a target - the button becomes highlighted when you click on it, and then your next right click is used to provide a target for the command.
- Commands which go to a different menu.

Grid commands are greyed out when they can't be used currently.

= Middle Click =

You can also middle click on the holomap to give a "fly to position" command. This is different from right click in that it will only ever select a position, never an object. This is handy if you want to send a ship very close to a station.

Additionally, by dragging the mouse up and down when you middle click, you can set a vertical offset which the command selection will fly to. This can't be displayed on the map due to a technical limitation, but you can see the offset in metres on the bottom left while dragging.

== Known Issues ==

Occasionally you might see this error when the menu refreshes - still trying to work out the problem. It shouldn't affect the menu's behaviour much.

[General] 270105.23 ======================================
[=ERROR=] 270105.23 Widget system error. Failed to set initial selected column. Selected-column will not be changed. Error: specified column contains a non-selectable element and hence cannot be selected
[General] 270105.23 ======================================

== Changes ==
2018-10-15: 1.5
Major Changes:
    - Switch to a pure-Lua way of replacing the vanilla map, removing the save-game dependency
    - Add support for selection modes, and replace the vanilla map for selection modes
        - In a selection mode, invalid choices on the object list are grey
        - Command functionality is completely disabled when in a selection mode
    - Add middle click as a way to give orders
        - Middle click only works in zone or sector mode, and selects a position for giving a command, ignoring any objects under the mouse
        - Handy for telling ships to go somewhere when a station or ship is in the way
        - Keep the middle mouse button held down and drag the mouse up and down to specify a vertical offset from the ecliptic
        - The vertical offset, when middle mouse dragging, is shown over the holomap
    - Station sequences and modules are in from the vanilla map
        - Modules are ordered by their module type (production, storage, etc)
        - Each sequence has its letter code (A, B, C, ...) on display as well as its current stage
        - Module types have their own little icon - any replacements would be gratefully accepted!

Minor Changes:
    - Display the player's current ship (Skunk or docked capital) in a different colour
    - Gates are displayed under their zone/sector in the appropriate view
    - Implement the vanilla Shift+A, F1 and F3 hotkeys

2018-03-23: 1.3
    - Larger font is used for small HUD detailmonitor mode, fixes debug output produced by this (only tested on 1920x1080)
    - In multi-select mode, the "X" button for clearing selection now has hotkey 6/RB
    
2017-10-09: 1.2
    - New multi-select mode
    - Ships selected for commands now have very obvious yellow arrows on the right-hand list, so they pop out a bit more
    - In the sector view, only commandable ships are displayed now
    - Reveal percentage display as in vanilla map, except for ships
    - Shield and hull condition alerts on player-owned ships
        - If hull is below 70% a yellow alert is shown, which turns red if the hull is below 40%
        - If shield is below half then a cyan alert is shown
    - Adjusted command accept text on bottom left, added colouration
    - Removed Sidebar Extender file (it's just renamed, so you can get it back if you like)
    - Jumpgates and jump beacons now shown in light grey, more in keeping with map colour
    - Fixed bug causing map -> object menu -> plot course to have no effect (and produce debug log error)
    - Fixed bug where zooming out wouldn't select the space you just zoomed out of
    - Fixed bug where trying to return from the map to a previous section would close out instead

2017-09-28: 1.1
    - Now replaces vanilla map by default (the opposite applies - you can rename/remove MainMenu.xml to revert this)
    - Now mimics the history behaviour of the vanilla map
    - Now includes economy stats button as in vanilla map
    - Now lists jump beacons as in vanilla map
    - Rudimentary (and untested!) jumpdrive support, but not for jumpdrive kickstarter - feedback appreciated
    - Command selection displays above grid buttons (previously was directly above the right-hand list)
    - Clicking a ship in sector view highlights the zone it's in (previously would clear map highlight)
    - Stations are now valid right-click targets (previously would just select a position if you right-clicked a station)
    - Changes to API: Issuable orders can have a priority number now, and the filter function can return a number to override the priority instead of a boolean. The map accepts more than one order being applicable at once, and takes the one with the highest priority.
    - Removed unnecessary debug.log output from MainMenu.xml
    
2017-09-16: Initial release