// Written in the D programming language.

/**
 * MessagePack RPC Client
 */
module msgpackrpc.client;

public import msgpackrpc.common;
import msgpackrpc.transport.tcp;

import msgpack;
import vibe.vibe;

import std.array;
import std.traits;


/**
 * MessagePack RPC Client
 */
class Client(alias Protocol)
{
  private:
    alias Protocol.ClientTransport Transport;

    Transport _transport;
    IDGenerater _generator;

  public:
    this(Endpoint endpoint, Duration timeout = Duration.max)
    {
        _transport = new Transport(endpoint, timeout);
    }

    void close()
    {
        _transport.close();
    }

    T call(T, Args...)(string method, Args args)
    {
        Request request;
        request.id = ++_generator;
        request.method = method;
        request.parameters = Value[](args.length);

        foreach(size_t i, argument; args)
            request[i] = Value(argument);

        auto response = _transport.send(request);

        if (response.error)
            RPCException.rethrow(response.error);
        else
            return response.result.as!T;
    }

    void notify(Args...)(string method, Args args)
    {
        auto packer = packer(Appender!(ubyte[])());

        packer.beginArray(3).pack(MessageType.notify, method).packArray(args);
        _transport.sendMessage(packer.stream.data, false);
    }
}

alias Client!(msgpackrpc.transport.tcp) TCPClient;

private:

// TODO: Make shared
struct IDGenerater
{
  private:
    size_t _id;

  public:
    size_t opUnary(string op)() if (op == "++" || op == "--")
    {
        static if (op == "++")
        {
            return ++_id;
        }
        else
        {
            return ++_id;
        }
    }
}
