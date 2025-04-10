############################### Logistic Analysis ########################################

using HTTP
using JSON 

const API_KEY = "158017c8-7c5f-4d05-8735-13ba65db8e2a"
const BASE_URL = "https://graphhopper.com/api/1/route?"

function GetTravelData(sx,sy,ex,ey,transport::String; locale="en", key = API_KEY)
    
    params = Dict(
        "point" => [_parse_point(sx,sy),_parse_point(ex,ey)],
        "vehicle" => transport,
        "locale" => locale,
        "key" => key,
        "points_encoded" => "false"
    )

    #request_url = BASE_URL * "?" * join(["$k=$v" for (k,v) in params], "&")
    response = HTTP.get(BASE_URL, query=params)

    if response.status == 200

        route_data = JSON.parse(String(response.body))
    
    else
        println("ERROR: ", reponse.body)
    end

    return route_data
end

############################# Helper ###############################

_parse_point(x,y) = string(x) * "," * string(y)