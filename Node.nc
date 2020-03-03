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

typedef struct{

uint16_t node;
//uint16_t Q;
//uint16_t PacketSent;
//uint16_t PacketArr;
} Neighbor;
// neighbor struct that will hold a node and the quality of the node connection

module Node{
   uses interface Boot;  
   uses interface SplitControl as AMControl;
   uses interface Receive;
	uses interface Timer<TMilli> as neighbortimer;
   uses interface SimpleSend as Sender;
   
   uses interface Hashmap<uint16_t> as RoutingTable;
   
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
   
   event void Boot.booted(){
      call AMControl.start();
      // a timer that will add and drop neighbors
      // the timmer will have a oneshot of (250)
      
   call neighbortimer.startOneShot(250);
      dbg(GENERAL_CHANNEL, "Booted\n");
   }
   
   
   event void neighbortimer.fired(){
//calls nieghbor discovery discover 
//Neighbor neighbor;
findneighbor();
   
       
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
  
  
    // dbg(GENERAL_CHANNEL, "Packet Received\n");

      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         if(myMsg->TTL==0&&myMsg->protocol==PROTOCOL_PING){
         // will drop packet when ttl expires packet will be dropped
         
         dbg(FLOODING_CHANNEL, "TTL has expired, packet from %d to %d will be dropped\n",myMsg->src, myMsg->dest);
         }
         
         if (myMsg->TTL!=0 && myMsg->dest!= TOS_NODE_ID){
         seqNum = myMsg->seq;
         
         // will make all seq of node and packet nodes equal 
         // This will help to keep track of what nodes have recived that packet in the hash
         
         if(myMsg->protocol==PROTOCOL_PING){
           if( TOS_NODE_ID!=myMsg->dest){
                    //If message is ping it will put packet in hash 
                    
         Packhash(myMsg);
         }
         
      }      
      if(myMsg->protocol==PROTOCOL_PINGREPLY){  
          // if ping reply add nieghbor to neighbor list && will take care of nodes being added or dropped
           ListHandler(myMsg);
      }  
         
         }
         // This will take care of the dest node from reciving the deliverd packet again and again...
         
         if(myMsg->dest == TOS_NODE_ID && !inthemap(myMsg)&&myMsg->protocol==PROTOCOL_PING){
         seqNum = myMsg->seq;
          dbg(FLOODING_CHANNEL, "I have recived a message from %d and it says %s\n",myMsg->src, myMsg->payload);
   Packhash(myMsg);
   			
   			//neighbor.Q = (neighbor.PacketArr/neighbor.PacketSent);
   		
          }     
     //-------------------------------------------endofneighbordiscovery 
         
         return msg;
      }

      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }




   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT destination %d\n", destination );
      seqNum++;
      makePack(&sendPackage, TOS_NODE_ID, destination, 10, PROTOCOL_PING,seqNum, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
      
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
dbg(NEIGHBOR_CHANNEL, "Node %d was added to %d's Neighborhood\n", Package->src, TOS_NODE_ID);
neighbor.node = Package->src;
call RoutingTable.insert(Package->src,1 );
 call NeighborHood.pushback(neighbor);
 		PacketArr++;
   		PacketSent;
   		
  dbg(FLOODING_CHANNEL, "The Successful packets from Node %d to %d is %d\n",Package->src, TOS_NODE_ID, PacketArr); // More QUALITY TEST
   		 
    Q=((PacketSent)/((float)PacketArr));
    dbg(FLOODING_CHANNEL, "The Quality from %d to %d is %f\n",Package->src, TOS_NODE_ID, Q);
   		 
   		 
   		 
   		 
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
      dbg(NEIGHBOR_CHANNEL, "The number of Packets sent is %d\n",PacketSent); //QUALITY TEST
       
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
         dbg(GENERAL_CHANNEL, "Hello Neighbor im Node: %d \n", node.node );
   }
   
   }
   
   }
   
   
   void printRouteTable(){
  uint16_t neighborthru = call RoutingTable.size();
  uint16_t hop;
for(int i=0; i<neighborthru;i++){
 hop=call RoutingTable.get(i); 
if (hop!=0){
dbg(GENERAL_CHANNEL, "Node %d has a hop distance to node %d of %d", TOS_NODE_ID,i,hop);
}
}
   
   }
   

   event void CommandHandler.printNeighbors(){ 
   printNeighbors();  
   }

   event void CommandHandler.printRouteTable(){
   printRouteTable();
   }

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

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