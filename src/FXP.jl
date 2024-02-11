module FXP

import JSON
import Jedis
import Jedis: Client, disconnect!

const sep = "__"

function new_client_copy(client_in::Jedis.Client)
    return Jedis.Client(;
        client_in.host,
        client_in.port,
        client_in.database,
        client_in.password,
        client_in.username)
end

function Base.push!(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; data...)
    raw_data = JSON.sprint(data)
    return raw_push!(client, session_id, service_name, whoami, raw_data)
end

function raw_push!(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol, raw_data::Any)
    @assert whoami ∈ [:provider, :requestor]
    if whoami == :provider
        key = join((session_id, service_name, "pro2req"), sep)
    elseif whoami == :requestor
        key = join((session_id, service_name, "req2pro"), sep)
    end
    return Jedis.lpush(key, raw_data; client)
end

function Base.pop!(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)
    raw_data = raw_pop!(client, session_id, service_name, whoami; timeout, error_on_timeout)
    return Dict(Symbol(k) => v for (k, v) in JSON.parse(raw_data))
end

function raw_pop!(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)
    @assert whoami ∈ [:provider, :requestor]
    if whoami == :provider
        key = join((session_id, service_name, "req2pro"), sep)
    elseif whoami == :requestor
        key = join((session_id, service_name, "pro2req"), sep)
    end
    data = Jedis.brpop(key; timeout, client)
    if isempty(data)
        if error_on_timeout
            error("Wait for `$key` has timed out")
        else
            return nothing
        end
    end
    return data[2]
end

"""
    register_service(client::Jedis.Client, service_name::String, service_function::Function; timeout::Float64=10.0)

`service_function` must have the following call signature:

    service_function(client::Jedis.Client, session_id::String, service_name::String; timeout::Float64=10.0)
"""
function register_service(client::Jedis.Client, service_name::String, service_function::Function; timeout::Float64=10.0)
    subscriber_client = new_client_copy(client)

    @async Jedis.subscribe(service_name; client=subscriber_client) do msg
        session_id = msg[3]
        service_name = msg[2]
        new_client = FXP.new_client_copy(client)
        try
            service_function(new_client, session_id, service_name; timeout)
            return nothing
        catch e
            println(e)
            rethrow(e)
        finally
            FXP.disconnect!(new_client)
        end
    end

    Jedis.wait_until_subscribed(subscriber_client)
    return subscriber_client
end

function has_service_provider(client::Jedis.Client, service_name::String)
    subs = Jedis.execute("PUBSUB CHANNELS $(service_name)", client)
    @assert length(subs) <= 1 "Too many service providers: $(subs)"
    return length(subs) == 1
end

function negotiate_service(client::Jedis.Client, session_id::String, service_name::String)
    key = join((session_id, service_name, "pro2req"), sep)
    Jedis.del(key; client)
    key = join((session_id, service_name, "req2pro"), sep)
    Jedis.del(key; client)
    return Jedis.publish(service_name, session_id; client)
end

"""
    JSON.sprint(data, args...; kw...)

Return JSON represntation of data
"""
function JSON.sprint(data, args...; kw...)
    buf = IOBuffer()
    JSON.print(buf, data, args...; kw...)
    return String(take!(buf))
end

end # module FXP
