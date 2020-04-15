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



s.testServer(2,4);
s.runTime(10);

#dest destport srcport transfer
s.testClient(1, 2, 4, 5, 60);
s.runTime(10);

s.ClientClose(1, 2, 4, 5);
s.runTime(10);


