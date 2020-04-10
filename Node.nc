/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"
#include "includes/TCP_packet.h"
#include "includes/socket.h"


//#define MAX_ROUTES 128;



typedef struct{

uint16_t node;

//uint16_t Q;
//uint16_t PacketSent;
//uint16_t PacketArr;
} Neighbor;
// neighbor struct that will hold a node and the quality of the node connection


typedef nx_struct table{ //Defines each entry in the routeing table 
nx_uint8_t Destination;
nx_uint8_t NextHop;
nx_uint8_t Cost;
}table;





module Node{
   uses interface Boot;  
   uses interface SplitControl as AMControl;
   uses interface Receive;
	uses interface Timer<TMilli> as neighbortimer;
	uses interface Timer<TMilli> as routingtimer;
		uses interface Timer<TMilli> as TCPtimer;
	
   uses interface SimpleSend as Sender;
   
   uses interface Hashmap<table> as RoutingTable;
      uses interface Transport;
   
	uses interface List<Neighbor> as NeighborHood;
	uses interface Hashmap<pack> as PacketCache;
	//uses interface Quality<Qual> as Quality List
   uses interface CommandHandler;
}


implementation{
   pack sendPackage;
   // Project 1 implementations (functions)
uint16_t seqNum=0;
uint16_t PacketSent;
uint16_t PacketArr;
float Q;
   bool met(uint16_t neighbor);
   bool inthemap(pack* Package);
   void findneighbor();
    void Packhash(pack* Package);
     void printNeighbors();
     void ListHandler(pack *Package);
     void replypackage(pack *Package);
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
   // end of project 1 functions 
   
//Project 2 implementations (functions)]
    uint16_t numRoutes =0;
 table routingTable[255]= {0};
   	
   	void forwarding(pack* Package);
    void printRouteTable();
   void localroute();
   void Route_flood();
   void checkdest(table* tmptable);
   bool checkMin(table* tmptable);
  // void UpdateRoutingTable(Route *newRoute, uint16_t numNewRoutes);
// end of Project 2 implementations (functions)
   
   event void Boot.booted(){
      call AMControl.start();
      // a timer that will add and drop neighbors
      // the timmer will have a oneshot of (250)
      
   call neighbortimer.startOneShot(250);
      call routingtimer.startOneShot(250);
   
      dbg(GENERAL_CHANNEL, "Booted\n");
   }
   
   
   event void neighbortimer.fired(){
//calls nieghbor discovery discover 
//Neighbor neighbor;
findneighbor();
       
   }
      event void routingtimer.fired(){
//calls nieghbor discovery discover 
//Neighbor neighbor;

       Route_flood();
   }
   
   
   
   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }


  event void AMControl.stopDone(error_t err){}



   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
   Neighbor neighbor;
table route[1];  
    // dbg(GENERAL_CHANNEL, "Packet Received\n");

      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         // Route_flood();
          if(myMsg->protocol==PROTOCOL_LINKEDLIST){
    memcpy(route, myMsg->payload, sizeof(route)*1);
          	route[0].NextHop=myMsg->src;
       checkdest(route);
          }
          
      if(myMsg->TTL==0&&myMsg->protocol==PROTOCOL_PING){
         // will drop packet when ttl expires packet will be dropped
        // dbg(ROUTING_CHANNEL, "TTL has expired, packet from %d to %d will be dropped\n",myMsg->src, myMsg->dest);
         }
         
         if(myMsg->protocol==PROTOCOL_PING){
         
           if( TOS_NODE_ID!=myMsg->dest){
           forwarding(myMsg);         
         //Packhash(myMsg);
         }
         else{
  
         
   dbg(ROUTING_CHANNEL, "I have recived a message from %d and it says %s\n",myMsg->src, myMsg->payload);
         
         
         }
         
         
      }  
       
           if(myMsg->protocol==PROTOCOL_TCP){  
          // if ping reply add nieghbor to neighbor list && will take care of nodes being added or dropped
           if( TOS_NODE_ID!=myMsg->dest){
           forwarding(myMsg);         
         //Packhash(myMsg);
         }else{
                TCPpack payload;
             memcpy(payload.payload, myMsg->payload, sizeof(payload.payload)*1);
          dbg(ROUTING_CHANNEL, "I have recived a message from %d and its sending a flag of %d\n",myMsg->src, payload.payload[2]);
         
         }
      } 
         
      if(myMsg->protocol==PROTOCOL_PINGREPLY){  
          // if ping reply add nieghbor to neighbor list && will take care of nodes being added or dropped
           ListHandler(myMsg);
      }  
         
         
         // This will take care of the dest node from reciving the deliverd packet again and again...
         
       
     //-------------------------------------------endofneighbordiscovery 
         
         return msg;
      }

      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }




   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
   
      dbg(GENERAL_CHANNEL, "PING EVENT destination %d\n", destination );
     
     // seqNum++;
     makePack(&sendPackage, TOS_NODE_ID, destination, 10, PROTOCOL_PING,seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
         forwarding(&sendPackage);
    //  call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      
   }

