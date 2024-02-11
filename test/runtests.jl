import Pkg
Pkg.activate(@__DIR__)
import FXP
import BenchmarkTools

REDIS_HOST = "localhost"
REDIS_PORT = 55000
REDIS_PASSWORD = "redispw"

####################
# service provider #
####################
provider = FXP.Client(; host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD);

# service function
function service_echo(client::FXP.Client, session_id::String, service_name::String; timeout::Float64)

    while true
        # pop inputs
        inputs = FXP.pop!(client, session_id, service_name, :provider; timeout, error_on_timeout=false)
        if inputs === nothing
            println("DONE: $(session_id) $(service_name)")
            break
        end
        inputs = NamedTuple(inputs)

        # do something
        outputs = inputs

        # push output
        FXP.push!(client, session_id, service_name, :provider; outputs...)
    end

end

# service function
function service_raw_echo(client::FXP.Client, session_id::String, service_name::String; timeout::Float64)

    while true
        # pop inputs
        raw_inputs = FXP.raw_pop!(client, session_id, service_name, :provider; timeout, error_on_timeout=false)
        if raw_inputs === nothing
            println("DONE: $(session_id) $(service_name)")
            break
        end

        # do something
        raw_outputs = raw_inputs

        # push output
        FXP.raw_push!(client, session_id, service_name, :provider, raw_outputs)
    end

end

# advertise services
FXP.register_service(provider, "echo", service_echo; timeout=10.0)
FXP.register_service(provider, "raw_echo", service_raw_echo; timeout=10.0)

#####################
# service requestor #
#####################
requestor = FXP.Client(; host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD);

session_id = "my_own_session"

# request echo service
service_name = "echo"
@show service_name
payload_in = Dict(:string => "hello world", :bool => true, :int => 1, :float => 1.0, :array => ["hello", false, 0, 0.0])
payload_in[:dict] = deepcopy(payload_in)
payload_in[:array_struc] = [deepcopy(payload_in), deepcopy(payload_in)]
FXP.has_service_provider(requestor, service_name)
FXP.negotiate_service(requestor, session_id, service_name)
display(BenchmarkTools.@benchmark begin # runs it 10k times
    FXP.push!(requestor, session_id, service_name, :requestor; payload_in...)
    payload_out = FXP.pop!(requestor, session_id, service_name, :requestor; timeout=10.0)
end)

# request raw_echo service
service_name = "raw_echo"
@show service_name
raw_in = "hello fxp"
FXP.has_service_provider(requestor, service_name)
FXP.negotiate_service(requestor, session_id, service_name)
display(BenchmarkTools.@benchmark begin # runs it 10k times
    FXP.raw_push!(requestor, session_id, service_name, :requestor, raw_in)
    raw_out = FXP.raw_pop!(requestor, session_id, service_name, :requestor; timeout=10.0)
end)

println()
