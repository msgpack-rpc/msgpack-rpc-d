import vibe.d;
import msgpackrpc;

void test(HTTPServerRequest req, HTTPServerResponse res)
{
    string enhanceme = req.query.get("enhanceme", "D");
    auto client = new TCPClient(Endpoint(18800, "127.0.0.1"));
    auto enhanced = client.call!string("enhance", enhanceme);
    res.writeBody("enhanced Result: " ~ enhanced ~ "\n");
}



void testTimeout(HTTPServerRequest req, HTTPServerResponse res)
{
    string enhanceme = req.query.get("enhanceme", "D");
    auto client = new TCPClient(Endpoint(18800, "127.0.0.1"), dur!"msecs"(100));
    auto rpcres = client.call!string("sleep", 10);
    auto rpcres2 = client.call!string("sleep", 1000);
    res.writeBody("result 1: " ~ rpcres ~ "\n result 2: " ~ rpcres2 ~ "\n");
}

static void main()
{

    setLogLevel(LogLevel.trace);

    auto router = new URLRouter;
    router.get("/", &test);

    router.get("/timeout.txt", &testTimeout);

    //set webserver config
    auto settings = new HTTPServerSettings;
    settings.port = 9090;
    settings.bindAddresses = ["0.0.0.0"];
    settings.options = settings.options | HTTPServerOption.parseCookies | HTTPServerOption.parseQueryString;
    listenHTTP(settings, router);

    //start a rpc server
    import rpcserver;

    auto rpcapi = new TCPServer!(RPCServer)(new RPCServer);
    rpcapi.listen(Endpoint(18800, "127.0.0.1"));

    lowerPrivileges();
    runEventLoop();

}
