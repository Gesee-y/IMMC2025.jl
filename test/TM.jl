include("../TeamMatchups.jl")
include("../FixTM.jl")
include("../LogisticAnalysis.jl")
include("../PrettyPrinter.jl")
include("../DataImporter.jl")

const PATH1 = "../Data/ClassementAF.txt"
const PATH2 = "../Data/ClassementAM.txt"
const PATH3 = "../Data/ClassementAS.txt"
const PATH4 = "../Data/ClassementEU.txt"
const PATH5 = "../Data/ClassementOC.txt"

# cl, prec, pays, matchs, V, N, D, points, Latitude, Longitude
const SIGNATURE = (Int,Int,String,Int,Int,Int,Int,Int,Float64,Float64)

function main()
    datas = GetCSVData(path,(Int,Int,String,Int,Int,Int,Int,Float16))

    xa = data[1][5:7]
    xb = data[2][5:7]

    pb = [1.5,0.5,1]
    pb = [1,0.5,1.5]
end

strength = [0.6,0.9,0.4,0.7,0.8]

function test()
    x = Grouping(4,strength)
    print_schedule(stdout,["Cameroun","Brezil","Cambodge","France","Angleterre","Allemagne","Maroc",
        "Chili","Arabie","Chine","Japon","Canada","Espagne","Italy","Nigeria","Tunisie", "Benin",
        "Coree","Nouvelle-Zelande","Malaisie"],x)
end

function test2()

    T = 1:6
    C = 1:3
    ci = [1, 1, 2, 2, 3, 3]
    si = [1, 1, 2, 2, 3, 3]
    dij = [0 10 30 40 50 60;
           10 0 20 25 55 65;
           30 20 0 10 45 50;
           40 25 10 0 35 40;
           50 55 45 35 0 15;
           60 65 50 40 15 0]
    dmax = 50
    mmin, mmax = 2, 3
    cmax = 1
    L = 1:3  # max nombre de ligues
    x = ToffoloGrouping(T,C,L,mmin,mmax,cmax,dmax,si,dij,ci)

    #println(x)
end

function test3()
    teams, T, C = _GetTeams() # 20 équipes
    Z = copy(C)
    d = _GetDistance(teams) # Distances aléatoires
    s = _GetStrength(teams)

    res = solve_stgp_with_continents(T, C, Z, d, s, 20, 24, 50, 300, 0, [1,2,3,4,5])
    leagues = _get_leagues(teams,res)
    println("\n\n CALENDAR")

    instance = generate_instance(20)
    score, solution = fix_and_optimize_heuristic(instance, time_limit=20)

    print_schedule(stdout,leagues[1],solution,20,38,3)
end

function _GetTeams()
    teams1 = GetCSVData(PATH1, SIGNATURE)
    teams2 = GetCSVData(PATH2, SIGNATURE)
    teams3 = GetCSVData(PATH3, SIGNATURE)
    teams4 = GetCSVData(PATH4, SIGNATURE)
    teams5 = GetCSVData(PATH5, SIGNATURE)

    teams = append!(teams1, teams2, teams3, teams4, teams5)
    C = append!(fill(1,length(teams1)), fill(2,length(teams2)), fill(3,length(teams3)), fill(4,length(teams4)), fill(5,length(teams5)))
    T = Vector(1:length(teams))

    return teams,T,C
end

function _GetStrength(teams::AbstractArray)
    return [team[end-2] for team in teams]
end

function _GetDistance(teams::AbstractArray)
    L = length(teams)

    dist = Array{Float64}(undef, L, L)

    for i = 1:L, j = 1:L
        if i != j
            sx, sy = teams[i][end-1]/32, teams[i][end]/32
            ex, ey = teams[j][end-1]/32, teams[j][end]/32

            d = GetSurfDist(sy,sx,ey,ex)
            
            isnan(d) && (d = 0)
            dist[i,j] = d
            dist[j,i] = d
        else
            dist[i,j] = 0
        end
    end

    return dist
end

function _get_leagues(teams,res)
    A = res[1]
    S = size(A)
    L = []
    for i in 1:S[2]
        x = []
        for j in 1:S[1]
            if A[j,i] != 0
                push!(x,teams[j][3])
            end
        end
        push!(L,x)    
    end

    return L
end

function _print_res(teams,res)
    A = res[1]
    S = size(A)
    for i in 1:S[2]
        x = []
        for j in 1:S[1]
            if A[j,i] != 0
                push!(x,teams[j][3])
            end
        end    
        println("Ligue $i : $x")
    end
end

_clamp_pi(x) = begin
    while x > pi/2
        x = pi/2
    end

    while x < pi/2
        x += pi/2
    end

    return x
end

test3()
#main()