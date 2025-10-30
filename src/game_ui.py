"""
Provides a GUI for the game

Note: Am not going into any trouble now, will just use Pygame to make the stuff

Does not have the keyboard stuff as not needed
"""

import sys
import time
import threading
import requests
import pygame


# config
API_BASE_URL = "http://127.0.0.1:8000"
SCREEN_WIDTH = 500
SCREEN_HEIGHT = 600
POLL_INTERVAL_SEC = 0.5
COLOUR_MAP = {
    "bg": "#121212",  # default background colour
    "border": "#323233",  # border colours when unfilled
    "filled_boarder": "#484a4a",  # border colour when filled
    "default_key": "#828483",  # default keyboard key value
    "hints": {
        'y': "#b49f3f",  # yellow result colour
        'g': "#528d4d",  # green result colour
        'b': "#3a3a3c",   # grey result colour  (also for invalid keys in the keyboard)
    },
    "white": "#FFFFFF"  # char's white
}


class WordleClient:
    def __init__(self, screen):
        self.screen = screen
        self.clock = pygame.time.Clock()

        self.title_font = pygame.font.SysFont("Arial", 30, bold=True)
        self.notify_font = pygame.font.SysFont("Arial", 15)  # notif
        self.tile_font = pygame.font.SysFont("Arial", 36, bold=True)

        self.game_id = None
        self.guesses = []  # List of Typles (guess, result)
        self.current_guess = ""
        self.current_row = 0  # as unlike Julia, indexes start from 0
        self.notification = ""
        self.is_game_over = False
        self.is_game_won = False

        self.session = requests.Session()  # to maintan conn pools

        self.state_lock = threading.Lock()  # make sure the main thread (pygame) and the pooling thread don't conflict
        self.running = True
        self.pool_thread = threading.Thread(target=self._pool_for_updates)
        self.pool_thread.daemon = True  # thus this exits when main program exits

    def start_new_game(self):
        try:
            r = self.session.post(f"{API_BASE_URL}/new")
            r.raise_for_status()  # if it gets a bad status code
            data = r.json()

            state = data.get("state", {})

            # while locking the state update
            with self.state_lock:
                self.game_id = data.get("game_id")
                self.guesses = state.get("guesses", [])
                self.current_row = len(self.guesses)
                self.current_guess = ""
                self.is_game_over = False or state.get("win", False)
                self.set_notification("New game started!")

        except requests.exceptions.RequestException:
            self.set_notification("Error: Couldn't connect to API")
        except ValueError:
            self.set_notification("Error: Invalid response for API")

    def _pool_for_updates(self):
        while self.running:  # polling is always on
            if not self.game_id:
                time.sleep(POLL_INTERVAL_SEC)
                continue

            try:
                r = self.session.get(f"{API_BASE_URL}/game/{self.game_id}")
                r.raise_for_status()
                data = r.json()

                # lock state
                with self.state_lock:
                    new_guesses = data.get("guesses", [])

                    # check if API state has new guesses
                    if len(new_guesses) > len(self.guesses):
                        self.guesses = new_guesses
                        self.current_row = len(self.guesses)
                        self.current_guess = ""
                        self.is_game_over = data.get("lost", False)
                        if self.is_game_over:
                            self.set_notification(f"Game over! The word was: {data.get('target', '???')}")
                        else:
                            self.set_notification("State updated by solver!")
            except requests.exceptions.RequestException:
                self.set_notification("Error: Couldn't connect to API")
            except ValueError:
                self.set_notification("Error: Invalid response for API")

        time.sleep(POLL_INTERVAL_SEC)

    def make_guess(self):
        if len(self.current_guess) != 5:
            self.set_notification("Guess must be 5 letters!")
            return
        if self.is_game_over:
            self.set_notification("Game over!")
            return

        try:
            payload = {"guess": self.current_guess}
            r = self.session.post(f"{API_BASE_URL}/game/{self.game_id}/make_guess", json=payload)
            r.raise_for_status()
            data = r.json()

            # API can return {"error": "..."} with 200 status :|
            if isinstance(data, dict) and data.get("error"):
                self.set_notification(data.get("error"))
                return

            # lock state
            with self.state_lock:
                self.guesses = data.get("guesses", [])
                self.current_row = len(self.guesses)
                self.current_guess = ""
                self.is_game_over = data.get("lost", False)

                if self.is_game_over:
                    if data.get("win", False):
                        self.set_notification("You won!")
                    else:
                        self.set_notification(f"Game over! The word was: {data.get('target', '???')}")
                else:
                    self.set_notification("Guess submitted. Awaiting next guess.")

        except requests.exceptions.RequestException:
            self.set_notification("Error: Couldn't connect to API")
        except ValueError:
            self.set_notification("Error: Invalid response from API")

    def handle_input(self, event):
        if event.type == pygame.KEYDOWN:
            if self.is_game_over:
                # allow sharting a new game
                if event.key == pygame.K_RETURN:
                    self.start_new_game()
                return

            if event.key == pygame.K_BACKSPACE:
                self.current_guess = self.current_guess[:-1]
            elif event.key == pygame.K_RETURN:
                self.make_guess()
            elif event.unicode.isalpha() and len(self.current_guess) < 5:
                self.current_guess += event.unicode.upper()

    def set_notification(self, message):
        self.notification = message

    def _colour(self, hex_str):
        try:
            return pygame.Color(hex_str)
        except Exception:
            return pygame.Color("#FFFFFF")

    def draw(self):  # honestly IDK how it works - TODO understand it later
        self.screen.fill(self._colour(COLOUR_MAP["bg"]))

        tile_size = 60
        tile_margin = 10
        start_x = (SCREEN_WIDTH - (5 * (tile_size + tile_margin) - tile_margin)) // 2
        start_y = 100

        # lock the state
        with self.state_lock:
            # draw the submitted guesses from guesses
            for r, (guess, result) in enumerate(self.guesses):
                for c, char in enumerate(guess):
                    hint = result[c] if c < len(result) else "b"
                    hint_colour_hex = COLOUR_MAP["hints"].get(hint, COLOUR_MAP["border"])
                    bg_col = self._colour(hint_colour_hex)
                    border_col = self._colour(COLOUR_MAP["filled_boarder"])
                    x = start_x + c * (tile_size + tile_margin)
                    y = start_y + r * (tile_size + tile_margin)
                    self.draw_tile(x, y, tile_size, char, bg_col, border_col)

            # draw the current guess (in the active row)
            if self.current_row < 6 and not self.is_game_over:
                y = start_y + self.current_row * (tile_size + tile_margin)
                for c in range(5):
                    x = start_x + c * (tile_size + tile_margin)
                    char = self.current_guess[c] if c < len(self.current_guess) else ""
                    border_colour = self._colour(COLOUR_MAP["border"])
                    self.draw_tile(x, y, tile_size, char, self._colour(COLOUR_MAP["bg"]), border_colour)

            # draw empty rows (up to default of 6)
            for r in range(self.current_row + 1, 6):
                y = start_y + r * (tile_size + tile_margin)
                for c in range(5):
                    x = start_x + c * (tile_size + tile_margin)
                    self.draw_tile(
                        x, y, tile_size, "", self._colour(COLOUR_MAP["bg"]), self._colour(COLOUR_MAP["border"])
                    )

        # draw notif
        if self.notification:
            notify_surf = self.notify_font.render(self.notification, True, self._colour(COLOUR_MAP["white"]))
            notify_rect = notify_surf.get_rect(center=(SCREEN_WIDTH // 2, 50))
            self.screen.blit(notify_surf, notify_rect)

        pygame.display.flip()

    def draw_tile(self, x, y, size, char, bg_colour, border_colour):
        """Helper function to draw a single tile."""
        # Tile background
        pygame.draw.rect(self.screen, bg_colour, (x, y, size, size))
        # Tile border
        pygame.draw.rect(self.screen, border_colour, (x, y, size, size), 2)

        # Letter
        if char:
            char_surf = self.tile_font.render(char, True, COLOUR_MAP["white"])
            char_rect = char_surf.get_rect(center=(x + size // 2, y + size // 2))
            self.screen.blit(char_surf, char_rect)

    def run(self):
        """Main game loop."""
        self.start_new_game()
        # start polling thread
        if not self.pool_thread.is_alive():
            self.pool_thread.start()

        while self.running:
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False  # Signal the poll thread to stop
                    break
                self.handle_input(event)

            self.draw()
            self.clock.tick(60)

        # Wait for the poll thread to finish one last loop
        self.pool_thread.join(timeout=POLL_INTERVAL_SEC)


if __name__ == "__main__":
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Wordle (Pygame API Client)")

    client = WordleClient(screen)
    client.run()

    pygame.quit()
    sys.exit()
