import std.stdio;
import std.datetime;
import vibe.d;

import msgpackrpc;

enum count = 100;
enum innerCount = 100;
void main()
{
	auto client = new TCPClient(Endpoint(18800, "127.0.0.1"));

	client.notify("length", 30);
	client.notify("delay", 20.msecs);

	foreach(i; 0..count)
		runTask((int i){
				auto client = new TCPClient(Endpoint(18800, "127.0.0.1"), 300.msecs);
				foreach(j; 0..innerCount)
				{
					auto data = client.call!string("getData");
					logInfo("i = %3d, j = %3d, received %s", i, j, data.length);
				}
				client.close;
			}.toDelegate, i);

	runTask({
		sleep(4.seconds);
		exitEventLoop;
		});

	runEventLoop();
}
