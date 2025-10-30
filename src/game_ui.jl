#=
Creates the UI for the game

Instead of making a webapp or even using Pyside6 - I plan to do it in Julia (what can go wrong :|)

Note: I am not really proficient in making a webapp - I have made simple backends with Flask and frontends using GPTs (as
I don't really understand JS well enough to make it myself), and as for Qt - I have never used it, and the only time I made a 
GUI was in my first year undergrad (in Java - its standard library or somthing, I don't exactly remember), 
so IDK about the results

It seems that QML.jl uses Julia for the brains for the UI and has a QML (Qt Markup Language?) for the UI,
so kinda like webapp where the backend is say Flask and the UI is CSS, HTML and JS.

It will be really slow to learn Qt from scratch so will be using AI to make code for me and learn the individual stuff from there
and use it to make my UI. Thus not entirely my work - but whatever. 

The code might be over commented as I am using it to learn too.
=#

using QML  # for ui
using HTTP  # to interact with the API
using JSON3  # to interpret JSON
using Observables  # no idea why (for now)

