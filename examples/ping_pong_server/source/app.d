import std.stdio;
import std.datetime;
import vibe.d;

import msgpackrpc;

class FooServer
{

	uint _length = 10;
	Duration _delay = 10.msecs;

	void length(uint length)
	{
		logInfo("length = %s", length);
		_length = length;
	}

	void delay(Duration delay)
	{
		logInfo("delay = %s", delay);
		_delay = delay;
	}

	string getData()
	{
		import std.algorithm, std.range;
		sleep(_delay);
		return 'a'.repeat(_length).array;
	}
}

shared static this()
{
	auto server = new TCPServer!(FooServer)(new FooServer);
	server.listen(Endpoint(18800, "127.0.0.1"));
}
