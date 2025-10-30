## Wordle

This is a supporting code repo for the wordle article at num-pi.com

## Data Sources

The word lists are sourced from

1. *english-words* repo ([link](https://github.com/dwyl/english-words))
2. *wordle-allowed-guesses.txt* and *wordle-answers-alphabetical.txt* gist by cfreshman ([link](https://gist.github.com/cfreshman/a03ef2cba789d8cf00c08f767e0fad7b))

## Steps to use it

1. Get the data - `python3 fetch_data.py`
2. Start the API Server - `cd src && uvicorn api:app`
3. Change configs based, which is found in - `config.json`
4. Run Game UI - `python3 game_ui.py`