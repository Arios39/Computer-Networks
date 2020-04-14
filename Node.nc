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
      uses interface Random as Random;
   
	uses interface Timer<TMilli> as neighbortimer;
	uses interface Timer<TMilli> as routingtimer;
		uses interface Timer<TMilli> as TCPtimer;
	
   uses interface SimpleSend as Sender;
       uses interface Hashmap<socket_store_t> as SocketsTable;
   
   uses interface Hashmap<table> as RoutingTable;
      uses interface Transport;
   
	uses interface List<Neighbor> as NeighborHood;
	uses interface Hashmap<pack> as PacketCache;
	//uses interface Quality<Qual> as Quality List
   uses interface CommandHandler;
}


implementation{
   pack sendPackage;
   socket_t global_fd;
   // Project 1 implementations (functions)
uint16_t seqNum=0;
uint16_t PacketSent;
uint16_t PacketArr;
float Q;
   bool met(uint16_t neighbor);
   bool inthemap( socket_t fd);
   void findneighbor();
   void Packhash(pack* Package, socket_t fd);
     void printNeighbors();
      socket_t getfd(TCPpack payload);
       uint16_t getfdmsg(uint16_t src);
     void ListHandler(pack *Package);
     void EstablishedSend();
     void replypackage(pack *Package);
      TCPpack dataPayload(uint16_t destport,uint16_t srcport,uint16_t flag,uint16_t ACK,uint16_t seq,uint16_t Awindow, TCPpack payload);
      TCPpack makePayload(uint16_t destport,uint16_t srcport,uint16_t flag,uint16_t ACK,uint16_t seq,uint16_t Awindow);
   void makeTCPpacket(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq,TCPpack payload, uint8_t length);
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
                   socket_store_t temp;
                   socket_t fd;
   
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
             
            switch (payload.payload[2]){
            case SYN_Flag:
            fd = getfd(payload);
                temp = call SocketsTable.get(fd); 
                dbg(TRANSPORT_CHANNEL, "SERVER:I have recived a SYN_Flag from %d\n",myMsg->src);
                
                call SocketsTable.remove(fd);
                temp = call Transport.accept(temp, payload);
                temp.dest.addr=myMsg->src;
                temp.effectiveWindow=payload.payload[5];
                call SocketsTable.insert(fd, temp);
                dbg(TRANSPORT_CHANNEL, "SERVER: Binded socket to dest addr:%d dest port: %d\n",temp.dest.addr, temp.dest.port);
                payload = makePayload( temp.dest.port,  temp.src.port,SYN_Ack_Flag,myMsg->seq+1,myMsg->seq,0);
  				makeTCPpacket(&sendPackage, TOS_NODE_ID,myMsg->src, 3, PROTOCOL_TCP,myMsg->seq+1,payload,TCP_PACKET_MAX_PAYLOAD_SIZE );
  				 Packhash(&sendPackage,fd);
   				forwarding(&sendPackage);   
   				break;
   				
   				
             case SYN_Ack_Flag:
      			  fd = getfd(payload);
                temp = call SocketsTable.get(fd); 
                 call SocketsTable.remove(fd);
                 temp.state = ESTABLISHED;           
                 call SocketsTable.insert(fd, temp);
   				 dbg(TRANSPORT_CHANNEL, "CLIENT: Connection to Server Port Established %d\n", temp.dest.port);
                 payload = makePayload( payload.payload[1],  payload.payload[0],Ack_Flag,myMsg->seq,myMsg->seq,0);
  				makeTCPpacket(&sendPackage, TOS_NODE_ID,myMsg->src, 3, PROTOCOL_TCP,myMsg->seq,payload,TCP_PACKET_MAX_PAYLOAD_SIZE ); //not complete
  				  				 Packhash(&sendPackage,fd);
  				
   				forwarding(&sendPackage);  
            break;
            
            
                  case Ack_Flag:
      			   fd = getfd(payload);
                temp = call SocketsTable.get(fd); 
                 call SocketsTable.remove(fd);
                 temp.state = ESTABLISHED;           
                 call SocketsTable.insert(fd, temp);
   				 dbg(TRANSPORT_CHANNEL, "SERVER: Connection to Client Port Established %d\n ", temp.dest.port);
   				 dbg(TRANSPORT_CHANNEL, "SERVER: window %d\n ", temp.effectiveWindow);
   				 
                 
            break;
            
            default:
            break;
            
            }
                           //call TCPtimer.startOneShot(12000);
            
         
         }
      } 
         
         
            if(myMsg->protocol==PROTOCOL_TCPDATA){ 
                        
              if( TOS_NODE_ID!=myMsg->dest){              
           forwarding(myMsg);         
         //Packhash(myMsg);
         }
         else{
             TCPpack payload;
             uint16_t i =0;
              uint8_t A =0;
              pack p;
              fd = getfdmsg(myMsg->src);
                                               memcpy(payload.payload, myMsg->payload, sizeof( myMsg->payload)*1);
                				// dbg(TRANSPORT_CHANNEL, "SERVER: window %d\n ",PACKET_MAX_PAYLOAD_SIZE );
             
                
                temp = call SocketsTable.get(fd); 
                // call SocketsTable.remove(fd);
            switch (temp.TYPE){
            
            case SERVER:     
            //FIN HERE******************************************88
             if(myMsg->payload[2]==Fin_Flag){
            fd = getfd(payload);
            temp = call SocketsTable.get(fd);
            call SocketsTable.remove(fd);
            //temp.state = CLOSED;
            dbg(TRANSPORT_CHANNEL, "SERVER:I have recived a FIN_Flag from %d\n",myMsg->src);

 
                temp = call Transport.accept(temp, payload);
                temp.dest.addr=myMsg->src;
                temp.effectiveWindow=payload.payload[5];
                call SocketsTable.insert(fd, temp);
                dbg(TRANSPORT_CHANNEL, "SERVER: Sening FIN_ACK to dest addr:%d dest port: %d\n",temp.dest.addr, temp.dest.port);
                payload = makePayload( temp.dest.port,  temp.src.port,Fin_Ack_Flag,myMsg->seq+1,myMsg->seq,0);
  				makeTCPpacket(&sendPackage, TOS_NODE_ID,myMsg->src, 3, PROTOCOL_TCP,myMsg->seq+1,payload,TCP_PACKET_MAX_PAYLOAD_SIZE );
  				 Packhash(&sendPackage,fd);
   				forwarding(&sendPackage);  
            
            
               }//temp
               
               
               
               //More fin here ***************8
             if(myMsg->payload[2] = Fin_Ack_Flag){
             	  fd = getfd(payload);
                temp = call SocketsTable.get(fd); 
                 call SocketsTable.remove(fd);
                 temp.state = CLOSED;           
                 call SocketsTable.insert(fd, temp);
                 //Do port cloing here maybe
   				 dbg(TRANSPORT_CHANNEL, "CLIENT: Received FIN_ACK, Connection to Server Port Closing %d\n", temp.dest.port);
             
             
             }
            if(myMsg->payload[2]==Data_Flag){
  

     dbg(TRANSPORT_CHANNEL,"Reading Data: ");
   
   for(i; i<temp.effectiveWindow;i++){
   
   
   	  // dbg(TRANSPORT_CHANNEL,"------------------------next expected %d \n",  temp.nextExpected);
   
   if( temp.nextExpected==myMsg->payload[i+6]){
	  temp.rcvdBuff[i] = myMsg->payload[i+6]; //copy payload into received buffer
	  	  	  	//dbg(TRANSPORT_CHANNEL,"bit %d\n",myMsg->payload[i+6]);
	  printf("%d,",temp.rcvdBuff[i]);
	 temp.lastRead = temp.rcvdBuff[i];
	  temp.nextExpected = temp.rcvdBuff[i]+1;
	  // dbg(TRANSPORT_CHANNEL,"next expected %d \n",  temp.nextExpected);
	  }else{
	  	  //	dbg(TRANSPORT_CHANNEL,"getting wrong bit%d\n",myMsg->payload[i+6]);
	  	  	break;
	  
	  }
	 
   
   }
   
     //dbg(TRANSPORT_CHANNEL,"Reading Data: ");
  printf("\n" );
	  
	 		
   p.payload[0]=temp.dest.port;
     p.payload[1]=temp.src.port;
       p.payload[2]=Data_Ack_Flag;
         p.payload[3]= temp.lastRead;
    p.payload[4]=  temp.nextExpected;
   temp.effectiveWindow=myMsg->payload[5];
    
    call SocketsTable.remove(fd);
        call SocketsTable.insert(fd, temp);
    makePack(&sendPackage, TOS_NODE_ID,myMsg->src , 3, PROTOCOL_TCPDATA, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
						forwarding(&sendPackage);
    // dbg(TRANSPORT_CHANNEL,"Next bit: %d",   temp.nextExpected);

             }       
          
            break;
            
              case CLIENT:   
              if(myMsg->payload[2]==Data_Ack_Flag){
                  fd = getfdmsg(myMsg->src);
            temp.lastAck = myMsg->payload[3];
            call SocketsTable.remove(fd);
        call SocketsTable.insert(fd, temp);
                            		 //dbg(TRANSPORT_CHANNEL, "---------- last bit rec %d\n ",   temp.lastAck);
                            		       //  call TCPtimer.startOneShot(12000);
                            		 
          EstablishedSend();
            }
            break;
            default:
            
           	break;
            }
            
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
 
  
   bool inthemap(socket_t fd){

      
if(!call PacketCache.contains(fd)){
 //call PacketCache.remove(Package->src);
 dbg(FLOODING_CHANNEL, "Adding packet \n" ); 
 return FALSE;
 }
   
    if(call PacketCache.contains(fd)){
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
   
   void Packhash(pack* Package, socket_t fd){
      
    if(!inthemap(fd)&&Package->src==TOS_NODE_ID){
    call PacketCache.insert(fd,sendPackage);
    }
     if(inthemap(fd)&&Package->src==TOS_NODE_ID){
          call PacketCache.remove(fd);
    call PacketCache.insert(fd,sendPackage);
    }
  

   }
   
     pack getpack(socket_t fd){
      pack temp;
 
   temp = call PacketCache.get(fd); 


return temp;
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

 socket_t getfd(TCPpack payload){

 socket_store_t temp;

   uint16_t size = call SocketsTable.size();
   uint8_t i =1;
   if(call SocketsTable.isEmpty()){
   
   return 0;
   
   }
   
   for(i;i<=size;i++){
   
   temp = call SocketsTable.get(i);
   
   if(temp.src.port == payload.payload[0]){
   
return i;      
   }
   
   }


return 0;
}
 uint16_t getfdmsg(uint16_t src){

 socket_store_t temp;

   uint16_t size = call SocketsTable.size();
   uint8_t i =1;
   if(call SocketsTable.isEmpty()){
   
   return 0;
   
   }
   
   for(i;i<=size;i++){
   
   temp = call SocketsTable.get(i);
   
   if(temp.dest.addr == src){
   
return i;      
   }
   
   }


return 0;
}
 
 
  TCPpack makePayload(uint16_t destport,uint16_t srcport,uint16_t flag,uint16_t ACK,uint16_t seq,uint16_t Awindow){
   TCPpack payload;
  
   payload.payload[0]=destport;
   payload.payload[1]=srcport;
   payload.payload[2]=flag;
   payload.payload[3]=ACK;
   payload.payload[4]=seq;
   payload.payload[5]=Awindow;
  
   return payload;
   }
   
     TCPpack dataPayload(uint16_t destport,uint16_t srcport,uint16_t flag,uint16_t ACK,uint16_t seq,uint16_t Awindow, TCPpack payload){
  
   payload.payload[0]=destport;
   payload.payload[1]=srcport;
   payload.payload[2]=flag;
   payload.payload[3]=ACK;
   payload.payload[4]=seq;
   payload.payload[5]=Awindow;
  
   return payload;
   }



event void TCPtimer.fired(){
//TCP Timer 
  socket_store_t temp;
  pack resendpack;
  socket_addr_t socket_server;
  uint16_t size = call SocketsTable.size();
  uint8_t i =1;
  for(i;i<=size;i++){
  temp = call SocketsTable.get(i);
//  call SocketsTable.remove(i);

  switch(temp.state){
  
  case SYN_SENT:
  dbg(TRANSPORT_CHANNEL,"Resending SYN_SENT\n");
  resendpack = getpack(i);
  forwarding(&resendpack);   
  break;
 
 
  case SYN_RCVD:
  dbg(TRANSPORT_CHANNEL,"Resending SYN_RCVD\n");
  resendpack = getpack(i);
  forwarding(&resendpack);   
  break;
 
  case ESTABLISHED:
  if(temp.TYPE==CLIENT){
    dbg(TRANSPORT_CHANNEL,"Sending data...................\n");
  
  EstablishedSend();
  
  }
  break;
 
 default:
 break; 
 }
 
 
 
 
call SocketsTable.insert(i, temp);
   }

   }
     void makeTCPpacket(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq,TCPpack payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = Protocol;

      
      memcpy(Package->payload, payload.payload, length);
      
      	//dbg(TRANSPORT_CHANNEL,"length ===== %d\n", length);
      
      
      
   }
   
   void synPacket(uint16_t dest, uint16_t destPort, uint16_t srcPort,socket_t fd,uint16_t window){
      TCPpack payload;
         uint16_t randseq = (call Random.rand16()%300);
         
   payload = makePayload(destPort, srcPort,SYN_Flag,0,randseq,window);
  makeTCPpacket(&sendPackage, TOS_NODE_ID,dest, 3, PROTOCOL_TCP,randseq,payload,TCP_PACKET_MAX_PAYLOAD_SIZE );
    				 Packhash(&sendPackage,fd);
  
   forwarding(&sendPackage);
   
   }

  void EstablishedSend(){
     socket_store_t temp;
      uint16_t destport, srcport, flag, ACK, seq, Awindow;
  pack p;
uint16_t size = call SocketsTable.size();
   uint16_t i =1;
      uint16_t j;
         uint16_t k=0;

				for(i; i<=size;i++){
 				temp = call SocketsTable.get(i);
						if(temp.state==ESTABLISHED){
         				 k=0;
         				 j = temp.lastAck+1;
  						 destport = temp.dest.port;
  						 srcport = temp.src.port;
  						 flag = Data_Flag;
   							ACK = temp.lastAck;
   							seq = temp.lastAck+1;
						
							for(k; k<=temp.effectiveWindow;k++){

							                   
							p.payload[k+6] = j+k;
						if(p.payload[k+6]==temp.Transfer_Buffer){ // check when its stoping
							flag = Fin_Flag;
							temp.lastSent = k+6;
							
							break;
							
						}
								}
								  Awindow = (temp.Transfer_Buffer-p.payload[k+4]);
								  p.payload[0] =  destport;
								  p.payload[1] = srcport;
								   p.payload[2] =flag;
								  p.payload[3] =ACK;
								   p.payload[4] =seq;
								   if(Awindow%16==0){
								 p.payload[5]=16;
								   }else{
								  p.payload[5] =Awindow%16;
								  }
								  temp.effectiveWindow =  p.payload[5];
								     call SocketsTable.remove(i);
        call SocketsTable.insert(i, temp);
								  if( p.payload[2]!=Fin_Flag){
								
				makePack(&sendPackage, TOS_NODE_ID, temp.dest.addr, 3, PROTOCOL_TCPDATA, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								   forwarding(&sendPackage);
								}
              					if(p.payload[2] == Fin_Flag){
              					
              					// dbg(TRANSPORT_CHANNEL,"Preparing to send FIN:\n");
              					p.payload[5]=temp.lastSent;
              					temp.effectiveWindow = p.payload[5];
              					call SocketsTable.remove(i);
       							 call SocketsTable.insert(i, temp);
        makePack(&sendPackage, TOS_NODE_ID, temp.dest.addr, 4, PROTOCOL_TCPDATA, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								 forwarding(&sendPackage);
              					  dbg(TRANSPORT_CHANNEL,"Closing at: %d \n", temp.src.port);
              					 
              					
              					
              					
              					}
						}



				} 
            
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
           socket_store_t tempsocket;
   
   socket_t fd = call Transport.socket();
   socket.addr = TOS_NODE_ID;
   socket.port = port;
        if(call Transport.bind(fd, &socket) == SUCCESS){
 dbg(TRANSPORT_CHANNEL,"Server Binding to port: %d success!\n", port);
     }
   if(call Transport.listen(fd) == SUCCESS) {
      // dbg(TRANSPORT_CHANNEL, "Fire timer\n");
        tempsocket =  call Transport.getSocket(fd);
        tempsocket.TYPE= SERVER;
                tempsocket.nextExpected= 1;
                tempsocket.lastRead=0;
        
         tempsocket.lastRead = 0;
     call SocketsTable.insert(fd, tempsocket);
                //call TCPtimer.startOneShot(6000);
       
     }

//call timmer
   
   }

   event void CommandHandler.setTestClient(uint16_t dest, uint16_t destPort, uint16_t srcPort, uint16_t transfer){
   socket_addr_t socket_address;
      socket_addr_t socket_server;
        socket_store_t tempsocket;
   socket_t fd = call Transport.socket();
   //dbg(TRANSPORT_CHANNEL,"port : %d\n", port);
   socket_address.addr = TOS_NODE_ID;
   socket_address.port = srcPort;
   socket_server.addr = dest;
   socket_server.port = destPort;
    if(call Transport.bindClient(fd, &socket_address, &socket_server) == SUCCESS){
       dbg(TRANSPORT_CHANNEL, "Client: Binding to port: %d!\n", srcPort);
       //get socket
     tempsocket =  call Transport.getSocket(fd);
            //dbg(TRANSPORT_CHANNEL, "src port..%d!\n",fd );
      tempsocket.state = SYN_SENT;
      tempsocket.TYPE= CLIENT;
      tempsocket.lastAck=0;
      tempsocket.Transfer_Buffer= transfer;
      tempsocket.effectiveWindow=transfer%16;
      call SocketsTable.insert(fd, tempsocket);
          synPacket(dest,  destPort,  srcPort, fd, tempsocket.effectiveWindow);
                call TCPtimer.startOneShot(12000);
                
     }
     
    
  
 
   
   }

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
            	//dbg(TRANSPORT_CHANNEL,"length ===== %d\n", length);
      
      memcpy(Package->payload, payload, length);
   }
}