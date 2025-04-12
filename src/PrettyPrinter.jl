###################################### pretty printer #################################

function print_schedule(io,teams_names,sched)
    str = ""
    d = size(sched)

    d2 = div(d[2],2)
    d1 = div(d[1],2)
    
    for k in Base.OneTo(d[3])
        str = str * " \n Day $k \n"
        for j in Base.OneTo(d2)
            for i in Base.OneTo(d1)
	            if sched[i,j,k] == 1
	                str = str * teams_names[i] * " vs " * teams_names[j] * "\n"
	            end
	        end
        end
    end

    println(io,str)
end