//--------------------------------------------------------------------------project 1 functions

//met will check if we already have node in neighbor list

bool met(uint16_t neighbor){
Neighbor node;
uint16_t i,size = call NeighborHood.size();   
   for(i =0; i < size;i++){
   node=call NeighborHood.get(i); 
   if(node.node==neighbor){   
        // dbg(GENERAL_CHANNEL, "We have already met dude im node: %d \n", neighbor );
   return TRUE;
   }
}
return FALSE;
}


//----------------------------------------------------------------------- ListHandler will push the nodes into a list

void ListHandler(pack* Package){
Neighbor neighbor;
if (!met(Package->src)){
localroute();
dbg(NEIGHBOR_CHANNEL, "Node %d was added to %d's Neighborhood\n", Package->src, TOS_NODE_ID);
neighbor.node = Package->src;
 call NeighborHood.pushback(neighbor);
 		PacketArr++;
   		PacketSent;
   	  localroute();	
   		 
    Q=((PacketSent)/((float)PacketArr));
   		 
   		 
   		 
   		 
   // dbg(GENERAL_CHANNEL, "Havent met you %d\n", Package->src);
 
}
}
//---------------------------------------------------------------------------------

//------------------------------------------------------------------------------------findneighbor function 
  
     void findneighbor(){
     Neighbor neighbor;
     char * msg;
    msg = "Help";    
    dbg(NEIGHBOR_CHANNEL, "Sending help signal to look for neighbor! \n");
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_PINGREPLY, 0, (uint8_t *)msg, (uint8_t)sizeof(msg));
       call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      // neighbor.PacketSent++;
      PacketSent++;

       
   }
 //-----------------------------------------------------------------------------------------------
 
 //------------------------------------------------------------------------------------------------ reply message will be sent to node who sent ping

  
   void replypackage(pack* Package){
       makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PINGREPLY, 0, 0, 0);
       call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }
