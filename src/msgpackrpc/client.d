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
    alias Protocol.ClientTransport!(typeof(this)) Transport;

    Transport _transport;
    IDGenerater _generator;
    Future[size_t] _table;
    Duration _timeout;

  public:
    this(Endpoint endpoint, Duration timeout= dur!"msecs"(1000))
    {
        _transport = new Transport(this, endpoint);
        _timeout = timeout;
    }

    this(string endpoint)
    {
        _transport = new Transport(this, Endpoint(endpoint));
    }

    void close()
    {
        _transport.close();
        _table.destroy();
    }

    T call(T, Args...)(string method, Args args)
    {
        return sendRequest(method, args).get!T;
    }

    Future callAsync(Args...)(string method, Args args)
    {
        return sendRequest(method, args);
    }

    void notify(Args...)(string method, Args args)
    {
        auto packer = packer(Appender!(ubyte[])());

        packer.beginArray(3).pack(MessageType.notify, method).packArray(args);
        _transport.sendMessage(packer.stream.data, false);
    }

    void onResponse(size_t id, ref Value error, ref Value result)
    {
        auto future = id in _table;
        if (future is null)
            return;

        if (error.type == Value.Type.nil) {
            future.result = result;
        } else {
            future.error = error;
        }
        version( noExitEventloop) {} else
        { getEventDriver().exitEventLoop(); }
    }

  private:
    Future sendRequest(Args...)(string method, Args args)
    {
        import std.array;

        auto id = ++_generator;
        auto future = new Future(_timeout);
        auto packer = packer(Appender!(ubyte[])());

        _table[id] = future;
        packer.beginArray(4).pack(MessageType.request, id, method).packArray(args);
        _transport.sendMessage(packer.stream.data);

        return future;
    }
}

alias Client!(msgpackrpc.transport.tcp) TCPClient;

/**
 * Compose the future value
 */
class Future
{
    alias void delegate(Future) Callback;

    this(Duration timeout = dur!"seconds"(5) )
    {
        logTrace("create ManualEvent for Future");
        m_ev = getEventDriver().createManualEvent();
        m_emitCount = m_ev.emitCount;
        m_timeout = timeout;
    }

  private:
    Value _value;
    Callback _callback;
    bool _err;
    ManualEvent m_ev;
    int m_emitCount;
    Duration m_timeout;

  public:
    void join()
    {
        m_ev.wait(m_timeout, m_emitCount);
    }

    @property
    T get(T = Value)()
    {
        join();

        if (_err) {
            RPCException.rethrow(_value);
            return T.init;
        }

        static if (is(T : Value))
        {
            return _value;
        }
        else
        {
            return _value.as!T;
        }
    }

    @property
    {
        ref Value result()
        {
            return _value;
        }

        void result(ref Value res)
        {
            m_ev.emit();
            _value = res;

            if (_callback !is null)
                _callback(this);
        }

        bool errorOccurred()
        {
            return _err;
        }

        ref Value error()
        {
            return _value;
        }

        void error(ref Value err)
        {
            m_ev.emit();
            _err = true;
            _value = err;

            if (_callback !is null)
                _callback(this);
        }

        void callback(Callback callback)
        {
            _callback = callback;
        }
    }
}

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
