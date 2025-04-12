################################### Finding the best team matchups #############################

using JuMP, HiGHS, Random

######### Way 1: Shuo Chen, Thorsten Joachims's blade-chest model ############

function get_probability(pbweigth, pcweigth, gbweigth, gcweigth, pa, pb, game_data)

    ac = _entrywise_prod(tanh.(gcweigth*game_data), tanh.(pcweigth*pa))
    bc = _entrywise_prod(tanh.(gcweigth*game_data), tanh.(pcweigth*pb))
    ab = _entrywise_prod(tanh.(gbweigth*game_data), tanh.(pbweigth*pa))
    bb = _entrywise_prod(tanh.(gbweigth*game_data), tanh.(pbweigth*pb))

    v = dot(ab,bc) - dot(ac,bb)
end

function get_probability(pbweigth, pcweigth, pa, pb)

    ac = tanh.(pcweigth*pa)
    bc = tanh.(pcweigth*pb)
    ab = tanh.(pbweigth*pa)
    bb = tanh.(pbweigth*pb)

    v = dot(ab,bc) - dot(ac,bb)
end

############################# Grouping ##################################
######### Commence ici#########

const MAX_TIME = 120
const SUBPB_SIZE = 2
const SUBPB_TIMEOUT = 20

function Grouping(N)

    # Model initializatio
    model = Model(HiGHS.Optimizer)
    set_time_limit_sec(model, MAX_TIME)

    # We generate a dummy initial schedule 
    x_init = _generate_initial_solution(N)

    # To handle the breaks
    @variable(model, b_break[i=1:N, k=1:2N-3])

    # This will contain our output calendar
    @variable(model, x[i=1:N, j=1:N, k=1:2N-2])

    @variable(model, home_games[i=1:N] >= 0)
    @variable(model, max_home)
    @variable(model, min_home)

    ## Contraint a team i to only have to match with a team j
    for i in Base.OneTo(N), j in Base.OneTo(N)
        i != j && @constraint(model, sum(x[i,j,k] + x[j,i,k] for k in Base.OneTo(2N-2)) == 2)
    end

    # Constraint the model to avoid AAA or HHH (playing 3 consecutive match Away or at Home)
    for i in Base.OneTo(N), k in Base.OneTo(2N-3)
        
        @constraint(model, b_break[i,k] >= sum(x[i,j,k] - x[i,j,k+1] for j in Base.OneTo(N) if j != i))
        @constraint(model, b_break[i,k] >= sum(x[j,i,k] - x[j,i,k+1] for j in Base.OneTo(N) if j != i))
    end

    for i in Base.OneTo(N)
        @constraint(model, home_games[i] == sum(x[i,j,k] for j in Base.OneTo(N), k in Base.OneTo(2N-2) if j != i))
        @constraint(model, max_home >= home_games[i])
        @constraint(model, min_home <= home_games[i])
    end

    # We apply the optimization on the model and return it
    return _fix_and_optimize!(model,x,x_init,N,b_break,max_home,min_home)
end

############################ Helpers ############################

function _generate_initial_solution(N::Int)
    x = zero(Array{Int}(undef,N, N, 2N-2))

    # we just fill the calendar with dummy values
    for k in Base.OneTo(2N-2)
        for i in Base.OneTo(N)
            j = mod(i + k -1, N) +1

            if i != j
                x[i,j,k] = (k % 2 == 0) ? 1 : 0
                x[j,i,k] = 1 - x[i,j,k]
            end
        end
    end

    return x
end

function _generate_initial_solution(N::Int, strength)
    x = zero(Array{Int}(undef,N, N, 2N-2))

    for k in Base.OneTo(2N-2)
        for i in Base.OneTo(N)
            j = mod(i + k -1, N) +1

            if i != j
                x[i,j,k] = (strength[i] > 0.5 && rand() < 0.6) ? 1 : 0
                x[j,i,k] = 1 - x[i,j,k]
            end
        end
    end

    return x
end

function _fix_and_optimize!(model,x,x_init,N,b_break,max_home,min_home)
    
    # We fix every value of the calendar 
    for i in Base.OneTo(N), j in Base.OneTo(N), k in Base.OneTo(2N-2)
        fix(x[i,j,k], x_init[i,j,k]; force=true)
    end

    # initial best objective, slower is better
    best_obj = Inf
    start_time = time()

    # The optimization will run for MAX_TIME second 
    while time() - start_time < MAX_TIME
        
        if rand() < 0.5
            selected_rounds = randperm(2N-2)[1:SUBPB_SIZE]

            for k in selected_rounds
                for i in Base.OneTo(N), j in Base.OneTo(N)
                    unfix(x[i,j,k])
                end
            end
        else
            selected_teams = randperm(N)[1:SUBPB_SIZE]
            for i in selected_teams
                for j in Base.OneTo(N), k in Base.OneTo(2N-2)
                    unfix(x[i,j,k])
                end
            end
        end

        set_time_limit_sec(model, SUBPB_TIMEOUT)

        @objective(model, Min, sum(b_break) + (max_home - min_home))

        optimize!(model)

        if termination_status(model) == OPTIMAL
            new_obj = objective_value(model)

            if new_obj < best_obj
                best_obj = new_obj
                x_init .= floor.(value.(x))
            end
        end

        for i in Base.OneTo(N), j in Base.OneTo(N), k in Base.OneTo(2N-2)
           fix(x[i,j,k], x_init[i,j,k]; force=true)
        end
    end 

    return x_init
end

######## Arrêté ici#####

function _entrywise_prod(A::Array{Number}, B::Array{Number})

    @assert size(A) == size(B) "Arrays should have the same dimensions"
    
    C = similar(A)    

    for i in eachindex(A)
        C[i] = A[i] * B[i]
    end

    return C
end
