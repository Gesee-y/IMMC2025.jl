# MODEL  

To create an efficient match schedule that accounts for travel distances, rest periods, team levels, etc., we began with the following assumptions:  

1. Countries are located via their capital city coordinates.  
2. Travel distance refers to the spherical distance between two capitals.  
3. Team strength is represented by their FIFA ranking.  

## Presentation  

The model starts by determining the 20 teams participating in the GSL using the framework from [1] Toffolo. It requires redefining certain variables:  

| Variable | Role |  
|----------|------|  
| Ti       | Includes all FIFA-registered teams worldwide |  
| C        | Set of "clubs" (continents in our model) |  
| dij      | Contains travel distances from country i to j |  
| Si       | Strength level of team i |  
| d+       | Maximum allowable travel distance |  
| s+       | Maximum allowable strength gap between teams |  
| m-       | Minimum number of teams per league (20 in our case) |  
| m+       | Maximum number of teams per league (24 in our model) |  

The model aims to minimize distances between two countries in the same league:  

```
Minimize: Σ dij yij  
           (i,j)∈A²  
```  
Subject to:  
- Each team i is assigned to exactly one league (Constraint 2):  
  ```Σ xi = 1 (2) ∀ ℓ∈L```  
- Strength gaps between teams are not extreme (Constraint 3):  
  ```|si − sj| ≤ 1 (3)```  
- Travel distances between countries do not exceed d+ (Constraint 4):  
  ```dij ≤ d+ (4)```  

To solve this model, we use the [2] Cbc solver and [3] JuMP in the [4] Julia language.  

Next, we apply the optimization method from [5] Toffolo and George H.G. to create a match schedule that accounts for breaks and home/away matches.  

Finally, we implement a program to streamline the generated schedule by distributing matches across days and ensuring rest periods for teams. The code is provided in the annexes.  

## Annexes  

### *&1* **Toffolo Model Program**  
```julia  
using JuMP, Random, Cbc  

function solve_stgp_with_continents(  
    T::Vector{Int},  # List of teams  
    C::Vector{Int},  # Club (continent) of each team  
    d::Matrix{<:Real},  # Distance matrix  
    s::Vector{<:Real},  # Team strength levels  
    m_min::Int,  # Minimum league size  
    m_max::Int,  # Maximum league size  
    c_max::Int,  # Max teams from the same club per league  
    d_max::Int,  # Max allowable distance  
    s_max::Int   # Max strength gap  
)  
    model = Model(Cbc.Optimizer)  
    num_teams = length(T)  
    L = 1:floor(Int, num_teams / m_min)  # Max number of leagues  

    # Variables  
    @variable(model, x[i in T, ℓ in L], Bin)  # 1 if team i is in league ℓ  
    @variable(model, z[ℓ in L], Bin)  # 1 if league ℓ is used  
    @variable(model, y[i in T, j in T; i < j && abs(s[i] - s[j]) <= s_max && d[i,j] <= d_max], Bin)  

    # Objective: Minimize total distance  
    @objective(model, Min, sum(d[i,j] * y[i,j] for i in T, j in T if i < j && haskey(y, (i,j))))  

    # Constraints  
    @constraint(model, [i in T], sum(x[i,ℓ] for ℓ in L) == 1)  # Each team in one league  
    for ℓ in L  
        @constraint(model, sum(x[i,ℓ] for i in T) <= m_max * z[ℓ])  
        @constraint(model, sum(x[i,ℓ] for i in T) >= m_min * z[ℓ])  
    end  
    for ℓ in L, c in unique(C)  
        @constraint(model, sum(x[i,ℓ] for i in T if C[i] == c) <= c_max * z[ℓ])  
    end  
    @constraint(model, [(i,j) in eachindex(y), ℓ in L], x[i,ℓ] + x[j,ℓ] <= y[i,j] + 1)  

    optimize!(model)  
    if termination_status(model) == OPTIMAL  
        return value.(x), value.(z), objective_value(model)  
    else  
        return nothing  
    end  
end  
```  