//------------------------------------------------------------------------------------------------------- inthehashmap will check if node already has packet in cache
 
  
   bool inthemap(pack* Package){

      
if(!call PacketCache.contains(Package->seq)){
 //call PacketCache.remove(Package->src);
 dbg(FLOODING_CHANNEL, "Adding packet ( %s ) into cache with seqNum %d\n",Package->payload,Package->seq ); 
 return FALSE;
 }
   if(call PacketCache.contains(Package->seq)&&Package->payload!="Help"){
   dbg(FLOODING_CHANNEL, "packet ( %s ) already in cache will drop packet  \n",Package->payload ); 
   return TRUE;
   } 
   
    if(call PacketCache.contains(Package->seq)&&Package->payload=="Help"){
    //ignore help signal just add to neighborhood
    
    
   return TRUE;
   } 
 
 
   }
 //---------------------------------------------Flood will create flooding message and will send it to all neighboring nodes (this is accomplished by iterating thru neighbor list and making flooding packet)
   
      void flood(pack* Package){
     Neighbor node;
     Neighbor neighbor;
	uint16_t i,size = call NeighborHood.size(); 
       for(i =0; i < size;i++){
   node=call NeighborHood.get(i); 
   if(node.node!=0&&node.node!=Package->src){
    dbg(FLOODING_CHANNEL, "Flooding Packet to : %d \n", node.node );
   makePack(&sendPackage, Package->src, Package->dest, Package->TTL-1, PROTOCOL_PING, Package->seq, (uint8_t*) Package->payload, sizeof( Package->payload));
    call Sender.send(sendPackage, node.node);
    	
    	//dbg(FLOODING_CHANNEL, "The Packets sent %d\n", neighbor.PackSent);
   			
   }
   }
    
    
    
   
   }
  //-----------------------------------------------------------------------------
  //this function will push packet to our node cache(PacketCache)
   
   void Packhash(pack* Package){
      
    if(!inthemap(Package)&&Package->dest==TOS_NODE_ID){
    call PacketCache.insert(seqNum,sendPackage );
    replypackage(Package);
    }
   
    if(!inthemap(Package)&&Package->dest!= TOS_NODE_ID){
    call PacketCache.insert(seqNum,sendPackage );
    replypackage(Package);
    flood(Package);
    }

   }
   

   
   // This will print our nieghbors by itterating thru the neighbor list of current node(mote)
   
   void printNeighbors(){
   Neighbor node;
	uint16_t i,size = call NeighborHood.size();   
   for(i =0; i < size;i++){
   node=call NeighborHood.get(i); 
   if(node.node!=0){
      //   dbg(GENERAL_CHANNEL, "Hello Neighbor im Node: %d \n", node.node );
   }
   
   }
   
   }
   
   //---------------------------------------------------Project2 functions
   void printRouteTable(){
   uint16_t j;
   table route;
dbg(ROUTING_CHANNEL,"Routing Table:\n");
dbg(ROUTING_CHANNEL,"Dest\t Hop\t Count\n");
for(j =0; j < 20;j++){
   		route=call RoutingTable.get(j);
   	if(route.Cost!=0){
		dbg(ROUTING_CHANNEL,"%d\t\t %d\t %d\n", route.Destination, route.NextHop, route.Cost);
		
   }
}
} 
void localroute(){ //Populates local route with nodes
          Neighbor node;
	uint16_t i,size = call NeighborHood.size(); 
       for(i =0; i < size;i++){
   node=call NeighborHood.get(i); 
   if(node.node!=0&&!call RoutingTable.contains(node.node)){
   routingTable[i].Cost=1;
   routingTable[i].Destination= node.node;
   routingTable[i].NextHop = TOS_NODE_ID;
   call RoutingTable.insert(routingTable[i].Destination,routingTable[i]);
  //dbg(ROUTING_CHANNEL, "Node %d was added at location %d\n",routingTable[i].Destination,i);
   	
   }
   }
   Route_flood();
}

      void Route_flood(){ //Sends neigbors its local routeing table
     Neighbor node;
     table route[1];
        uint32_t* keys= call RoutingTable.getKeys();   
	uint16_t j=0,i,size = call NeighborHood.size(); 
  			
  			 while(keys[j]!=0){
  			 route[0] = call RoutingTable.get(keys[j]);
  		//dbg(ROUTING_CHANNEL, "sending my routing Table to: %d with route to get to node %d\n", node.node, route[0].Destination);
 			 makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_LINKEDLIST, 0,(uint8_t*)route ,sizeof(table)*1);
    		call Sender.send(sendPackage, AM_BROADCAST_ADDR);   
    		j++;
  			  }
 
   }
   void inserttable(table* tmptable){ //adds the route to the local table
   uint16_t i=0;
while(routingTable[i].Destination!=0){
i++;

}
routingTable[i].Destination=tmptable[0].Destination;
routingTable[i].NextHop=tmptable[0].NextHop;
routingTable[i].Cost=tmptable[0].Cost+1;
   call RoutingTable.insert(tmptable[0].Destination,routingTable[i]);
  Route_flood();
   
   
   }

bool checkMin(table* tmptable){ //Will check if the cost is already the lowest.
table route;
route = call RoutingTable.get(tmptable[0].Destination);
if(route.Cost != 0&& route.Cost > tmptable[0].Cost){
return TRUE;
}
if(route.Cost == 0){
return TRUE;
}
else{
return FALSE;
}
}


void checkdest(table* tmptable){ //Check if our destination is already in the local routing table

uint16_t j=0,i=0; 
if(checkMin(tmptable)){
if(!call RoutingTable.contains(tmptable[i].Destination)&&tmptable[i].Destination!= TOS_NODE_ID){
inserttable(tmptable);
}
}
else{
//Route_flood();
}

}

