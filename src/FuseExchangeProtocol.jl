module FuseExchangeProtocol

import JSON
import Jedis
import Jedis: Client, disconnect!

const sep = "__"  # Defines a constant separator used to construct Redis keys

"""
    new_client_copy(client_in::Jedis.Client)

Creates a copy of a Jedis client with the same connection parameters.
"""
function new_client_copy(client_in::Jedis.Client)
    return Jedis.Client(;
        client_in.host,
        client_in.port,
        client_in.database,
        client_in.password,
        client_in.username)
end

export new_client_copy

"""
    json_push(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; data...)

Pushes serialized JSON data into a Redis list, using a key derived from session_id, service_name, and whoami
"""
function json_push(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; data...)
    raw_data = json_sprint(data)
    return raw_push(client, session_id, service_name, whoami, raw_data)
end

export json_push

"""
    json_pop(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)

Pops and deserializes JSON data from a Redis list, using a key derived from session_id, service_name, and whoami
"""
function json_pop(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)
    raw_data = raw_pop(client, session_id, service_name, whoami; timeout, error_on_timeout)
    if raw_data === nothing
        return nothing
    end
    return Dict(Symbol(k) => v for (k, v) in JSON.parse(raw_data))
end

export json_pop

"""
    raw_push(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol, raw_data::Any)

Pushes raw data into a Redis list, key determined by session_id, service_name, and whoami
"""
function raw_push(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol, raw_data::Any)
    if whoami == :provider
        key = join((session_id, service_name, "pro2req"), sep)
    elseif whoami == :requestor
        key = join((session_id, service_name, "req2pro"), sep)
    else
        @assert whoami ∈ [:provider, :requestor] "Unrecognized whoami=$(repr(whoami)) Must be ither :provider or :requestor"
    end
    return Jedis.lpush(key, raw_data; client)
end

export raw_push

"""
    raw_pop(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)

Pops raw data from a Redis list, key determined by session_id, service_name, and whoami
"""
function raw_pop(client::Jedis.Client, session_id::String, service_name::String, whoami::Symbol; timeout::Float64, error_on_timeout::Bool=true)
    if whoami == :provider
        key = join((session_id, service_name, "req2pro"), sep)
    elseif whoami == :requestor
        key = join((session_id, service_name, "pro2req"), sep)
    else
        @assert whoami ∈ [:provider, :requestor] "Unrecognized whoami=$(repr(whoami)) Must be ither :provider or :requestor"
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

export raw_pop

"""
    register_service(client::Jedis.Client, service_name::String, service_function::Function; timeout::Float64=10.0)

Registers a service by subscribing to a Redis channel and invoking the service_function when a message is received

The service_function must have the following call signature:

    service_function(client::Jedis.Client, session_id::String, service_name::String; timeout::Float64)
"""
function register_service(client::Jedis.Client, service_name::String, service_function::Function; timeout::Float64=10.0)
    
    Jedis.unsubscribe(service_name; client)
    
    subscriber_client = new_client_copy(client)

    @async Jedis.subscribe(service_name; client=subscriber_client) do msg
        session_id = msg[3]
        service_name = msg[2]
        new_client = new_client_copy(client)
        try
            service_function(new_client, session_id, service_name; timeout)
            return nothing
        catch e
            println(e)
            rethrow(e)
        finally
            disconnect!(new_client)
        end
    end

    @info "Register service `$(service_name)` (subscribe to Redis channel `$(service_name)`)"
    Jedis.wait_until_subscribed(subscriber_client)
    return subscriber_client
end

export register_service

"""
    has_service_provider(client::Jedis.Client, service_name::String)

Checks if there is a provider for a given service
"""
function has_service_provider(client::Jedis.Client, service_name::String)
    subs = Jedis.execute("PUBSUB CHANNELS $(service_name)", client)
    @assert length(subs) <= 1 "Too many service providers: $(subs)"
    return length(subs) == 1
end

export has_service_provider

"""
    negotiate_service(client::Jedis.Client, session_id::String, service_name::String)

Initializes service negotiation by cleaning up previous keys and publishing a request on a Redis channel
"""
function negotiate_service(client::Jedis.Client, session_id::String, service_name::String)
    @info "Negotiating FXP service `$(service_name)` with session ID `$(session_id)`"
    key = join((session_id, service_name, "pro2req"), sep)
    Jedis.del(key; client)
    key = join((session_id, service_name, "req2pro"), sep)
    Jedis.del(key; client)
    return Jedis.publish(service_name, session_id; client)
end

export negotiate_service

"""
    json_sprint(data, args...; kw...)

Serializes data into a JSON string
"""
function json_sprint(data, args...; kw...)
    buf = IOBuffer()
    JSON.print(buf, data, args...; kw...)
    return String(take!(buf))
end

export json_sprint

const document = Dict()
document[Symbol(@__MODULE__)] = [name for name in Base.names(@__MODULE__; all=false, imported=false) if name != Symbol(@__MODULE__)]

end # module FuseExchangeProtocol
