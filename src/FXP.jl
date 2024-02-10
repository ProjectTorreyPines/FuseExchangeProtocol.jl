module FXP

import JSON
import Jedis
import Jedis: Client, disconnect!

const sep = "__"

function Base.push!(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; data...)
    @assert whoami ∈ [:service, :client]
    if whoami == :service
        key = join((session_id, service_name, "srv2cli"), sep)
    elseif whoami == :client
        key = join((session_id, service_name, "cli2srv"), sep)
    end
    return Jedis.lpush(key, JSON.sprint(data); client)
end

function Base.pop!(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)
    @assert whoami ∈ [:service, :client]
    if whoami == :service
        key = join((session_id, service_name, "cli2srv"), sep)
    elseif whoami == :client
        key = join((session_id, service_name, "srv2cli"), sep)
    end
    data = Jedis.brpop(key; timeout, client)
    if isempty(data)
        if error_on_timeout
            error("Wait for `$key` has timed out")
        else
            return nothing
        end
    end
    return Dict(Symbol(k) => v for (k, v) in JSON.parse(data[2]))
end

function register_service(client::Jedis.Client, service_name::String, service_function::Function)
    @async Jedis.subscribe(service_name; client) do msg
        session_id = msg[3]
        service_name = msg[2]
        return service_function(session_id, service_name)
    end
    return Jedis.wait_until_subscribed(client)
end

function has_service_provider(client::Jedis.Client, service_name::String)
    subs = Jedis.execute("PUBSUB CHANNELS $(service_name)", client)
    @assert length(subs) <= 1 "Too many service providers: $(subs)"
    return length(subs) == 1
end

function negotiate_service(client::Jedis.Client, session_id::String, service_name::String)
    key = join((session_id, service_name, "srv2cli"), sep)
    Jedis.del(key; client)
    key = join((session_id, service_name, "cli2srv"), sep)
    Jedis.del(key; client)
    return Jedis.publish(service_name, session_id; client)
end

end # module FXP
