/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{

}
implementation {
    components MainC;
    components Node;
 
    components new AMReceiverC(AM_PACK) as GeneralReceive;
	components new TimerMilliC() as neighbortimer;
	components new TimerMilliC() as routingtimer;
    Node -> MainC.Boot;
    Node.routingtimer->routingtimer;
	Node.neighbortimer -> neighbortimer;
    Node.Receive -> GeneralReceive;

	components new HashmapC(Route,20) as RoutingTableC;
	Node.RoutingTable -> RoutingTableC;
	
	
    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

  components new ListC(Neighbor, 20) as NeighborHoodC;
   Node.NeighborHood -> NeighborHoodC;

   components new HashmapC(pack, 500) as PacketCacheC; //Hash to store packets in circulatio
   Node.PacketCache -> PacketCacheC;  
   
    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;
}
