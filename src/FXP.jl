module FXP

import JSON
import Jedis

function Base.push!(client::Jedis.Client, id_service_name::String; data...)
    return Jedis.lpush(id_service_name, JSON.sprint(data); client)
end

function Base.pop!(client::Jedis.Client, id_service_name::String; timeout::Float64, error_on_timeout::Bool=true)
    data = Jedis.brpop(id_service_name; timeout, client)
    if isempty(data)
        if error_on_timeout
            error("Wait for data from `$id_service_name` has timed out")
        else
            return nothing
        end
    end
    return Dict(Symbol(k) => v for (k, v) in JSON.parse(data[2]))
end

function register_service(service_name::String, service_function::Function; client::Jedis.Client)
    @async Jedis.subscribe(service_name; client) do msg
        return service_function(msg[3])
    end
    Jedis.wait_until_subscribed(client)
end

function has_service_provider(service_name::String; client::Jedis.Client)
    subs = Jedis.execute("PUBSUB CHANNELS $(service_name)", client)
    @assert length(subs) <= 1 "Too many service providers: $(subs)"
    return length(subs) == 1
end

function negotiate_service(session_id::String, service_name::String; client::Jedis.Client)
    id_service_name = "$(session_id)__$(service_name)"
    return Jedis.publish(service_name, id_service_name; client)
end

end # module FXP
