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
    this(Endpoint endpoint)
    {
        _transport = new Transport(endpoint);
    }

    this(Endpoint endpoint, Duration timeout)
    {
        _transport = new Transport(endpoint, timeout);
    }

    this(string endpoint)
    {
        this(Endpoint(endpoint));
    }

    void close()
    {
        _transport.close();
    }

    T call(T, Args...)(string method, Args args)
    {
        auto id = ++_generator;
        auto packer = packer(Appender!(ubyte[])());       
        packer.beginArray(4).pack(MessageType.request, id, method).packArray(args);

        Value error, result;
        _transport.sendMessage(packer.stream.data, (ref Response response) {
                if (response.error.type != Value.Type.nil)
                    error = response.error;
                else
                    result = response.result;
            });

        if (error.type != Value.Type.nil)
            RPCException.rethrow(error);

        return result.as!T;
    }

    void notify(Args...)(string method, Args args)
    {
        auto packer = packer(Appender!(ubyte[])());
        packer.beginArray(3).pack(MessageType.notify, method).packArray(args);
        _transport.sendMessage(packer.stream.data);
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
