include("../LogisticAnalysis.jl")

function main()
    sx, sy = 48.853, 2.349
    ex, ey = 48.856, 2.352

    transport = "car"

    data = GetTravelData(sx,sy,ex,ey,transport)
    println(data)
end

main()