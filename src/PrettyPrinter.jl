###################################### pretty printer #################################

function print_schedule(io,teams_names,sched)
    str = ""
    d = size(sched)

    d2 = div(d[2],1)
    d1 = div(d[1],1)
    
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

    println(io,sched)
    println(io,str)
end


function print_schedule(io,teams_names,sched::Dict,L,K,n)
    str = ""
    
    idx = 1
    cnt = 0

    str = str * " \n Day $idx \n"

    for k in Base.OneTo(K)

        for j in Base.OneTo(L)
            for i in Base.OneTo(L)
                if haskey(sched,((i,j),k))
                    if cnt < n
                        str = str * teams_names[i] * " vs " * teams_names[j] * "\n"
                        cnt += 1
                    else
                        idx +=1
                        str = str * " \n Day $idx \n"
                        cnt = 0
                    end
                end
            end
        end

        idx += 1
    end

    println(io,sched)
    println(io,str)
end