void forwarding(pack* Package){

if(call RoutingTable.contains(Package->dest)){
table route;
route = call RoutingTable.get(Package->dest);
if(route.Cost!=1){
dbg(ROUTING_CHANNEL,"Routing Packet - src: %d, dest: %d, seq: %d, next hop: %d, cost:%d \n",Package->src,Package->dest,Package->seq,route.NextHop,route.Cost);
 makePack(&sendPackage, Package->src, Package->dest, 3, Package->protocol, Package->seq, (uint8_t*) Package->payload, sizeof( Package->payload));
    call Sender.send(sendPackage,route.NextHop); //will send to next node
}
else{

dbg(ROUTING_CHANNEL,"Routing Packet - src: %d, dest: %d, seq: %d, next hop: %d, cost:%d, protocol %d \n",Package->src,Package->dest,Package->seq,route.NextHop,route.Cost,Package->protocol);
 makePack(&sendPackage, Package->src, Package->dest, 3, Package->protocol, Package->seq, (uint8_t*) Package->payload, sizeof( Package->payload));
    call Sender.send(sendPackage,Package->dest); //will send to its dest
}




}
//If not in the table send to closest node
else{
table route;
route = call RoutingTable.get(Package->dest);
if(route.Cost==1){

dbg(ROUTING_CHANNEL,"Routing Packet - src: %d, dest: %d, seq: %d, next hop: %d, cost: \n",Package->src,Package->dest,Package->seq,route.NextHop);
makePack(&sendPackage, Package->src, Package->dest, 3, PROTOCOL_PING, Package->seq, (uint8_t*) Package->payload, sizeof( Package->payload));
call Sender.send(sendPackage,route.NextHop);
}
}
}
//-------------------------------------------------------end of project2 functions

//------------------------------------------------------------------Project 3 functions

event void TCPtimer.fired(){
//TCP Timer 
       dbg(TRANSPORT_CHANNEL, "TCP timer linked\n");
       
      

   }
   void makeTCPpacket(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq,uint16_t flag, uint16_t destPort, uint16_t srcPort, uint8_t length){
     TCPpack payload;
  Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      payload.destport = destPort;
            payload.payload[0] =  payload.destport;
      
      payload.srcport = srcPort;
                  payload.payload[1] =  payload.srcport;
      
      payload.flag = flag;
                        payload.payload[2] =  payload.flag;
      
      memcpy(Package->payload, payload.payload, length);
   }
   
   void synPacket(uint16_t dest, uint16_t destPort, uint16_t srcPort,socket_t fd){
   makeTCPpacket(&sendPackage, TOS_NODE_ID,dest, 3, PROTOCOL_TCP,0, 5, destPort, srcPort,TCP_PACKET_MAX_PAYLOAD_SIZE );
   forwarding(&sendPackage);
   
   }

//-------------------------------------------------------------------End of project 3


   event void CommandHandler.printNeighbors(){ 
   printNeighbors();  
   }

   event void CommandHandler.printRouteTable(){
  printRouteTable();
   
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(uint16_t port){
   socket_addr_t socket;
   socket_t fd = call Transport.socket();
 dbg(TRANSPORT_CHANNEL,"port : %d\n", port);
   socket.addr = TOS_NODE_ID;
   socket.port = port;
        if(call Transport.bindS(fd, &socket) == SUCCESS){
       dbg(TRANSPORT_CHANNEL, "SERVER: BINDING SUCCESS!\n");
     }
   if(call Transport.listen(fd) == SUCCESS) {
       dbg(TRANSPORT_CHANNEL, "Fire timer\n");
                call TCPtimer.startOneShot(6000);
       
     }

//call timmer
   
   }

   event void CommandHandler.setTestClient(uint16_t dest, uint16_t destPort, uint16_t srcPort, uint16_t transfer){
   socket_addr_t socket_address;
      socket_addr_t socket_server;
   
   socket_t fd = call Transport.socket();
   //dbg(TRANSPORT_CHANNEL,"port : %d\n", port);
   socket_address.addr = TOS_NODE_ID;
   socket_address.port = srcPort;
    if(call Transport.bindS(fd, &socket_address) == SUCCESS){
       dbg(TRANSPORT_CHANNEL, "SERVER: BINDING SUCCESS!\n");
     }
     synPacket( dest,  destPort,  srcPort, fd);
      socket_server.addr = dest;
   socket_server.port = destPort;
   
   
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }
}