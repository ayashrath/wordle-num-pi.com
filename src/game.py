"""
Defines the game logic
"""

import random
from typing import List
import json


# constants
WORD_LIST_DIR = "./data/"
with open("./src/config.json", "r") as fh:
    data = json.load(fh)
WORD_LIST_GUESS = data["word_list_guess"]
WORD_LIST_ANS = data["word_list_ans"]
MAX_GUESSES = data["max_guesses"]


def filter_five_letter_words(word_list: List[str]) -> List[str]:
    """
    Mainly to filter all the words in word_list.txt which are not 5 letter words
    """
    main_lst = []
    for word in word_list:
        if len(word) == 5:
            main_lst.append(word)
    return main_lst


class Wordle:
    """
    The game of Wordle

    The logic applies 3 states to char of guess word:
        - grey (=b): not in the target (b = black, approx grey)
        - yellow (=y): in the target, but not in this position
        - green (=g): in the target and in this position

    Also there is some extra logic required to deal with repeating letters: if you use a letter twice and it only
    appears in the word once but neither is in the right spot, the first instance will be yellow and the
    second will not. If the letter does appear in the word twice but neither is in the right spot, both will be yellow.
    """
    def __init__(
        self, word_list_guess: str = WORD_LIST_GUESS,
        word_list_ans: str = WORD_LIST_ANS,
        max_guesses: int = MAX_GUESSES
    ):
        """
        Only takes files - word_list.txt, wordle_allowed_guesses.txt and wordle_answers_alphabetical.txt
        In word_list.txt, both the possible ans and guesses are the same list. While the wordle_*.txt are disjoint sets

        Args:
            - word_list_guess: list of guesses.
            - word_list_ans: list of possible ans.
            - max_guesses (=6): Am allowing it to be dynamic as can help find exactly how many moves a solver needs to
                solve even if it exceeds the normal limit of 6.
        """

        if (
            word_list_guess not in ("word_list.txt", "wordle_allowed_guesses.txt") or
            word_list_ans not in ("word_list.txt", "wordle_answers_alphabetical.txt")
        ):
            raise FileNotFoundError(
                "Choose one of these files appropriately - word_list.txt, wordle_answers_alphabetical.txt, "
                "wordle_allowed_guesses.txt"
            )
        if word_list_ans != word_list_guess and (
            word_list_ans == "word_list.txt" or word_list_guess == "word_list.txt"
        ):
            raise ValueError("If using word_list.txt, it must be both the ans and the guess lists")

        # using .upper() as makes all the string cases uniform, and also as that is how the wordle words are displayed
        with open(WORD_LIST_DIR + word_list_ans, "r") as fh:
            self.ans_list = filter_five_letter_words([line.strip().upper() for line in fh])  # all possible ans
        with open(WORD_LIST_DIR + word_list_guess, "r") as fh:  # possible guesses (includes ans)
            if word_list_guess == "word_list.txt":
                self.guess_list = filter_five_letter_words([line.strip().upper() for line in fh])
            else:
                self.guess_list = [line.strip().upper() for line in fh] + self.ans_list

        self.target_word = random.choice(self.ans_list)
        self.len_word = 5  # can be changed if we are using word_list.txt - but not worth making it dynamic
        # TODO - add dynamic len_word, and ensure if its dynamic, it must depend on word_list.txt
        self.max_guesses = max_guesses
        self.guesses = []  # List of tuples (guess, result)

        # game states - helps make the code more readable, instead of always checking a condition
        self.lost = False
        self.win = False

    def make_guess(self, guess_word):
        guess_word = guess_word.upper()

        # instead of raising exceptions, its a better idea to return a dict with key error
        # as it allows to be handled later
        if self.lost:
            return {"error": "Game Over!"}
        elif self.win:
            return {"error": "You have already won!!"}
        elif len(guess_word) != self.len_word or not guess_word.isalpha() or guess_word not in self.guess_list:
            return {"error": "Invalid Guess :("}

        # Game Logic
        result = ["b"] * self.len_word  # b = grey, y = yellow, g = green

        target_count = {}  # to deal with repeat logic
        for char in set(self.target_word):
            target_count[char] = self.target_word.count(char)

        # find green
        for ind in range(self.len_word):
            if guess_word[ind] == self.target_word[ind]:
                result[ind] = "g"
                target_count[guess_word[ind]] -= 1

        # find yellow
        for ind in range(self.len_word):
            if result[ind] != "g" and guess_word[ind] in self.target_word and target_count.get(guess_word[ind], 0) > 0:
                # using get as some char may not be in target
                result[ind] = "y"
                target_count[guess_word[ind]] -= 1

        self.guesses.append((guess_word, result))

        # check win/loss conditions
        if guess_word == self.target_word:
            self.win = True
        elif len(self.guesses) >= self.max_guesses:
            self.lost = True

        return self.get_state()

    def get_state(self):
        return {
            "chances_left": self.max_guesses - len(self.guesses),
            "lost": self.lost,
            "win": self.win,
            "guesses": self.guesses,
            # "target": self.target_word  # for debugging
        }