### *&2* **Toffolo and George H.G. Optimization Program**  
```julia  
using JuMP, Cbc  

struct ITCInstance  
    teams::Int  
    rounds::Int  
    games::Vector{Tuple{Int,Int}}  
    home_venues::Dict{Tuple{Int,Int}, Int}  
end  

function generate_instance(teams)  
    teams % 2 == 0 || error("Even number of teams required")  
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
        matches = [(fixed, rotating[end])]  
        num_pairs = (length(rotating) - 1) ÷ 2  
        for i in 1:num_pairs  
            push!(matches, (rotating[i], rotating[end - i])  
        end  
        schedule[r] = matches  
        schedule[r + mid] = [(j, i) for (i, j) in matches if i ≠ j]  
        last = pop!(rotating)  
        insert!(rotating, 2, last)  
    end  

    for (k, round) in enumerate(schedule)  
        for (i, j) in round  
            home = i < j ? (i, j) : (j, i)  
            solution[(home, k)] = 1.0  
        end  
    end  
    return solution  
end  

function fix_and_optimize_heuristic(instance; time_limit=300, subproblem_size=5)  
    model = Model(Cbc.Optimizer)  
    @variable(model, x[g in instance.games, k in 1:instance.rounds], Bin)  
    # ... (additional constraints and optimization loop)  
end  
```  

### *&3* **Calendar Printer**  
```julia  
function print_schedule(  
    io::IO,  
    teams_names::Vector{<:AbstractString},  
    sched::Dict,  
    L,  # Number of teams  
    n   # Matches per day  
)  
    str = ""  
    K = 2L - 2  # Total rounds  
    idx = 1  
    cnt = 0  
    str *= "\nDay $idx\n"  

    for k in 1:K  
        for j in 1:L, i in 1:L  
            if haskey(sched, ((i,j),k)  
                if cnt < n  
                    str *= teams_names[i] * " vs " * teams_names[j] * "\n"  
                    cnt += 1  
                else  
                    idx += 1  
                    str *= "\nDay $idx\n"  
                    cnt = 0  
                end  
            end  
        end  
    end  
    println(io, str)  
end  
```  

