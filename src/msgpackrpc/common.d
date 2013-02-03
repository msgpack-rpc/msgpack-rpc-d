// Written in the D programming language.

/**
 * MessagePack RPC common symbols
 */
module msgpackrpc.common;

import msgpack;

import std.typecons;


/**
 * See: http://wiki.msgpack.org/display/MSGPACK/RPC+specification#RPCspecification-MessagePackRPCProtocolspecification
 */
enum MessageType
{
    request = 0,
    response = 1,
    notify = 2
}

alias Tuple!(ushort, "port", string, "address") Endpoint;

/**
 * Base exception for RPC error hierarchy
 */
class RPCError : Exception
{
    enum Code = ".RPCError";

    static void rethrow(ref Value error)
    {
        if (error.type == Value.type.array) {
            auto errCode = error.via.array[0].as!string;
            auto errMsg = error.via.array[1].as!string;

            switch (errCode) {
            case RPCError.Code:
                throw new RPCError(errMsg);
            case TimeoutError.Code:
                throw new TimeoutError(errMsg);
            case TransportError.Code:
                throw new TransportError(errMsg);
            case CallError.Code:
                throw new CallError(errMsg);
            case NoMethodError.Code:
                throw new NoMethodError(errMsg);
            case ArgumentError.Code:
                throw new ArgumentError(errMsg);
            default:
                throw new Exception("Unknown code: code = " ~ errCode);
            }
        } else {
            throw new RPCError(error.as!string);
        }
    }

    mixin ErrorConstructor;
}

///
class TimeoutError : RPCError
{
    enum Code = ".TimeoutError";
    mixin ErrorConstructor;
}

///
class TransportError : RPCError
{
    enum Code = ".TransportError";
    mixin ErrorConstructor;
}

///
class CallError : RPCError
{
    enum Code = ".NoMethodError";
    mixin ErrorConstructor;
}

///
class NoMethodError : CallError
{
    enum Code = ".CallError.NoMethodError";
    mixin ErrorConstructor;
}

///
class ArgumentError : CallError
{
    enum Code = ".CallError.ArgumentError";
    mixin ErrorConstructor;
}

private:

mixin template ErrorConstructor()
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

    foreach (Error; TypeTuple!(RPCError, TimeoutError, TransportError, CallError, NoMethodError, ArgumentError)) {
        auto e = new Error("hoge");
        string[] codeAndMsg;
        unpack(pack(e), codeAndMsg);
        assert(codeAndMsg[0] == Error.Code);
    }
}
