# gets the data from appropriate sources

from urllib.request import urlretrieve


# should be valid unless the repos or the gist are deleated
word_list_url = "https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words_alpha.txt"
wordle_allowed_guesses_url = (
    "https://gist.githubusercontent.com/cfreshman/cdcdf777450c5b5301e439061d29694c/raw/"
    "d7c9e02d45afd26e12a71b4564189a949c29e8a9/wordle-allowed-guesses.txt"
)
wordle_answers_alphabetical_url = (
    "https://gist.githubusercontent.com/cfreshman/a03ef2cba789d8cf00c08f767e0fad7b/raw/"
    "c46f451920d5cf6326d550fb2d6abb1642717852/wordle-answers-alphabetical.txt"
)

urlretrieve(word_list_url, "./data/word_list.txt")
urlretrieve(wordle_allowed_guesses_url, "./data/wordle_allowed_guesses.txt")
urlretrieve(wordle_answers_alphabetical_url, "./data/wordle_answers_alphabetical.txt")
