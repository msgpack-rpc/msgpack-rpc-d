module rpcserver;

import vibe.core.core;
import std.datetime;
import std.conv;

class RPCServer
{
    string enhance(string input)
    {
        return "8===========" ~ input;
    }

    string sleep(long wtime)
    {
      setTimer(dur!"msecs"(wtime), {}).wait();
      return "ok";
    }
}
