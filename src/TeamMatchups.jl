################################### Finding the best team matchups #############################

######### Way 1: Shuo Chen, Thorsten Joachims's blade-chest model ############

function get_probability(pbweigth, pcweigth, gbweigth, gcweigth, pa, pb, game_data)

    ac = _entrywise_prod(tanh.(gcweigth*game_data), tanh.(pcweigth*pa))
    bc = _entrywise_prod(tanh.(gcweigth*game_data), tanh.(pcweigth*pb))
    ab = _entrywise_prod(tanh.(gbweigth*game_data), tanh.(pbweigth*pa))
    bb = _entrywise_prod(tanh.(gbweigth*game_data), tanh.(pbweigth*pb))

    v = dot(ab,bc) - dot(ac,bb)
end

############################ Helpers ############################

function _entrywise_prod(A::Array{Number}, B::Array{Number})

    @assert size(A) == size(B) "Arrays should have the same dimensions"
    
    C = similar(A)    

    for i in eachindex(A)
        C[i] = A[i] * B[i]
    end

    return C
end