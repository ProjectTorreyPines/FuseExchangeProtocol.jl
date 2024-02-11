import FXP

REDIS_HOST = "localhost"
REDIS_PORT = 55000
REDIS_PASSWORD = "redispw"

####################
# service provider #
####################

# service function
function service_echo(client::FXP.Client, session_id::String, service_name::String; timeout::Float64)
    service_client = FXP.new_client_copy(client)

    while true
        # pop inputs
        inputs = pop!(service_client, session_id, service_name, :provider; timeout, error_on_timeout=false)
        if inputs === nothing
            println("DONE: $(session_id) $(service_name)")
            break
        end
        inputs = NamedTuple(inputs)

        # do something
        outputs = inputs

        # push output
        push!(service_client, session_id, service_name, :provider; outputs...)
    end

    return FXP.disconnect!(service_client)
end

# advertise
provider = FXP.Client(; host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD);
FXP.register_service(provider, "echo", service_echo; timeout=10.0)

#####################
# service requestor #
#####################
session_id = "my_own_session"
service_name = "echo"
payload_in = Dict(:string => "hello world", :bool => true, :int => 1, :float => 1.0, :array => ["hello", false, 0, 0.0])
payload_in[:dict] = deepcopy(payload_in)
payload_in[:array_struc] = [deepcopy(payload_in), deepcopy(payload_in)]

requestor = FXP.Client(; host=REDIS_HOST, port=REDIS_PORT, password=REDIS_PASSWORD);
FXP.has_service_provider(requestor, service_name)
FXP.negotiate_service(requestor, session_id, service_name)
FXP.push!(requestor, session_id, service_name, :requestor; payload_in...)
payload_out = FXP.pop!(requestor, session_id, service_name, :requestor; timeout=10.0)

@show payload_out