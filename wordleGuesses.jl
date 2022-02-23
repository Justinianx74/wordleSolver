import StatsBase: countmap

# Known bugs: 
# readline() takes two tries on the first attempt to get input from the user. 

println("Starting")
f = open("C:\\Users\\jd74h\\Documents\\wordleSolver\\wordle-answers-alphabetical.txt", "r")
g = open("C:\\Users\\jd74h\\Documents\\wordleSolver\\wordle-allowed-guesses.txt")

# Setting up the words
# TODO: Move this to another file
words = Vector{String}()
possibleWords = Vector{String}()

for line in readlines(f)
    push!(words, line)
end

for line ∈ readlines(g)
    push!(possibleWords,line)
end
close(g)
close(f)


# Set up for functions in guess
# TODO: Make all of this a module
log2_safe(x) = x > 0 ? log2(x) : 0
entropy(dist) = -1 * (sum(dist .* log2_safe.(dist)))


# Functions to constrain the corpus
# TODO: Make a wrapper function for all of these
function lettersContained(letters::String, words::Array{String,1})
    letters = [Char(i) for i ∈ letters]
    filterString = ""
    for letter ∈ letters
        filterString *= "(?=.*$letter)"
    end
    filterString *= ".+"
    filter!(contains(Regex(filterString)), words)
    return words
end
function yellowLetters(letters, words::Array{String,1})
    filterString = fill(".",5)
    for i ∈ 1:5
        if !isempty(letters[i])
            filterString[i] = "[^" * join(letters[i]) * "]"
        end
    end
    filter!(contains(Regex(join(filterString,""))), words)
    return words
end

function blackLetters(letters::String, words::Array{String,1})
    filterString = "[" * letters * "]"
    filter!(!contains(Regex(filterString)),words)
    return words
end

function greenLetters(letters, words::Array{String,1})

    filterString = fill('.',5)
    for i ∈ 1:5
        if !isempty(letters[i])
            filterString[i] = Char(letters[i][1])
        end
    end
    filter!(contains(Regex(join(filterString,""))),words)
    return words
end
function guess(query::String, answer::String)

    ### grey is 0
    ### yellow is 1
    ### green is 2

    letters = countmap(answer)
    result = ['0' for i ∈ 1:5]

    # Checks for green letter
    for i ∈ 1:5
        if answer[i] == query[i]
            result[i] = '2'
            letters[query[i]] -= 1
        end
    end

    for i = 1:5
        if occursin(query[i], answer) && (result[i] ≠ '2') && (letters[query[i]] > 0)
            result[i] = '1'
            letters[query[i]] -=1
        end
    end
    join(result,"")
end

