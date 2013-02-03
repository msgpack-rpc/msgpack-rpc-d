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
    static immutable code = ".RPCError";

    mixin ErrorConstructor;
    mixin MessagePackable!("msg");
}

///
class TimeoutError : RPCError
{
    static immutable code = ".TimeoutError";
    mixin ErrorConstructor;
}

///
class TransportError : RPCError
{
    static immutable code = ".TransportError";
    mixin ErrorConstructor;
}

///
class CallError : RPCError
{
    static immutable code = ".NoMethodError";
    mixin ErrorConstructor;
}

///
class NoMethodError : CallError
{
    static immutable code = ".CallError.NoMethodError";
    mixin ErrorConstructor;
}

///
class ArgumentError : CallError
{
    static immutable code = ".CallError.ArgumentError";
    mixin ErrorConstructor;
}

private:

mixin template ErrorConstructor()
{
    @safe pure nothrow this(string msg)
    {
        super(msg);
    }
}
