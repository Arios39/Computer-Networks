from TestSim import TestSim


    
    # Get simulation ready to run.
s = TestSim();
   
    # Before we do anything, lets simulate the network off.
s.runTime(1);
   
    # Load the the layout of the network.
s.loadTopo("example.topo");

    # Add a noise model to all of the motes.
s.loadNoise("no_noise.txt");

    # Turn on all of the sensors.
s.bootAll();

    # Add the main channels. These channels are declared in includes/channels.h

s.addChannel(s.GENERAL_CHANNEL);
#s.addChannel(s.NEIGHBOR_CHANNEL);
#s.addChannel(s.FLOODING_CHANNEL);
s.addChannel(s.TRANSPORT_CHANNEL);
#s.addChannel(s.ROUTING_CHANNEL);
#s.addChannel(s.HASHMAP_CHANNEL);
    # After sending a ping, simulate a little to prevent collision.
s.runTime(10);



#s.ping(1, 7, "hi");
#s.runTime(20);
#s.ping(1, 5, "hi");
#s.runTime(50);

s.testServer(1,41);
s.runTime(10);

s.testServer(1,41);
s.runTime(10);

s.testServer(1,41);
s.runTime(10);

s.ping(2, 7, "hello arios39 \r\n");
s.runTime(10);

s.ping(5, 9, "hello cortiz42 \r\n");
s.runTime(10);

s.ping(3, 9, "hello dguinn \r\n");
s.runTime(10);

s.ping(1, 41, "listuser\r\n");
s.runTime(10);

s.ping(2, 7, "msg Hello World!\r\n");
s.runTime(10);

s.ping(3, 2, "whisper arios39 Hey \r\n");
s.runTime(10);



