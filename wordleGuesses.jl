import StatsBase: countmap
import LinearAlgebra: ⋅


f = open("C:\\Users\\jd74h\\Documents\\wordle\\wordle-answers-alphabetical.txt", "r")
g = open("C:\\Users\\jd74h\\Documents\\wordle\\wordle-allowed-guesses.txt")


println("Starting")




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



log2_safe(x) = x > 0 ? log2(x) : 0
entropy(dist) = -1 * (sum(dist .* log2_safe.(dist)))

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

    
    isKnown = [all(x[i] == words[1][i] for x ∈ words) for i ∈ 1:5]
    println(isKnown)
    wordSoFar = string([isKnown[j] ? words[1][j] : '0' for j ∈ 1:5]...)
    hasCharInPos = Dict()

    for i ∈ 0:25
        char = 'a' + i
        for j ∈ 1:5
            hasCharInPos[char] = [sum(x[j] == char for x ∈ words) for j ∈ 1:5]
        end
    end

    bestWord = ""

    bestDiffEntropy = 0

    for word ∈ possibleWords
        diffEntropy = 0
        seenChars = Set()
        for (i, char) ∈ enumerate(word)
            greens = hasCharInPos[char][i]
            if char ∉ seenChars
                mask = [ch ≠ char for ch ∈ wordSoFar]
                yellows = sum(hasCharInPos[char][mask]) - greens
                push!(seenChars, char)
            else
                yellows = 0
            end
            greys = length(words) - yellows - greens
            dist = [greens, yellows, greys]
            dist = dist ./ sum(dist)
            diffEntropy += entropy(dist)
        end
        if diffEntropy > bestDiffEntropy
            bestDiffEntropy = diffEntropy
            bestWord = word
        end
    end

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
        println(query)
        println(length(words))
        # If there aren't too many words, print out them. This is purely cause I'm curious about it
        if length(words) < 10
            println(words)
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
                println(typeof(greys))
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
        println(choose(words))
    end
end

# Effectively the main. Call the play function
play(words)
 
println("Ending")