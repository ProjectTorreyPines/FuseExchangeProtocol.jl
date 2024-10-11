clear all
close all
clc
import redis.clients.jedis.Jedis;
filePath = '/home/clarkm/.redis/irad_redis.config';
fileContent = fileread(filePath); % Read the file
lines = strsplit(fileContent, '\n'); % Split by line
redisHost = strtrim(lines{1}); % Server name
redisPort = str2double(strtrim(lines{2})); % Port number
redisKey = strtrim(lines{3}); % Password/key
jedis = Jedis(redisHost, redisPort);  % Default Redis port is 6379, 6380 for writing
jedis.auth(redisKey);

% Test the connection
if jedis.isConnected()
    disp('Connected to Redis server');
else
    disp('Failed to connect to Redis server');
end