"""
Creates the API that the solver and the UI will interface with

Note: I have never used FastAPI before, just googled it and it is a better option for these kind of purposes.
"""

from fastapi import FastAPI
from game import Wordle
from pydantic import BaseModel  # to data validation
import uuid  # for game id


app = FastAPI()

# stores all the active games in memory - in deployment it should be stored in a db, but for my application - not needed
games = {}  # TODO - add a way to make it store the games in dbs and clear the dict - useful when recording for solvers


class GuessRequest(BaseModel):
    guess: str


@app.post("/new")
def new_game():
    """
    Starts a new game and returns a game ID
    """
    game_id = str(uuid.uuid4())  # gens a random id
    games[game_id] = Wordle()
    return {
        "game_id": game_id,
        "state": games[game_id].get_state()
    }


@app.get("/game/{game_id}")
def get_game_state(game_id: str):
    """
    Get game state based on the game_id
    """
    if game_id not in games:
        return {"error": "Game not found!"}
    return games[game_id].get_state()


@app.post("/game/{game_id}/make_guess")
def make_guess(game_id: str, guess_request: GuessRequest):
    """
    Make a guess to a game and return the state
    """
    if game_id not in games:
        return {"error": "Game not found!"}

    game = games[game_id]
    return game.make_guess(guess_request.guess)  # makes the guess and returns it


@app.post("/all_games")
def all_games():
    """
    Starts a new game and returns a game ID
    """
    return {"all_games": [game for game in games]}