function choose(words::Vector{String})

    # This choosing algorithm doesn't work well when down to few options, so I just chose n=2 and if that happens, just pick randomly
    # Could do more testing to see if n=[3,10] deals best with choosing randomly
    if length(words) ≤ 2
        return words[rand(1:length(words))]
    end

    # Checks if every word has a letter in the same position. If true, we know that one letter
    isKnown = [all(x[i] == words[1][i] for x ∈ words) for i ∈ 1:5]


    # Build the word so far, based on the letters we know for sure.
    wordSoFar = string([isKnown[j] ? words[1][j] : '0' for j ∈ 1:5]...)

    # Dict to see frequency of chars in each position
    hasCharInPos = Dict()

    # Loops through every word left in the corpus, builds a frequency list for them
    for i ∈ 0:25
        char = 'a' + i
        for j ∈ 1:5
            hasCharInPos[char] = [sum(x[j] == char for x ∈ words) for j ∈ 1:5]
        end
    end
    # Variable for the best word so far
    bestWord = ""

    # Variable for best entropy so far. We want to find the word with the most entropy, 
    # as that splits our corpus the best
    bestDiffEntropy = 0

    # Iterate over every word in the possible words. We don't use the narrowed corpus here, we use the entire accepted words
    # That is because sometimes the word that splits the corpus best isn't in the corpus. Take for example the word being shake,
    # and having guessed shade. Shale, shame, shape, share, and shame are possible, but guessing any of those will hardly narrow down anything.
    # Guessing something with l, m, p, and r tells us exactly which one it will be
    for word ∈ possibleWords
        diffEntropy = 0
        seenChars = Set()
        # Loop to find entropy of word
        for (i, char) ∈ enumerate(word)
            # Amount of greens if guessed word was correct
            greens = hasCharInPos[char][i]

            # Condition that we haven't seen this character before. If we haven't seen it before, then it could be a yellow
            if char ∉ seenChars
                # Find if the character is in the wrong spot, and sum them to get the total of the yellows
                mask = [ch ≠ char for ch ∈ wordSoFar]
                yellows = sum(hasCharInPos[char][mask]) - greens
                push!(seenChars, char)
            else
                yellows = 0
            end
            # We know that the greys are just the amount of words, minus the amount of yellows and greens
            greys = length(words) - yellows - greens

            # Build the vector of all the greens, yellows, and greys
            dist = [greens, yellows, greys]

            # This just finds the average of all the greens, yellows and greys. Just amountGreen/sum(green,yellows,greys)
            dist = dist ./ sum(dist)

            # Add the entropy for this letter
            diffEntropy += entropy(dist)
        end
        # We have now found the entropy by letter for the entire word. If it is the best so far, save it
        if diffEntropy > bestDiffEntropy
            bestDiffEntropy = diffEntropy
            bestWord = word
        end
    end
    # Return the best word to split
    bestWord

end

function play(words)

    # Function to play. Requires user input from command line. 
    # User must play wordle on their own and give the bot information about the guesses

    # Initialize this being the first guess
    i = 1


    # Variables for constraining the search field
    containing = ""
    yellows = [[] for _ ∈ 1:5]
    greys = ""
    greens = [[] for _ ∈ 1:5]

    # Loop for each guess. Conditions that the available guesses are more than 1 guess (which would for sure be the answer), 
    # and that we haven't used all our guesses. This isn't strictly necessary, 
    # as I'm not fulling emulating the game, but it doesn't hurt anything
    while (length(words) > 1) && (i ≤ 6)
        # Get the best guess from choose()
        query = choose(words)

        # Print what the best guess is and how many guesses are still valid
        println("query: ", query)
        println("Length of corpus: ", length(words))
        # If there aren't too many words, print out them. This is purely cause I'm curious about it
        if length(words) < 10
            println("Valid words: ", words)
        end
        
        # We've used a guess, so add one to our guess countmap
        i += 1

        # Get result like how it is explained in guess()
        ### grey is 0
        ### yellow is 1
        ### green is 2
        result = readline()

        # Check if I've inputted too many numbers. 
        # If I have, just chop the end off. Not great trouble shooting, but it will prevent a crash later
        result = length(result) > 5 ? result[1:5] : result


        # Iterate over input and add to the constraining variables
        for i ∈ 1:length(result)
            if result[i] == '2'
                containing *= query[i]
                push!(greens[i], query[i])
                if query[i] ∈ greys
                    greys = replace(greys, query[i]=>"")
                end
            elseif result[i] == '1'
                containing *= query[i]
                push!(yellows[i], query[i])
            elseif query[i] ∉ containing
                greys *= query[i]
            end
        end
        # filter the words vector
        words = !(isempty(containing)) ? lettersContained(containing, words) : words
        words = sum(isempty.(yellows)) ≥ 1 ? yellowLetters(yellows, words) : words
        words = !(isempty(greys)) ? blackLetters(greys,words) : words
        words = sum(isempty.(greens)) ≥ 1 ? greenLetters(greens, words) : words
    end
    # If condition that would break our while loop, just print out the word
    # Common case is theres two left, and we pick randomly between those
    if (length(words) == 1)
        println("The correct word: ", choose(words))
    end
end

# Effectively the main. Call the play function
play(words)
 
println("Ending")