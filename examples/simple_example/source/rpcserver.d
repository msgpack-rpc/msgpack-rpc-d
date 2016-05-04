module rpcserver;

import std.math;
import vibe.d;

class RPCServer
{
    string test()
    {
        return "Das Pferd frisst keinen Gurkensalat.";
    }

    string test2(string input)
    {
        if (input == "Marco")
            return "Polo!";
        else
            return "Meh";
    }

    float fail()
    {
        throw new Exception("This is an exception.");
    }

//    int findTheAnswerToEverything()
//    {
//        //Compute for half a million years
//        sleep(Duration.max);
//        return 42;
//    }
}
