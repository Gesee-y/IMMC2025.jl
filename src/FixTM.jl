using JuMP, Random, HiGHS, Cbc, GLPK

function solve_stgp_with_continents(
    T::Vector{Int}, # Liste des équipes
    C::Vector{Int}, # Clubs de chaque équipe (C[i] = club de l'équipe i)
    Z::Vector{Int}, # Continents de chaque équipe (Z[i] = continent de l'équipe i)
    d::Matrix{<:Real}, # Matrice de distances d[i,j]
    s::Vector{<:Real}, # Niveaux des differentes equipes
    m_min::Int, # Taille minimale d'une ligue
    m_max::Int, # Taille maximale d'une ligue
    c_max::Int, # Max équipes d'un même club par ligue
    d_max::Int, # Distance maximale entre équipes d'une ligue
    n::Int, # Nombre minimal d'équipes par continent dans une ligue
    continents::Vector{Int} # Liste des continents uniques (Z)
)
    # Création du modèle
    model = Model(Cbc.Optimizer)
    #set_optimizer_attribute(model, "TimeLimit", 3600) # Limite de temps

    # Définir les ensembles
    num_teams = length(T)
    L = 1:floor(Int, num_teams / m_min) # Nombre maximal de ligues
    M = 1:floor(Int, num_teams / (3m_min))

    # Variables
    @variable(model, x[i in T, ℓ in L], Bin) # x[i,ℓ] = 1 si équipe i dans ligue ℓ
    @variable(model, z[ℓ in L], Bin) # z[ℓ] = 1 si ligue ℓ est utilisée
    @variable(model, y[i in T, j in T; i < j && abs(s[i] - s[j]) <= 50 && d[i,j] <= d_max], Bin)

    # Objectif : minimiser la distance totale
    @objective(model, Min, sum(d[i,j] * y[i,j] for i in T, j in T if i < j && haskey(y, (i,j))))

    # Contraintes de base du STGP
    # Chaque équipe dans exactement une ligue
    @constraint(model, [i in T], sum(x[i,ℓ] for ℓ in L) == 1)

    # Taille des ligues
    for ℓ in L
        @constraint(model, sum(x[i,ℓ] for i in T) <= m_max * z[ℓ])
        @constraint(model, sum(x[i,ℓ] for i in T) >= m_min * z[ℓ])
    end

    # Limite d'équipes par club
    for ℓ in L, c in unique(C)
        @constraint(model,
            sum(x[i,ℓ] for i in T if C[i] == c) <= c_max * z[ℓ])
    end

    # Compatibilité des équipes
    @constraint(model, [(i,j) in eachindex(y), ℓ in L],
        x[i,ℓ] + x[j,ℓ] <= y[i,j] + 1)

    # Nouvelle contrainte : au moins n équipes par continent dans chaque ligue
    @constraint(model, [ℓ in L, k in continents],
        sum(x[i,ℓ] for i in T if Z[i] == k) >= n * z[ℓ])

    # Résolution
    optimize!(model)

    # Récupérer la solution
    if termination_status(model) == OPTIMAL
        println("Solution optimale trouvée")
        return value.(x), value.(z), objective_value(model)
    else
        println("Aucune solution optimale trouvée")
        return nothing
    end
end

######################################################################################################
##
##                                              CALENDAR
##
#######################################################################################################

struct ITCInstance
    teams::Int
    rounds::Int
    games::Vector{Tuple{Int,Int}}
    home_venues::Dict{Tuple{Int,Int}, Int}
end

function generate_instance(teams)
    teams % 2 == 0 || error("Nombre d'équipes pair requis")
    rounds = 2 * teams - 2
    games = [(i, j) for i in 1:teams for j in 1:teams if i < j]
    home_venues = Dict(g => g[1] for g in games)
    ITCInstance(teams, rounds, games, home_venues)
end

