== Tactical Map Readme ==
Author: MegaJohnny
Egosoft Forums Thread: https://forum.egosoft.com/viewtopic.php?t=396379

Requires the Sidebar Extender.

This mod adds a new menu to the game which replicates many of the behaviours of the vanilla map, but adds some new ones besides. Most importantly, you can select your ships on this map and right-click on the holomap, and a command will be issued based on the context. For example, clicking on a point in space issues "Fly to Position", clicking on an enemy issues "Attack Object", and so on. For less "obvious" commands a grid of buttons on the bottom right is used to make them available.

This mod does not come with any commands of its own, but instead has the capability to load commands in from other mods (see readme_api.txt). Keeping the two separate makes it easier to accommodate full overhauls of the player-owned ship AI where the normal command signals may be interpreted differently or be ignored entirely. Unless you're using one of these, you'll probably want to download the Vanilla Commands addon to make full use of this mod.

My ultimate goal is to replace the vanilla map menu in every use-case, but there are still some holes to be plugged. Known missing things are:
- Jumpdrive does not respect kickstarter item
- No support for different modes of operation

However, enough is working that I've decided to have it replace the vanilla map in the normal mode. Dot and comma open the tactical map now, as do the buttons on property/object menus. However the vanilla map will open when you are being asked to select a zone, player object, etc.


== Usage ==

Most things are similar to the vanilla map, but just above the command buttons on the bottom right is a row which shows you the current "command selection". The ship that will receive commands is different from the one that is highlighted on the right-hand list, because not every ship you select is able to receive a command. In the usual AI, only ships which are in your squad or have no commander can become the command selection. These are marked on the right-hand list with a yellow ">" before the name. Selecting any other player-owned ship will have the map scan the command tree that ship is in, and set the command selection to the ship at the top, if it's eligible. Once set, a ship remains the command selection until you set a new one or it becomes ineligible (probably by being blown up).

When you have a command selection showing on the right, right-clicking anywhere on the map will try to issue an appropriate command to the command selection based on the context. More specifically, it will look through all the available commands and try to find any applicable ones. The "throttle set to full forward" sound will play, and the command with the highest priority will be issued. If there's no applicable right-click commands, a "not possible" sound will play instead.

The bottom-right command buttons are used for commands that don't fit into the usual right-click. Some commands don't require a target (such as "Hold Position") and will be issued as soon as you press the button. Others, such as "Patrol", do need a target/destination. In this case, when you press the button, it will be highlighted until you give a target for it by right-clicking. While a grid command is highlighted, the normal right-click behaviour is suppressed. You can click the same button again to cancel it, instead of giving a target, if you like.

The above describes the menu's single-select mode. As of 1.2 an optional multi-select mode can be used to have multiple ships in the command-selection and issue commands to all of them at once. To toggle between single-select and multi-select, click the small button with a fleet icon just above the ABXY buttons on the holomap (or press 5 on your keyboard). In multi-select mode the command selection is displayed instead as breakdown of the size classes of the selected ships (S, M, L, XL). Commandable ships on the right-hand list have checkboxes instead of icons, and you select/deselect them using these checkboxes. You can also use the "X" button on the command-selection display to clear the command-selection.

Besides that, right-click and grid orders generally work as in single-select mode. More specifically, right-click orders are determined individually for each selected ship (which might be two different things depending on what commands are installed), and grid buttons are only available if /all/ selected ships are valid. Additionally, some commands simply don't make sense to be issued to multiple ships - for example if they open another menu. In this case the commands just won't be available at all in multi-select mode.


== Known Issues ==

Going into an object's details from sector view and then back to the map makes it very zoomed in.

I have a feeling something that handles the hotkeys is giving this output in the debug log:

[General] 175107.07 ======================================
[=ERROR=] 175107.07 [InputMapper::AddContextRequest] There is already a ContextR
equest for Context INPUT_CONTEXT_COMM_ACTION, Requester INPUT_CONTEXT_REQUESTER_
PLAYERCONTROLLER, priority 10
[General] 175107.07 ======================================
[General] 175107.07 ======================================
[=ERROR=] 175107.07 [InputMapper::AddContextRequest] There is already a ContextR
equest for Context INPUT_CONTEXT_INFO_ACTION, Requester INPUT_CONTEXT_REQUESTER_
PLAYERCONTROLLER, priority 10
[General] 175107.07 ======================================

I could be wrong, and it doesn't seem to affect the behaviour of the map either way. But it would be nice to get rid of some unnecessary debug log spam.

== Changes ==
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