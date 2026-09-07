# archipelago-city-gen
Procedural city generator tech demo, that generates branching road networks and fills resulting sectors with simplistic buildings.

Currently allows for 3 singular city generation types: 

    Square - a city formed from many cells placed in a radius around central point
    Ring - a city formed from layers of rings expanding outward from the central circle 
    Circle - a city formed from splitting a singular initial circle. 

These generation types are used in the unique generation type: Archipelago. Archipelago will generate islands using singular generation types and then connect them via boat networks.

For additional life, simple cars drive along the roads with no set destination, roaming the city

Includes customizable generation options in the menu to experiment with different layouts.

Controls:

Arrows - Movement

Shift - Fly Down

Space - Fly Up

Q /E - Rotate left / right 

ESC - Open / Close menu


Currently known issues:

1. Sidewalk intersections can overlap heavily, creating visual clutter in some areas
2. Performance drops a bit when many roads or large parks are loaded in.
