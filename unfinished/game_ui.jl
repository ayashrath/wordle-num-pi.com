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
using Observables  # to make it reactive


const API_BASE_URL = "http://127.0.0.1:8000"

const COLOUR_MAP = Dict(
    "bg" => "#121212",  # default background colour
    "border" => "#323233",  #  border colours when unfilled
    "filled"  => "#484a4a",  # border colour when filled
    "b" => "#3a3a3c",   # grey result colour  (also for invalid keys in the keyboard)
    "y" => "#b49f3f",  # yellow result colour
    "g" => "#528d4d",  # green result colour
    "default_key" => "#828483"  # default keyboard key value
)  # used the colours from NYTimes Wordle game


# UI State struct
mutable struct Client
    # an observable is a data type that contants a value and when you change it, its subscribers are notified
    game_id::Observable{Union{String, Nothing}}  # nothing as an initial game state - as having any value is not ideal for init
    notif::Observable{String}

    current_row::Int  # guess no
    current_col::Int  # guess char entry no
    current_guess::String
    key_colours::Dict{String, String}

    # data model for QML
    # ListModel is a collection of ListElements, so kind of like a 2d array
    grid_model::QML.JuliaItemModel
    key_model::QML.JuliaItemModel

    # inner constructor
    function Client()
        # init the 6x5 model  - TODO, make it able to accomodate more than 6 rows
        grid_data = [
            Dict("letter" => "", "tile_colour" => COLOUR_MAP["border"])
            for iter in 1:30
        ]

        # init keyboard model
        key_rows = [
            split("q w e r t y u i o p"),
            split("a s d f g h j k l"),
            split("Enter z x c v b n m Backspace")
        ]  # TODO - just make it in list form, no need for splits

        key_data = []
        for row in key_rows, key in row
            push!(key_data, Dict(
                "key" => key,
                "key_colour" => COLOUR_MAP["default_key"],
                "is_large" => length(key) > 1  # for enter and backspace
            ))
        end

        new(
            Observable{Union{String,Nothing}}(nothing),  # game_id
            Observable{String}("Loading..."),  # notif
            1,  # row
            1,  # col
            "",  # guess
            Dict{String, String}(),  # key colours map
            QML.JuliaItemModel(grid_data),
            QML.JuliaItemModel(key_data),
        )
    end
end


# Warn

if Threads.nthreads() == 1
    @warn "Julia running with 1 thread. Start Julia with JULIA_NUM_THREADS>1 so background requests run while QML.exec() is active."
end


# Functions that QML can call

function start_newgame(client::Client)  # TODO - make it such that the number of tries is provided and the file to be used too in post
    client.notif[] = "New game starting..."  # Update struct field directly
    Threads.@spawn begin try  # creates a async task and also try as need to make sure to handle case where the server is not working properly
        r = HTTP.post("$API_BASE_URL/new")  # sends response
        data = JSON3.read(r.body)  # gets the response body
        println(data)
        flush(STDOUT)

        QML.run_on_gui_thread() do  # to update UI, should be done with this method
            # Reset grid model
            for i in 1:30
                client.grid_model[i] = Dict("letter" => "", "tile_colour" => COLOUR_MAP["border"])
            end

            # Reset key model
            for i in 1:length(client.key_model)
                key_data = client.key_model[i]
                key_data["key_colour"] = COLOUR_MAP["default_key"]
                client.key_model[i] = key_data # Set the model data
            end

            client.current_row = 1
            client.current_col = 1
            client.current_guess = ""
            empty!(client.key_colours)

            # robustly extract game_id from JSON (string or symbol key)
            if haskey(data, "game_id")
                client.game_id[] = string(data["game_id"])
            elseif haskey(data, :game_id)
                client.game_id[] = string(data[:game_id])
            else
                client.game_id[] = nothing
            end

            client.notif[] = "Game started!"
        end
    catch err
        QML.run_on_gui_thread() do
            client.notif[] = "Error: Can't connect to API!"
        end
    end
end
end


