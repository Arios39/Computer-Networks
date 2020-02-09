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
uint16_t Q;

} Neighbor;

module Node{
   uses interface Boot;  
   uses interface SplitControl as AMControl;
   uses interface Receive;
	uses interface Timer<TMilli> as neighbortimer;
   uses interface SimpleSend as Sender;
	uses interface List<Neighbor> as NeighborHood;
	uses interface Hashmap<int> as PacketCache;
	
   uses interface CommandHandler;
}

implementation{
   pack sendPackage;
   // Prototypes

   bool met(uint16_t neighbor);
   bool inthemap(pack* Package);
   void findneighbor();
    void Packhash(pack* Package);
     void printNeighbors();
     void ListHandler(pack *Package);
     void replypackage(pack *Package);
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);
 
   event void Boot.booted(){
   
      call AMControl.start();
   call neighbortimer.startOneShot(250);
      dbg(GENERAL_CHANNEL, "Booted\n");
   }
   
   
   event void neighbortimer.fired(){

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
   
    // dbg(GENERAL_CHANNEL, "Packet Received\n");
            
      
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
 //---------------------------------neighbordiscovery        
 if(myMsg->dest== AM_BROADCAST_ADDR){
	if(myMsg->protocol==PROTOCOL_PING){
           replypackage(myMsg);

      }  
      
      if(myMsg->protocol==PROTOCOL_PINGREPLY){  
          
           ListHandler(myMsg);
      }  
      }
      
     //-------------------------------------------endofneighbordiscovery
     
    else{
 
     
                if(myMsg->protocol==PROTOCOL_PING){
               
         if( TOS_NODE_ID!=myMsg->dest){
         
         Packhash(myMsg);
         
         }
              if( TOS_NODE_ID==myMsg->dest){
         
        dbg(FLOODING_CHANNEL, "Ight ima head out \n" );
         
         }
      }  
      
      if(myMsg->protocol==PROTOCOL_PINGREPLY){  
   
      
      }         
     }
      
       // dbg(GENERAL_CHANNEL, "Package Payload: %d\n", myMsg->src);
         
         return msg;
      }

      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }




   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n" );
      	   
      makePack(&sendPackage, TOS_NODE_ID, destination, 0, PROTOCOL_PING, 0, payload, PACKET_MAX_PAYLOAD_SIZE);
      if(!met(destination)){
      Packhash(&sendPackage);
    
          }
      call Sender.send(sendPackage, destination);
   }

//--------------------------------------------------------------------------project 1 functions

//met will check if we already have node in list

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
neighbor.node = Package->src;
 call NeighborHood.pushback(neighbor);
   // dbg(GENERAL_CHANNEL, "Havent met you %d\n", Package->src);
}
}
//---------------------------------------------------------------------------------

//------------------------------------------------------------------------------------findneighbor function 
  
     void findneighbor(){
     char * msg;

    msg = "Will you be my Nebber";
    
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PING, 0, (uint8_t *)msg, (uint8_t)sizeof(msg));
       call Sender.send(sendPackage, AM_BROADCAST_ADDR);

   
   }
 //-----------------------------------------------------------------------------------------------
 
 //------------------------------------------------------------------------------------------------ 
  
   void replypackage(pack* Package){
       makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 0, PROTOCOL_PINGREPLY, 0, 0, 0);
       call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }
//------------------------------------------------------------------------------------------------------- 
  
   bool inthemap(pack* Package){
   
   if(call PacketCache.contains(sizeof(Package->payload))){
 dbg(GENERAL_CHANNEL, "package already exists %s \n",Package->payload  );
   return TRUE;

   }
   
   return FALSE;
   
   }
   
   
   void Packhash(pack* Package){
     Neighbor node;
	uint16_t i,size = call NeighborHood.size(); 
    // pack* myMsg=(pack*) payload;
    if(!inthemap(Package)){
    call PacketCache.insert(sizeof(Package->payload), Package);
       for(i =0; i < size;i++){
   node=call NeighborHood.get(i); 
   if(node.node!=0&&node.node!=Package->src){
    dbg(FLOODING_CHANNEL, "Sending to : %d \n", node.node );
   makePack(&sendPackage, Package->src, Package->dest, 0, PROTOCOL_PING, 0, (uint8_t*) Package->payload, sizeof( Package->payload));
    call Sender.send(sendPackage, node.node);
   }
   }
    
    
    }
   }
   
   
   
   
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
   
   
   


   event void CommandHandler.printNeighbors(){   
   }

   event void CommandHandler.printRouteTable(){}

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