function create_initial_solution(instance)
    solution = Dict{Tuple{Tuple{Int,Int},Int},Float64}()
    schedule = Vector{Vector{Tuple{Int,Int}}}(undef, instance.rounds)
    mid = instance.rounds ÷ 2

    teams = collect(1:instance.teams)
    fixed = teams[1]
    rotating = teams[2:end]

    for r in 1:mid
        # Matchs aller
        matches = [(fixed, rotating[end])]
        num_pairs = (length(rotating) - 1) ÷ 2  # Correction clé ici
        for i in 1:num_pairs
            push!(matches, (rotating[i], rotating[end - i]))
        end
        schedule[r] = matches

        # Matchs retour 
        schedule[r + mid] = [(j, i) for (i, j) in matches if i ≠ j]

        # Rotation correcte
        last = pop!(rotating)
        insert!(rotating, 2, last)  # Rotation différente
    end

    # Vérification du nombre de matchs
    for (k, round) in enumerate(schedule)
        @assert length(round) == instance.teams ÷ 2 "Round $k: $(length(round)) matchs"
        for (i, j) in round
            home = i < j ? (i, j) : (j, i)
            solution[(home, k)] = 1.0
        end
    end
    solution
end

function select_variables(instance, n)
    selected = Set()
    rounds = randperm(instance.rounds)[1:min(n, instance.rounds)]
    for k in rounds
        available_games = shuffle(instance.games)
        for g in available_games[1:min(5, length(available_games))]
            push!(selected, (g, k))
        end
    end
    selected
end

function validate_solution(instance, solution)
    # Vérification complète des contraintes hard
    for k in 1:instance.rounds
        # Nombre de matchs par round
        count = sum(solution[(g, k)] for g in instance.games if haskey(solution, (g, k)))
        @assert count == instance.teams ÷ 2 "Round $k: $count matchs au lieu de $(instance.teams ÷ 2)"

        # Participation des équipes
        for t in 1:instance.teams
            participation = sum(solution[(minmax(t,j)..., k)] for j in 1:instance.teams if j ≠ t)
            @assert participation == 1.0 "Équipe $t non schedulée au round $k"
        end
    end
    true
end

function fix_and_optimize_heuristic(instance; time_limit=300, subproblem_size=5)
    model = Model(Cbc.Optimizer)
    set_silent(model)

    # Variables avec vérification des clés
    @variable(model, x[g in instance.games, k in 1:instance.rounds], Bin)

    # Contraintes validées
    for k in 1:instance.rounds
        @constraint(model, sum(x[:, k]) == instance.teams ÷ 2)
        for t in 1:instance.teams
            @constraint(model, sum(x[(min(t,j), max(t,j)), k] for j in 1:instance.teams if j ≠ t) == 1)
        end
    end

    # Objectif temporaire pour validation
    @objective(model, Min, 0)

    # Solution initiale garantie
    initial_solution = create_initial_solution(instance)
    #validate_solution(instance, initial_solution)

    # Initialisation
    for key in keys(x)
        set_start_value(x[key], get(initial_solution, key, 0.0))
    end

    # Phase 1: Trouver une solution réalisable
    optimize!(model)
    if termination_status(model) != MOI.OPTIMAL
        error("Aucune solution initiale réalisable")
    end

    # Phase 2: Optimisation des breaks
    @variable(model, breaks[t in 1:instance.teams, k in 1:instance.rounds-1] >= 0)
    for t in 1:instance.teams
        for k in 1:instance.rounds-1
            diff = @expression(model, sum(x[g,k]*(instance.home_venues[g] == t) - x[g,k+1]*(instance.home_venues[g] == t) for g in instance.games))
            @constraint(model, breaks[t,k] >= diff)
            @constraint(model, breaks[t,k] >= -diff)
        end
    end
    @objective(model, Min, sum(breaks))

    best_score = Inf
    start_time = time()

    while time() - start_time < time_limit
        vars = select_variables(instance, subproblem_size)
        
        # Réinitialisation partielle
        for key in keys(x)
            if key in vars
                unfix(x[key])
            else
                fix(x[key], get(initial_solution, key, 0.0); force=true)
            end
        end
        
        optimize!(model)
        
        if termination_status(model) == MOI.OPTIMAL
            current_score = objective_value(model)
            if current_score < best_score
                best_score = current_score
                for key in keys(x)
                    initial_solution[key] = value(x[key])
                end
            end
            subproblem_size = min(subproblem_size + 2, 10)
        else
            subproblem_size = max(subproblem_size - 1, 3)
        end
    end

    return best_score, initial_solution
end
