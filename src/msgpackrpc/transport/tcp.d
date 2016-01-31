// Written in the D programming language.

/**
 * MessagePack RPC TCP transport layer
 */
module msgpackrpc.transport.tcp;

import msgpackrpc.common;
import msgpackrpc.server;

import msgpack;
import vibe.core.net;
import vibe.core.driver;

import std.conv;
import std.datetime;
import std.exception;

class TimeoutException: RPCException
{
    @safe pure nothrow this(string msg)
    {
        super(msg);
    }
}

class MsgpackSocket
{
private:
    TCPConnection _connection;
    StreamingUnpacker _unpacker;
    Duration _timeout;
    bool     _closeOnTimeout;

  public:
    this(TCPConnection connection)
    {
        _connection = connection;
        _unpacker = StreamingUnpacker([], 2048);
        _timeout = 3000.seconds;
        _closeOnTimeout = false;
    }

    this(TCPConnection connection, Duration timeout)
    {
        _connection = connection;
        _unpacker = StreamingUnpacker([], 2048);
        _timeout = timeout;
        _closeOnTimeout = true;
    }

    void close()
    {
        _connection.close();
    }

    void sendData(const ubyte[] data)
    {
        OutputStream output = _connection;
        output.write(data);
        output.flush();
    }

    auto readMessages()
    {
        struct Reader
        {
        private:
            MsgpackSocket _socket;

            size_t getBufferSizeForStream(InputStream input)
            {
                //Cast the leastSize down if we are on a non-64bit platform
                auto size = cast(size_t) input.leastSize;

                //Overflow protection: If ulong is casted to a smaller size_t
                //and the result is zero, read the maximum possible amount of bytes
                static if (size_t.sizeof < typeof(input.leastSize).sizeof)
                    if (!size)
                        size = size_t.max;

                return size;
            }


        public:
            this(MsgpackSocket socket)
            {
                _socket = socket;
            }

            //TODO: Can this be broken up into smaller functions?
            int opApply(scope int delegate(ref Message) handleMessage)
            {
                int result;
                auto timeoutLeft = _socket._timeout;
                auto startTime = Clock.currTime();
                InputStream input = _socket._connection;

                //Preallocate a buffer of 1KB
                ubyte[] buffer = new ubyte[](1024);

                //TODO: Refactor the loop and if conditions to be nicer.
                //      This should be much easier once waitForData() behaves
                //      the same on all backends.
                while(_socket._connection.connected || !_socket._connection.empty)
                {
                    if (!_socket._connection.dataAvailableForRead)
                        if (timeoutLeft <= 0.msecs || !_socket._connection.waitForData(timeoutLeft))
                            if (_socket._closeOnTimeout)
                                throw new TimeoutException("");

                    auto size = getBufferSizeForStream(input);
                    //if (size < 1)
                      //  return result;

                    //Reallocate a bigger buffer if necessary
                    if (buffer.length < size)
                        buffer = new ubyte[](size);

                    //Read and process the available data
                    _socket._connection.read(buffer[0..size]);

                    //Unpack the messages received so far and handle them individually
                    _socket._unpacker.feed(buffer[0..size]);
                    while(_socket._unpacker.execute())
                    {
                        auto message = _socket._unpacker.purge();
                        result = handleMessage(message);
                        if (result)
                            return result;
                    }
                           
                    //Adjust the timeout ticker
                    if (_socket._closeOnTimeout)
                        timeoutLeft -= (Clock.currTime() - startTime);
                }

                return result;
            }
        }
        return Reader(this);
    }
}

final class ClientTransport
{
  private:
    Endpoint _endpoint;
    MsgpackSocket _socket;

  public:
    this(Endpoint endpoint)
    {
        _endpoint = endpoint;
        _socket = new MsgpackSocket(connectTCP(_endpoint.address, _endpoint.port));
    }

    this(Endpoint endpoint, Duration timeout)
    {
        _endpoint = endpoint;
        _socket = new MsgpackSocket(connectTCP(_endpoint.address, _endpoint.port), timeout);
    }

    void sendMessage(const ubyte[] data, scope void delegate(ref Response) handleResponse = null)
    {
        _socket.sendData(data);
        if (handleResponse !is null)
        {
            foreach(message; _socket.readMessages())
            {
                //TODO: Factor out the message parsing and implement proper async.
                //      Vibe.d's tasks and TaskCondition should be enough to do this.
                auto response = message.parseResponse();
                handleResponse(response);
                return;
            }

            //This should never be reached.
            throw new Error("No response received");
        }
    }

    void close()
    {
        _socket.close();
    }
}

final class ServerTransport(Server)
{
  private:
    Endpoint _endpoint;
    Duration _timeout;
    bool     _useTimeout = false;

  public:
    this(Endpoint endpoint)
    {
        _endpoint = endpoint;
    }

    this(Endpoint endpoint, Duration timeout)
    {
        _endpoint = endpoint;
        _timeout = timeout;
        _useTimeout = true;
    }

    void listen(Server server)
    {
        auto callback = (TCPConnection connection) {
            try
            {
                auto socket = createSocket(connection);
                foreach(message; socket.readMessages())
                    handleMessage(server, socket, message);
            }
            catch (TimeoutException e)
            {
                connection.close();
            }
        };
        listenTCP(_endpoint.port, callback, _endpoint.address);
    }

    void close()
    {
    }

private:
    MsgpackSocket createSocket(TCPConnection connection)
    {
        if (_useTimeout)
            return new MsgpackSocket(connection,_timeout);
        else
            return new MsgpackSocket(connection);
    }

    void handleMessage(Server server, MsgpackSocket socket, ref Message message)
    {
        auto messageType = message.parseType();
        switch (messageType)
        {
        case MessageType.request:
            {
                auto request = message.parseRequest();
                auto response = server.onRequest(request);
                socket.sendData(response.serialize());
            }
            break;

        case MessageType.notify:
            {
                auto notify = message.parseNotification();
                server.onNotify(notify);
            }
            break;

        default:
            throw new RPCException("Unexpected message type: " ~ messageType.to!string);
        }
    }
}
