"""
Provides a GUI for the game

Note: Am not going into any trouble now, will just use Pygame to make the stuff
"""

import time
import threading
import requests
import pygame


# config
API_BASE_URL = "http://127.0.0.1:8000"
SCREEN_WIDTH = 650
SCREEN_HEIGHT = 700
POLL_INTERVAL_SEC = 0.1
COLOUR_MAP = {
    "bg": "#121212",  # default background colour
    "border": "#323233",  # border colours when unfilled
    "filled_boarder": "#484a4a",  # border colour when filled
    "default_key": "#828483",  # default keyboard key value
    "hints": {
        'y': "#b49f3f",  # yellow result colour
        'g': "#528d4d",  # green result colour
        'b': "#3a3a3c",   # grey result colour  (also for invalid keys in the keyboard)
    }
}


class WordleClient:
    def __init__(self, screen):
        self.screen = screen
        self.clock = pygame.time.Clock()

        self.title_font = pygame.font.SysFont("Arial", 30, bold=True)
        self.notify_font = pygame.font.SysFont("Arial", 15)  # notif

        self.game_id = None
        self.guesses = []  # List of Typles (guess, result)
        self.current_guess = ""
        self.current_row = 0  # as unlike Julia, indexes start from 0
        self.current_col = 0
        self.notification = ""
        self.is_game_over = False
        self.is_game_won = False

        self.session = requests.Session()  # to maintan conn pools

        # TODO - add threading to access game state from the background
