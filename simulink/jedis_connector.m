function jedis_connector(block)
    persistent jedis;
    setup(block);

    %useful references
    %edit('msfuntmpl.m');
    %edit('msfuntmpl_basic.m');

function setup(block)
    %Block setup
    block.NumInputPorts = 1;
    block.NumOutputPorts = 1;
    %block.SetPreCompInpPortInfoToDynamic;
    %block.SetPreCompOutPortInfoToDynamic;

    %Input setup
    block.InputPort(1).Dimensions  = 13;
    %block.InputPort(1).DatatypeID  = 0;  % double
    %block.InputPort(1).Complexity  = 'Real';
    block.InputPort(1).DirectFeedthrough = true;

    %S-function essentials/required components
    block.SampleTimes = [0 0];

    %Block methods
    block.RegBlockMethod('Start', @Start);
    block.RegBlockMethod('Outputs', @InvokeModel);
    %block.RegBlockMethod('Update', @Push);
    block.RegBlockMethod('Terminate', @Terminate);
end

function Start(block)
    import redis.clients.jedis.Jedis
    if ispc
        redisConfig = fullfile(getenv('USERPROFILE'), ".redis/irad_redis.config");
    else
        redisConfig = fullfile(getenv('HOME'), ".redis/irad_redis.config");
    end
    [redisHost, redisPort, redisKey] = readConfigFile(redisConfig);
    jedis = Jedis(redisHost, redisPort);  % Default Redis port is 6379, 6380 for writing
    jedis.auth(redisKey);
    disp(['Hello, ' char(jedis.get('clarkm_hello'))]);
    %jedis.lpush("debug", zeros(13,1));

end

% function Push(block)
%     channelname = "rdm__state_space_model__req2pro";
%     %channelname = "debug";
%     name = 'u';
%     data = block.InputPort(1).Data;
%     msg_out = jsonencode(struct(name, data)); %can this somehow reuse the fxp_lite class?
%     disp("Writing %s",msg_out)
%     jedis.lpush(channelname, msg_out);
% end

    function InvokeModel(block)
    rec_channel = "rdm__state_space_model__pro2req";
    send_channel = "rdm__state_space_model__req2pro";
    %channelname = "debug";
    timeout = 30;

    send_name = 'u';
    send_data = block.InputPort(1).Data;
    msg_out = jsonencode(struct(send_name, send_data));
    disp(["Writin:g " msg_out])
    jedis.lpush(send_channel, msg_out);
    %data_name = 'y';
    msg_in = jedis.brpop(timeout,rec_channel); %Reads from model
    raw_json = char(msg_in.getValue());
    %disp(['Value from Redis: ' raw_json]) %lots of logic to be automated/ripped from lite
    json_in = jsondecode(raw_json);
    disp(['Time from Redis: ' num2str(json_in.t)])
    block.OutputPort(1).Data = json_in.y;
end

function Terminate(block)
    jedis.close();
end

end

function [redisHost, redisPort, redisKey] = readConfigFile(filePath)
    fileContent = fileread(filePath); % Read the file    
    lines = strsplit(fileContent, '\n'); % Split by line
    redisHost = strtrim(lines{1}); % Server name
    redisPort = str2double(strtrim(lines{2})); % Port number
    redisKey = strtrim(lines{3}); % Password/key
 end
