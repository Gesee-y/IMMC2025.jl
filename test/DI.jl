include("../DataImporter.jl")

const FILE_PATH = "data.csv"

function main()

    data = GetCSVData(FILE_PATH, (String, Int, Int, Int))

    println(data)
end

main()