**Resulting Calendar Example**  
```
 Day 1
Grenade vs Aruba
Dominica vs Turks and Caicos Islands
Barbados vs Coree du Nord

 Day 2
Panama vs Guam
Somalie vs Russie
Burundi vs Grece

 Day 3
Togo vs Belarus
Senegal vs Chypre
Dominica vs Grenade

 Day 5
Curacao vs Turks and Caicos Islands
Panama vs Coree du Nord
Somalie vs Timor Leste

 Day 6
Botswana vs Russie
Togo vs Slovenie
Senegal vs Belarus

 Day 7
Barbados vs Dominica
Curacao vs Grenade
Panama vs Aruba

 Day 9
Burundi vs Coree du Nord
Botswana vs Timor Leste
Togo vs Grece

 Day 10
Russie vs Belarus
Guam vs Chypre
Curacao vs Barbados

 Day 12
Somalie vs Grenade
Burundi vs Aruba
Botswana vs Turks and Caicos Islands

 Day 13
Senegal vs Grece
Guam vs Slovenie
Timor Leste vs Belarus

 Day 14
Panama vs Curacao
Somalie vs Barbados
Burundi vs Dominica

 Day 16
Togo vs Guam
Senegal vs Russie
Timor Leste vs Grece

 Day 17
Turks and Caicos Islands vs Belarus
Aruba vs Chypre
Somalie vs Panama

 Day 19
Botswana vs Barbados
Togo vs Timor Leste
Senegal vs Guam

 Day 20
Turks and Caicos Islands vs Grece
Aruba vs Slovenie
Grenade vs Belarus

 Day 21
Burundi vs Somalie
Botswana vs Panama
Togo vs Coree du Nord

 Day 23
Turks and Caicos Islands vs Guam
Aruba vs Russie
Grenade vs Grece

 Day 24
Barbados vs Belarus
Curacao vs Chypre
Botswana vs Burundi

 Day 26
Senegal vs Coree du Nord
Aruba vs Timor Leste
Grenade vs Guam

 Day 27
Barbados vs Grece
Curacao vs Slovenie
Panama vs Belarus

 Day 28
Togo vs Aruba
Senegal vs Turks and Caicos Islands
Grenade vs Coree du Nord

 Day 30
Barbados vs Guam
Curacao vs Russie
Panama vs Grece

 Day 31
Burundi vs Belarus
Botswana vs Chypre
Togo vs Grenade

 Day 33
Dominica vs Turks and Caicos Islands
Barbados vs Coree du Nord
Curacao vs Timor Leste

 Day 34
Somalie vs Russie
Burundi vs Grece
Botswana vs Slovenie

 Day 35
Togo vs Dominica
Senegal vs Grenade
Barbados vs Aruba

 Day 37
Panama vs Coree du Nord
Somalie vs Timor Leste
Burundi vs Guam

 Day 38
Slovenie vs Belarus
Grece vs Chypre
Togo vs Barbados

 Day 40
Curacao vs Grenade
Panama vs Aruba
Somalie vs Turks and Caicos Islands

 Day 41
Botswana vs Timor Leste
Grece vs Slovenie
Russie vs Belarus

 Day 42
Togo vs Curacao
Senegal vs Barbados
Panama vs Dominica

 Day 44
Burundi vs Aruba
Botswana vs Turks and Caicos Islands
Russie vs Grece

 Day 45
Timor Leste vs Belarus
Coree du Nord vs Chypre
Togo vs Panama

 Day 47
Somalie vs Barbados
Burundi vs Dominica
Botswana vs Grenade

 Day 48
Timor Leste vs Grece
Coree du Nord vs Slovenie
Turks and Caicos Islands vs Belarus

 Day 49
Togo vs Somalie
Senegal vs Panama
Burundi vs Curacao

 Day 51
Timor Leste vs Guam
Coree du Nord vs Russie
Turks and Caicos Islands vs Grece

 Day 52
Grenade vs Belarus
Dominica vs Chypre
Togo vs Burundi

 Day 54
Botswana vs Panama
Coree du Nord vs Timor Leste
Turks and Caicos Islands vs Guam

 Day 55
Grenade vs Grece
Dominica vs Slovenie
Barbados vs Belarus

 Day 56
Togo vs Botswana
Senegal vs Burundi
Turks and Caicos Islands vs Coree du Nord

 Day 58
Grenade vs Guam
Dominica vs Russie
Barbados vs Grece

 Day 59
Panama vs Belarus
Somalie vs Chypre
Senegal vs Botswana

 Day 61
Grenade vs Coree du Nord
Dominica vs Timor Leste
Barbados vs Guam

 Day 62
Panama vs Grece
Somalie vs Slovenie
Burundi vs Belarus

 Day 63
Grenade vs Aruba
Dominica vs Turks and Caicos Islands
Barbados vs Coree du Nord

 Day 65
Panama vs Guam
Somalie vs Russie
Burundi vs Grece

 Day 66
Togo vs Belarus
Senegal vs Chypre
Grenade vs Aruba

 Day 68
Barbados vs Coree du Nord
Curacao vs Timor Leste
Panama vs Guam

 Day 69
Burundi vs Grece
Botswana vs Slovenie
Togo vs Belarus

 Day 70
Dominica vs Grenade
Barbados vs Aruba
Curacao vs Turks and Caicos Islands

 Day 72
Somalie vs Timor Leste
Burundi vs Guam
Botswana vs Russie

 Day 73
Senegal vs Belarus
Grece vs Chypre
Barbados vs Dominica

 Day 75
Panama vs Aruba
Somalie vs Turks and Caicos Islands
Burundi vs Coree du Nord

 Day 76
Togo vs Grece
Senegal vs Slovenie
Russie vs Belarus

 Day 77
Curacao vs Barbados
Panama vs Dominica
Somalie vs Grenade

 Day 79
Botswana vs Turks and Caicos Islands
Togo vs Russie
Senegal vs Grece

 Day 80
Timor Leste vs Belarus
Coree du Nord vs Chypre
Panama vs Curacao

 Day 82
Burundi vs Dominica
Botswana vs Grenade
Togo vs Guam

 Day 83
Timor Leste vs Grece
Coree du Nord vs Slovenie
Turks and Caicos Islands vs Belarus

 Day 84
Somalie vs Panama
Burundi vs Curacao
Botswana vs Barbados

 Day 86
Senegal vs Guam
Coree du Nord vs Russie
Turks and Caicos Islands vs Grece

 Day 87
Grenade vs Belarus
Dominica vs Chypre
Burundi vs Somalie

 Day 89
Togo vs Coree du Nord
Senegal vs Timor Leste
Turks and Caicos Islands vs Guam

 Day 90
Grenade vs Grece
Dominica vs Slovenie
Barbados vs Belarus

 Day 91
Botswana vs Burundi
Togo vs Turks and Caicos Islands
Senegal vs Coree du Nord

 Day 93
Grenade vs Guam
Dominica vs Russie
Barbados vs Grece

 Day 94
Panama vs Belarus
Somalie vs Chypre
Togo vs Aruba

 Day 96
Grenade vs Coree du Nord
Dominica vs Timor Leste
Barbados vs Guam

 Day 97
Panama vs Grece
Somalie vs Slovenie
Burundi vs Belarus

 Day 98
Togo vs Grenade
Senegal vs Aruba
Dominica vs Turks and Caicos Islands

 Day 100
Curacao vs Timor Leste
Panama vs Guam
Somalie vs Russie

 Day 101
Botswana vs Slovenie
Belarus vs Chypre
Togo vs Dominica

 Day 103
Barbados vs Aruba
Curacao vs Turks and Caicos Islands
Panama vs Coree du Nord

 Day 104
Burundi vs Guam
Botswana vs Russie
Slovenie vs Belarus

 Day 105
Togo vs Barbados
Senegal vs Dominica
Curacao vs Grenade

 Day 107
Somalie vs Turks and Caicos Islands
Burundi vs Coree du Nord
Botswana vs Timor Leste

 Day 108
Russie vs Belarus
Guam vs Chypre
Togo vs Curacao

 Day 110
Panama vs Dominica
Somalie vs Grenade
Burundi vs Aruba

 Day 111
Russie vs Grece
Guam vs Slovenie
Timor Leste vs Belarus

 Day 112
Togo vs Panama
Senegal vs Curacao
Somalie vs Barbados

 Day 114
Botswana vs Grenade
Guam vs Russie
Timor Leste vs Grece

 Day 115
Turks and Caicos Islands vs Belarus
Aruba vs Chypre
Togo vs Somalie

 Day 117
Burundi vs Curacao
Botswana vs Barbados
Timor Leste vs Guam

 Day 118
Turks and Caicos Islands vs Grece
Aruba vs Slovenie
Grenade vs Belarus

 Day 119
Togo vs Burundi
Senegal vs Somalie
Botswana vs Panama

 Day 121
Turks and Caicos Islands vs Guam
Aruba vs Russie
Grenade vs Grece

 Day 122
Barbados vs Belarus
Curacao vs Chypre
Togo vs Botswana

 Day 124
Turks and Caicos Islands vs Coree du Nord
Aruba vs Timor Leste
Grenade vs Guam

 Day 125
Barbados vs Grece
Curacao vs Slovenie
Panama vs Belarus

 Day 126
Senegal vs Botswana
Aruba vs Turks and Caicos Islands
Grenade vs Coree du Nord

 Day 128
Barbados vs Guam
Curacao vs Russie
Panama vs Grece

 Day 129
Burundi vs Belarus
Togo vs Chypre
Grenade vs Aruba

 Day 131
Barbados vs Coree du Nord
Curacao vs Timor Leste
Panama vs Guam

 Day 132
Burundi vs Grece
Botswana vs Slovenie
Togo vs Belarus
```  

# References  
1. Toffolo, T. A. M., et al. "The Sport Teams Grouping Problem." *Annals of Operations Research*, 2019.  
2. Cbc Solver: [https://github.com/coin-or/Cbc](https://github.com/coin-or/Cbc)  
3. JuMP: [https://juliapackages.com/p/jump](https://juliapackages.com/p/jump)  
4. Julia Language: [https://julialang.org](https://julialang.org)  
5. Fonseca, G. H. G., & Toffolo, T. A. M. "A Fix-and-Optimize Heuristic for the ITC2021 Sports Timetabling Problem."  

# AI Report  
- The document was translated from French to English using Deepseek.  
- Team data was collected from online sources and formatted into CSV files.
- Toffolo's model was constructed using Deepseek
- Toffolo and Georges H.G optimization model was built using Deepseek