// Written in the D programming language.

/**
 * MessagePack RPC common symbols
 */
module msgpackrpc.common;

import msgpack;
import vibe.vibe;

import std.conv;
import std.exception;


/**
 * See: http://wiki.msgpack.org/display/MSGPACK/RPC+specification#RPCspecification-MessagePackRPCProtocolspecification
 */
enum MessageType
{
    request = 0,
    response = 1,
    notify = 2
}

alias Message = Unpacked;

//Extract the message type from an unpacked MSGPACK value
MessageType parseType(ref Message message)
{
    immutable type = message[0].as!uint;
    switch (type) {
    case MessageType.request:
    case MessageType.response:
    case MessageType.notify:
        return type.to!MessageType;
    default:
        throw new RPCException("Unknown message type: type = " ~ to!string(type));
    }
}

struct Request
{
    size_t id;
    string method;
    Value[] parameters;

    this(ref Message message)
    {
        MessageType t = message.parseType();
        enforce(t == MessageType.request, "A parsed request was didn't contain the expected message type.");
        enforce(message.length == 4,  "A parsed request was didn't contain the expected number of values.");

        id = message[1].as!size_t;
        method = message[2].as!string;
        parameters = message[3].via.array;
    }

    auto serialize()
    {
        auto packer = packer(Appender!(ubyte[])());
        packer.beginArray(4)
              .pack(MessageType.request, id, method)
              .packArray(parameters);
        return packer.stream.data;
    }
}
Request parseRequest(ref Message message) { return Request(message); }

struct Response
{
    size_t id;
    Value error;
    Value result;

    this(ref Message message)
    {
        MessageType t = message.parseType();
        size_t l = message.length;
        enforce(t == MessageType.response, "A parsed response was didn't contain the expected message type.");
        enforce(message.length == 4, "A parsed response was didn't contain the expected number of values.");
        id = message[1].as!size_t;
        error = message[2];
        result = message[3];
    }

    auto serialize()
    {
        auto packer = packer(Appender!(ubyte[])());
        packer.beginArray(4)
              .pack(MessageType.response, id, error, result);
        return packer.stream.data;
    }
}
Response parseResponse(ref Message message) { return Response(message); }

struct Notification
{
    string method;
    Value[] parameters;

    this(ref Message message)
    {
        MessageType t = message.parseType();
        enforce(t == MessageType.notify, "A parsed notification was didn't contain the expected message type.");
        enforce(message.length == 3,  "A parsed notification was didn't contain the expected number of values.");
        method = message[1].as!string;
        parameters = message[2].via.array;
    }

    auto serialize()
    {
        auto packer = packer(Appender!(ubyte[])());
        packer.beginArray(3)
              .pack(MessageType.notify, method)
              .packArray(parameters);
        return packer.stream.data;
    }
}
Notification parseNotification(ref Message message) { return Notification(message); }




struct Endpoint
{
    ushort port;
    string address;

    this(ushort port, string address)
    {
        this.port = port;
        this.address = address;
    }

    this(string connectionString)
    {
        import std.array;
        auto splitted = connectionString.split(":");
        this.address = splitted[0];
        import std.conv;
        this.port = splitted[1].to!ushort;
    }

}

unittest
{
    auto e = Endpoint("127.0.0.1:18800");
    assert(e.port = 18800);
    assert(e.address = "127.0.0.1");
}
/**
 * Base exception for RPC error hierarchy
 */
class RPCException : Exception
{
    enum Code = ".RPCError";

    static void rethrow(ref Value error)
    {
        if (error.type == Value.type.array) {
            auto errCode = error.via.array[0].as!string;
            auto errMsg = error.via.array[1].as!string;

            switch (errCode) {
            case RPCException.Code:
                throw new RPCException(errMsg);
            case TimeoutException.Code:
                throw new TimeoutException(errMsg);
            case TransportException.Code:
                throw new TransportException(errMsg);
            case CallException.Code:
                throw new CallException(errMsg);
            case NoMethodException.Code:
                throw new NoMethodException(errMsg);
            case ArgumentException.Code:
                throw new ArgumentException(errMsg);
            default:
                throw new Exception("Unknown code: code = " ~ errCode);
            }
        } else {
            throw new RPCException(error.as!string);
        }
    }

    mixin ExceptionConstructor;
}

///
class TimeoutException : RPCException
{
    enum Code = ".TimeoutError";
    mixin ExceptionConstructor;
}

///
class TransportException : RPCException
{
    enum Code = ".TransportError";
    mixin ExceptionConstructor;
}

///
class CallException : RPCException
{
    enum Code = ".NoMethodError";
    mixin ExceptionConstructor;
}

///
class NoMethodException : CallException
{
    enum Code = ".CallError.NoMethodError";
    mixin ExceptionConstructor;
}

///
class ArgumentException : CallException
{
    enum Code = ".CallError.ArgumentError";
    mixin ExceptionConstructor;
}

private:

mixin template ExceptionConstructor()
{
    @safe pure nothrow this(string msg)
    {
        super(msg);
    }

    void toMsgpack(Packer)(ref Packer packer, bool withFieldName = false) const
    {
        packer.beginArray(2);
        packer.pack(Code);
        packer.pack(msg);
    }
}

unittest
{
    import std.typetuple;

    foreach (E; TypeTuple!(RPCException, TimeoutException, TransportException, CallException, NoMethodException, ArgumentException)) {
        auto e = new E("hoge");
        string[] codeAndMsg;
        unpack(pack(e), codeAndMsg);
        assert(codeAndMsg[0] == E.Code);
    }
}
