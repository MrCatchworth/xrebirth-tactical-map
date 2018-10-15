== Tactical Map API ==
The tactical map offers a standard way for other mods to extend the set of supported orders. Integration of the map to mods that add new commands for the AI is (hopefully) easy and not prone to conflicts.
The map looks at each extension’s folder and tries to load mej_tacmap_orders.txt as a Lua script. Your script should return a table with the following items:

- issuableOrders: A list of orders that are issued to ships by contextual right-click.
- gridOrders: A list of orders that are issued via the grid at the bottom right of the menu.

The overall return value is a table so that other optional things can be added to the API later as desired. You can, of course, put other side-effects in this file as well before you return the table. But be careful about interfering with the map’s normal operation.


== Issuable Orders ==
When a right-click on the map happens while a command selection exists, the map will iterate through each issuable order and ask it whether it is applicable in this situation. It returns a priority value for itself (as described below) and out of all the applicable orders, the one with the highest priority is issued. If there's a tie, it's arbitrary which of the tying orders is issued.

Each order is a table that has the following items:

- name: String describing the order. Will be used in the map UI in some cases, but doesn’t have to be unique.
- priority: Number representing the order's priority. Optional; defaults to 0.
- multicast: Boolean for whether or not the order can ever be applicable in multi-select mode. Optional; defaults to false. If the map is in multi-select mode and this is false, it will not be considered applicable, even if the filter function would have returned true.
- filter: Function that takes an order object (described below) as its only argument. Based on whether the order is applicable to the supplied order object, you should return one of these values:
    - A number: The order is applicable, and the returned number should be used as the priority instead of the above 'priority' member.
    - Boolean true: The order is applicable, and the above 'priority' member should be used as the priority.
    - Boolean false: The order is not applicable.
- issue: Function that takes an order object as its only argument. Put the code for actually issuing the order here. (signal objects, open another menu, etc.) Return value is currently ignored.

In other words, the order gives a priority, as one of the following:
- The return value of 'filter', if supplied.
- The 'priority' member of the order, if supplied.
- Zero, if neither of the above.

Therefore consider zero as the baseline for priority, with a positive number for high priority and negative for low priority.


== Grid Orders ==
Each order is a table that has the following items:

- buttonText: String denoting the text on the button.
- multicast: Same as for issuable orders.
- buttonFilter: Function that takes an order object as its only argument. Returns true if the button should be enabled, and false if it should be greyed out. The target will be “none”.
- requiresTarget: Boolean that denotes whether or not the order needs a target in order to be issued. For example, “Hold Position” doesn’t need a target, but for “Patrol” the zone must be specified. If this is false, the order is issued as soon as the button is clicked.
- filter: Only required if requiresTarget is true. In this case the next right-click on the map gives the target to the order, and this function is used to say whether or not the right-click is valid. Takes an order object as its only argument, and should return a boolean as appropriate. Priority doesn't matter here, and so numbers are not accepted.
- issue: Identical to its equivalent for an issuable order. The target will be “none” if requiresTarget is false.


== Order Objects ==
In the hope of cutting down on the length of argument lists, and improving readability, information is passed to orders in a single table rather than as separate arguments. The table has the following members:

- subject: A component (of the Lua-friendly datatype) referring to the player-owned ship that will be carrying out the order. It will always satisfy the following conditions:
    - Has a pilot/captain
    - Is operational
    - Does not have a build anchor
    - Is either a direct subordinate of the player ship, or is not a subordinate to anybody (these being the usual requirements for giving orders to ships in vanilla)
    
- targetType: A string telling you what sort of target is being given for the order. It will either be “object”, “position” or “none” as appropriate (see below). Be sure to check the value of this before working with target.
- target: The target being given for the order. Has a different datatype depending on the target type:
    - Object: an operational component of the Lua-friendly datatype.
    - Position: a table with the keys x, y and z representing a point clicked on the map. Be sure to examine spaceType to determine how to handle this value.
    - None: the number zero.

- space: The space whose contents the map is currently viewing. For example if Fervid Corona and Gushing Spring are in the right-hand list, the space is Glaring Truth. This is in the FFI-friendly datatype unlike the previous two components.
- spaceType: String denoting the type of space that space is. Either “zone”, “sector”, “cluster” or “galaxy” as appropriate.
- menu: The menu table containing all other properties of the map. Useful if I’ve forgotten to add anything you really need, but it’s strongly recommended to use the values provided in the order object whenever possible.

For more information on the slightly different data types used in X Rebirth’s Lua environment, see https://www.egosoft.com:8444/confluence/display/XRWIKI/Getting+started+guide.


== In Practice ==
Hopefully this is all pretty easy to use. The Vanilla Commands addon offers several working examples. In vanilla behaviour, all ships receive commands by receiving signals, which they handle as an event. The Lua functions in the game include one to signal objects, and this is good enough for many cases. For cases where Lua alone cannot send the properly-formatted signal to a ship, the Skunk (or IIRC, in the case of UniTrader's Advanced Renaming, the galaxy) makes a convenient omnipresent object to send signals, as a way to asynchronously send data from Lua to MD/AI.

Some vanilla (or mod-added) commands will want to open another menu to set other parameters; refuel budget, what wares to transfer, etc. If you want to use e.g. Helper.closeMenuForSection in your command, be sure to call <order object>.menu.cleanup straight afterwards, so the tactical map can close as cleanly as possible.