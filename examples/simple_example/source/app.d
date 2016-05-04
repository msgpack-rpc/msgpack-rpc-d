import vibe.d;
import msgpackrpc;
import std.stdio;
import std.exception;

import vibe.core.connectionpool : ConnectionPool;

alias RPCPool = ConnectionPool!TCPClient;

static this()
{
    RPCPool rpcPool = new RPCPool({
            return new TCPClient(Endpoint(18800,"127.0.0.1"));
        });

    setTimer(1.seconds, {
            //start a rpc server
            import rpcserver;

            auto rpcapi = new TCPServer!(RPCServer)(new RPCServer);
            rpcapi.listen(Endpoint(18800, "127.0.0.1"));
        });

    setTimer(3.seconds, {
            auto lock = rpcPool.lockConnection();
            TCPClient client = lock;
            auto answer = client.call!string("test");
            writeln("Test 1: " ~ answer);


        });

    setTimer(3.seconds, {
            auto lock = rpcPool.lockConnection();
            TCPClient client = lock;
            auto answer = client.call!string("test2","Marco");
            writeln("Test 2: " ~ answer);
        });

    setTimer(3.seconds, {
            auto lock = rpcPool.lockConnection();
            TCPClient client = lock;
            try {
                client.call!float("fail");
                writeln("Test 3: Something went wrong. This shouldn't execute.");
            } catch(Exception e) {
                writeln("Test 3: Exception occurred as planned. Message: " ~ e.msg);
            }
        });

    setTimer(10.seconds, {
            exitEventLoop();
        });
}