function handle_key(client::Client, key::String)
    if isnothing(client.game_id[]) || client.current_row > 6  # game either started or ended ()
        return
    end

    key = lowercase(key)

    if key == "enter"
        make_guess(client)
    elseif key == "backspace"
        if client.current_col > 1
            client.current_col -= 1
            client.current_guess = chop(client.current_guess)  # removes 1 char from end

            # update grid model
            ind = (client.current_row - 1) * 5 + client.current_col  # find index in the 1D array (flattened array)
            # Use 1-based indexing for ListModel
            client.grid_model[ind] = Dict("letter" => "", "tile_colour" => COLOUR_MAP["border"])
        end
    elseif client.current_col <= 5  && length(key) == 1 && occursin(r"[a-z]", key)
        client.current_guess *= key

        # update the grid model
        ind = (client.current_row - 1) * 5 + client.current_col
        # Use 1-based indexing for ListModel
        client.grid_model[ind] = Dict("letter" => uppercase(key), "tile_colour" => COLOUR_MAP["filled"])  # upper in grid!
        client.current_col += 1
    end
end

function make_guess(client::Client)  # TODO - handle error key json
    # Added a check for guess length before sending
    if length(client.current_guess) != 5
        client.notif[] = "Not enough letters"
        return
    end

    # Copy the guess, as it will be cleared
    current_guess_copy = client.current_guess

    Threads.@spawn begin try
        header = ["Content-Type" => "application/json"]  # need to include it
        body = JSON3.write(Dict("guess" => current_guess_copy))
        
        # --- API Endpoint Fix ---
        # Your API file defines "/game/{game_id}/guess"
        # Your code was calling "/game/{game_id}/make_guess"
        r = HTTP.post("$API_BASE_URL/game/$(client.game_id[])/guess", header, body)
        data = JSON3.read(r.body)

        # non-error response
        QML.run_on_gui_thread() do
            # Use 1-based indexing for Julia
            _temp, result = data.board[end] 
            update_from_result(client, current_guess_copy, result)

            client.current_row += 1  # go to a new row
            client.current_col = 1
            client.current_guess = ""

            # Check win and loss conditions
            # Your API file returns "win" and "game_over"
            if data.win
                client.notif[] = "You won!"
            elseif data.game_over # Changed from data.lost
                client.notif[] = "Game over!"
            end
        end

    catch err
        QML.run_on_gui_thread() do
            if err isa HTTP.Exceptions.StatusError
                try
                    # parse error detail from response (FastAPI uses 'detail')
                    err_body = JSON3.read(err.response.body)
                    if haskey(err_body, "error") # Changed from "error"
                        client.notif[] = string(err_body["error"])
                        return
                    end
                catch err_1
                    # if the response is not JSON - should not matter
                end
            end
            client.notif[] = "API Error"  # some other kind of error
        end
    end
end
end

function update_from_result(client::Client, guess::String, result::Vector)
    start_ind = (client.current_row - 1) * 5  # find place in flattened array
    guess_chars = collect(lowercase(guess))

    for (iter, letter_str) in enumerate(guess_chars)
        colour_code = string(result[iter])

        # update the tile
        grid_ind = start_ind + iter
        client.grid_model[grid_ind] = Dict(
            "letter" => uppercase(letter_str),
            "tile_colour" => COLOUR_MAP[colour_code]
        )

        # update the keyboard
        # Use 1-based indexing for ListModel
        key_ind = findfirst(k -> k["key"] == letter_str, client.key_model)
        if !isnothing(key_ind)
            key_data = client.key_model[key_ind]
            # Use "default_key" to match your COLOUR_MAP
            current_key_colour = get(client.key_colours, letter_str, "default_key")

            # determine new colour but never downgrade: default -> b -> y -> g
            new_key_colour = current_key_colour
            if colour_code == "g"
                new_key_colour = "g"
            elseif colour_code == "y"
                new_key_colour = (current_key_colour == "g") ? "g" : "y"
            elseif colour_code == "b"
                new_key_colour = (current_key_colour in ("g","y")) ? current_key_colour : "b"
            end

            client.key_colours[letter_str] = new_key_colour # Use letter_str

            key_data["key_colour"] = COLOUR_MAP[new_key_colour]
            client.key_model[key_ind] = key_data
        end
    end
end


# The main execution part

client = Client()
qml_file = joinpath(@__DIR__, "game_ui.qml")

# --- FIX: Define wrapper functions for @qmlfunction ---
# These functions will be visible to QML as `Julia.jl_handle_key` etc.
# They capture the `client` object from the global scope.
jl_handle_key(key) = handle_key(client, convert(String, key))
jl_start_newgame() = start_newgame(client)

# --- FIX: Register the functions with QML ---
@qmlfunction jl_handle_key jl_start_newgame

# --- FIX: Use loadqml and only pass the client object ---
# The functions are now handled by the @qmlfunction macro
loadqml(qml_file, client = client)
exec()  # runs the QML Application
