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
   socket_store_t connections[MAX_NUM_OF_SOCKETS];
   uint8_t Gpayload[20];
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
                                      socket_store_t temp2;
                   
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
                dbg(TRANSPORT_CHANNEL, "SERVER:I have recived a SYN_Flag from %d for Port %d\n",myMsg->src, temp.src.port);
                
                call SocketsTable.remove(fd);

    temp.state = SYN_RCVD;
    temp.dest.port = payload.payload[1];
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
   				 dbg(TRANSPORT_CHANNEL, "SERVER: Connection to Client Port Established\n");
					
   				 //make a list of "ports"
                 
            break;
            
            default:
            break;
            
            }
                           //call TCPtimer.startOneShot(12000);
            
         
         }
      } 
      
            if(myMsg->protocol==PROTOCOL_whisper){ 
             //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                        
              if( TOS_NODE_ID!=myMsg->dest){              
           forwarding(myMsg);         
         //Packhash(myMsg);
         }
         if(TOS_NODE_ID==myMsg->dest){
         TCPpack payload;
            
             uint16_t i =0,j=0;
              uint8_t A =0;
                 uint16_t size = call SocketsTable.size();
              
              pack p,msg;
              
              fd = getfdmsg(myMsg->src);
      memcpy(payload.payload, myMsg->payload, sizeof( myMsg->payload)*1);
                temp = call SocketsTable.get(fd); 
     
  // dbg(TRANSPORT_CHANNEL,"Message From: %s \n", myMsg->payload);
   //====================================================================================================================================
   
   for(i;i<=size;i++){
temp2 = call SocketsTable.get(i);
if(temp2.dest.addr==myMsg->src){
while(temp.user[A]!=32){
						p.payload[A] = temp.user[A];
						A++;
						}


 makePack(&sendPackage, TOS_NODE_ID, myMsg->seq, 3, PROTOCOL_Server, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								 forwarding(&sendPackage);
								  makePack(&sendPackage, TOS_NODE_ID, myMsg->seq, 3, PROTOCOL_Server, 7, myMsg->payload, PACKET_MAX_PAYLOAD_SIZE);
								 forwarding(&sendPackage);
					}
					}
   
   
   
   
   //====================================================================================================================================



}
      
      
  }    
      
      
      
      
      
       if(myMsg->protocol==PROTOCOL_Server){ 
             //--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                        
              if( TOS_NODE_ID!=myMsg->dest){              
           forwarding(myMsg);         
         //Packhash(myMsg);
         }
         if(TOS_NODE_ID==myMsg->dest){
             TCPpack payload;
            
             uint16_t i =0,j=0;
              uint8_t A =0;
              pack p,msg;
              
              fd = getfdmsg(myMsg->src);
      memcpy(payload.payload, myMsg->payload, sizeof( myMsg->payload)*1);
                temp = call SocketsTable.get(fd); 
                if(temp.TYPE==SERVER){
//-------------------------------------------------------------------------------------------------------------------cmd104 actural 109               
if (payload.payload[2] =104){

//sending the message to all

uint16_t size = call SocketsTable.size();

for(i;i<=size;i++){
temp2 = call SocketsTable.get(i);
if(temp2.dest.addr!=temp.dest.addr){
while(temp.user[A]!=32){
						p.payload[A] = temp.user[A];
						A++;
						}


 makePack(&sendPackage, TOS_NODE_ID, temp2.dest.addr, 3, PROTOCOL_Server, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								 forwarding(&sendPackage);
					
					A=0;
					while(j<102){
         
          
 		msg.payload[j]=myMsg->payload[6+j];
	
	
	
	
	if(myMsg->payload[6+j]==13){
	j=102;
	
	}
	j++;
			}
					
							   
								   
		makePack(&sendPackage, TOS_NODE_ID, temp2.dest.addr, 3, PROTOCOL_Server, 104, msg.payload, PACKET_MAX_PAYLOAD_SIZE);
								  forwarding(&sendPackage);						   
								   
								   
}


}




} 




     
}
  //---------------------------------------------------------------------------------------------------------------------------------end of cmd 104
  
  //-----------------------------------------------------------------------------------------------------------------------------------cmd 109
  
  
  
 //-----------------------------------------------------------------------------------------------------------------------------------cmd end 109
 if(temp.TYPE==CLIENT){
 if(myMsg->seq==0){
   dbg(TRANSPORT_CHANNEL,"Message From: %s \n", myMsg->payload);
   }else{
   
   dbg(TRANSPORT_CHANNEL,"Message: %s \n", myMsg->payload);
   
   }
      printf("\n");
   
   }


      }
      }
      
      
      
         
         
            if(myMsg->protocol==PROTOCOL_TCPDATA){ 
                        
              if( TOS_NODE_ID!=myMsg->dest){              
           forwarding(myMsg);         
         //Packhash(myMsg);
         }
         if(TOS_NODE_ID==myMsg->dest){
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
             if(myMsg->payload[2]==Fin_Flag){
                  dbg(TRANSPORT_CHANNEL,"FIN FLAG for Port (%d)\n",temp.src.port );
           
                  
   // dbg(TRANSPORT_CHANNEL,"Reading last Data for Port (%d): ", temp.src.port);
    
   for(i; i<myMsg->payload[5];i++){
   
   
   	  //
   	  
   	//   dbg(TRANSPORT_CHANNEL,"------------------------next expected %d \n",  temp.nextExpected);
   
if(myMsg->payload[3] !=104){
	  temp.rcvdBuff[i] = myMsg->payload[i+6]; //copy payload into received buffer
	  }else{
	  
	  temp.user[i]=myMsg->payload[i+6];
	  	  	  	  	//dbg(TRANSPORT_CHANNEL,"user %c\n", temp.user[i]);
	  
	  }
	  //printf("%c,",temp.rcvdBuff[i]);
	 temp.lastRead = temp.rcvdBuff[i];
	 temp.state=ESTABLISHED;
	 // temp.nextExpected = temp.rcvdBuff[i]+1;
	  // dbg(TRANSPORT_CHANNEL,"next expected %d \n",  temp.nextExpected);

	 
   
   }
          dbg(TRANSPORT_CHANNEL," ----------------------(%c): ....destport:.%d, fd:%d\n", temp.user[0], temp.dest.port,fd);
   
     //dbg(TRANSPORT_CHANNEL,"Reading Data: ");
  printf("\n" );
	  
	 		
   p.payload[0]=temp.dest.port;
     p.payload[1]=temp.src.port;
       p.payload[2]=Fin_Ack_Flag;
         p.payload[3]= temp.lastRead;
    p.payload[4]=  temp.nextExpected;
   temp.effectiveWindow=myMsg->payload[5];
    
    call SocketsTable.remove(fd);
        call SocketsTable.insert(fd, temp);
    makePack(&sendPackage, TOS_NODE_ID,myMsg->src , 3, PROTOCOL_TCPDATA, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
						forwarding(&sendPackage);
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
                  
             
             
             
             
             
             
             }
              
            if(myMsg->payload[2]==Data_Flag){
  

    dbg(TRANSPORT_CHANNEL,"Reading Data for Port (%d): ", temp.src.port);
   
   for(i; i<=temp.effectiveWindow;i++){
   
   
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
            
       if(myMsg->payload[2]==Fin_Ack_Flag){
                  fd = getfdmsg(myMsg->src);
            temp.lastAck = myMsg->payload[3];
            call SocketsTable.remove(fd);
        call SocketsTable.insert(fd, temp);
                            	//	 dbg(TRANSPORT_CHANNEL, "---------- last bit rec %d\n ",   temp.lastAck);
                            		       //  call TCPtimer.startOneShot(12000);
                if(temp.lastAck!=temp.Transfer_Buffer){            		 
          //EstablishedSend();
            }
            else{
             dbg(TRANSPORT_CHANNEL, "ALL DATA RECIEVED\n");
                      dbg(TRANSPORT_CHANNEL, "READY TO CLOSE \n");
             temp.state = CLOSED;
                                   dbg(TRANSPORT_CHANNEL, "CLIENT CLOSED \n");
             
             call SocketsTable.remove(fd);
        call SocketsTable.insert(fd, temp);
             
            
            }
            }
    
    
    
    
    
    
    
            break;
            default:
            
           	break;
            }
                           // call TCPtimer.startOneShot(12000);
            
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

void printusers(){

 socket_store_t temp;
      uint16_t destport, srcport, flag, ACK, seq, Awindow;
  pack p;
uint16_t size = call SocketsTable.size();
   uint16_t i =1;
      uint16_t j;
         uint16_t k=0;
    
            dbg(TRANSPORT_CHANNEL, "listUsrRply ");

				for(i; i<=size;i++){
				j=0;
 				temp = call SocketsTable.get(i);
						if(temp.state==ESTABLISHED){
						
						while(temp.user[j]!=32){
						printf("%c",temp.user[j]);
						j++;
						}
												printf(", ");
						
						}
						}
																		printf("\r\n");
						
						

}
//-----------------------------------------------------------------------------------------------------------------------------------------
 
 void TCPCHAT_SEND(uint8_t *payload, uint8_t CMD,pack p){
  socket_store_t temp;
      uint16_t destport, srcport, flag, ACK, seq, Awindow,i=0, j=0,k=0;
//fill in payload and send
temp = call SocketsTable.get(1);

Awindow = (temp.Transfer_Buffer-temp.lastAck)%16;


for(i;i< Awindow;i++){
if(CMD==109){
p.payload[i+6]= payload[4+j];
j++;
}

}
if(CMD==109){
	 makePack(&sendPackage, TOS_NODE_ID, temp.dest.addr, 3, PROTOCOL_Server, CMD, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								   forwarding(&sendPackage);
 }
 
 if(CMD==119){
 for(i;i< Awindow;i++){
if(CMD==109){
p.payload[i+6]= payload[4+j];
j++;
}

}
 
 
	// makePack(&sendPackage, TOS_NODE_ID, 1, 3, PROTOCOL_Server, CMD, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								   //forwarding(&sendPackage);
 }
 
 
 
 }
 
 
 
 
 void TCPchat(uint8_t *payload, uint8_t CMD, uint8_t destination){
  socket_store_t temp;
      uint16_t destport, srcport, flag, ACK, seq, Awindow,whitespace1=0, end=0,i=0,j=0;
  pack p;
temp = call SocketsTable.get(1);
 p.payload[0] = 41;
  p.payload[1] = temp.src.port;
   p.payload[2] = CMD;
    p.payload[3] = 0;
     p.payload[4] = 1;
 //-----------------------------------------------cmd 109
if(CMD==109){

while(end<1){
           // dbg(TRANSPORT_CHANNEL, "%d---------------------\n", payload[i]);

if(payload[i]==32 && whitespace1==0){
whitespace1=i;


}
if(payload[i]==13){
end=i;

}
i++;
}

        p.payload[5] = 0;
temp.Transfer_Buffer = (end-whitespace1);
call SocketsTable.remove(1);
call SocketsTable.insert(1, temp);
 TCPCHAT_SEND(payload, CMD, p);

}




 
 //-----------------------------------------------119
 
 
 if(CMD==119){
 
 while(end<1){
            //dbg(TRANSPORT_CHANNEL, "%d---------------------\n", payload[i]);

if(payload[i]==32 && whitespace1==0){
whitespace1=i;
            dbg(TRANSPORT_CHANNEL, "%d-whitespace 2\n", i);

}
if(payload[i]==32 && whitespace1!=0){
whitespace1=i;
          //  dbg(TRANSPORT_CHANNEL, "%d-whitespace 2\n", i);


}
if(whitespace1!=0){

p.payload[j] = payload[i];

}
if(payload[i]==13){
end=i;

}
i++;
}
 
         
temp.Transfer_Buffer = (end-whitespace1);
dbg(TRANSPORT_CHANNEL, "%d\n", temp.Transfer_Buffer);
call SocketsTable.remove(1);
call SocketsTable.insert(1, temp);

  makePack(&sendPackage, TOS_NODE_ID, 1, 3, PROTOCOL_Server, destination, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								   forwarding(&sendPackage);
 
 
 }
 
 //----------------------------------------------
 }





   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
  socket_store_t temp;
  pack p;
      uint16_t destport, srcport, flag, ACK, seq, Awindow,whitespace1=0, end=0,i=0,j=0;
   //-----------------------
   if(payload[0]==104){
      dbg(TRANSPORT_CHANNEL, "%s", payload );
            dbg(TRANSPORT_CHANNEL, "establishing connection to server....\n" );
         //  signal CommandHandler.setTestClient(1, 41, destination, 104);
       
       signal  CommandHandler.setAppClient(payload,  destination);
      }
      
     //-------------------------------------------------------------------------
     if(payload[0]==108){
         //   dbg(TRANSPORT_CHANNEL, "%s________________ CMD: %d\n", payload ,payload[0]);
      printusers();
      }
      
      
              if(payload[0]==109){
              // dbg(TRANSPORT_CHANNEL, "%s________________ CMD: %d\n", payload ,payload[0]);
              
TCPchat(payload, payload[0], destination);
      }
      
      
      if(payload[0]==119){      
       while(end<1){
            //dbg(TRANSPORT_CHANNEL, "%c---------------------%d\n", p.payload[j],j);

if(payload[i]==32){
whitespace1++;

}
if(payload[i]==13){
end=i;

}
if(whitespace1>=2&&end<1){

p.payload[j] = payload[i];
j++;
           // dbg(TRANSPORT_CHANNEL, "%c\n", p.payload[j]);

}

i++;
}
 
         
temp.Transfer_Buffer = (end-whitespace1);
dbg(TRANSPORT_CHANNEL, "%s\n", payload);


  makePack(&sendPackage, TOS_NODE_ID, 1, 3, PROTOCOL_whisper, destination, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								   forwarding(&sendPackage);
      
      
      
      
      
      }
      
      
      
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
   if(temp.TYPE == SERVER){

   
    if(temp.src.port == payload.payload[0]&& temp.dest.port==0){
       //  dbg(TRANSPORT_CHANNEL,"Connections   %d\n", i);
    return i;
    
    
    }
   
   
   
   }else{
return i;
      }
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
         uint16_t st=0;

				for(i; i<=size;i++){
 				temp = call SocketsTable.get(i);
						if(temp.state==ESTABLISHED){
						
						//----------------------------------------flag ===104
         				                
         				 if(temp.flag ==104){
         				 j = temp.lastAck;
         				for(k;k<temp.effectiveWindow;k++){
         				p.payload[k+6]=Gpayload[k+j+6];
         				         				// dbg(TRANSPORT_CHANNEL, "filling up payload with %c \n", p.payload[k+6]);
         				
         				if(k+j==temp.Transfer_Buffer-1){
         				         				         				         				 //dbg(TRANSPORT_CHANNEL, "%d\n", k+j);
         				
         				st = k;
         				break;
         				}
         				}
         				
         			p.payload[0] = temp.dest.port;
         			p.payload[1] = temp.src.port;
         			if(st==0){
         			p.payload[2] =  Data_Flag;
         			}else{
         			p.payload[2] =  Fin_Flag;
         			
         			}
         			p.payload[3] = temp.flag;
         			p.payload[4] = 0;
         			p.payload[5] = temp.effectiveWindow;
         				 makePack(&sendPackage, TOS_NODE_ID, temp.dest.addr, 3, PROTOCOL_TCPDATA, 0, p.payload, PACKET_MAX_PAYLOAD_SIZE);
								   forwarding(&sendPackage);
         				 
         				 }
						
							
//--------------------------------------------------------------------------------------


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
   uint16_t size;
       socket_t fd;
   
  if(call SocketsTable.size()<= MAX_NUM_OF_SOCKETS){
  
  fd = call SocketsTable.size()+1;
        dbg(TRANSPORT_CHANNEL, "%d---------------\n", fd);
  
   socket.addr = TOS_NODE_ID;
   socket.port = port;
   tempsocket.src = socket;
        tempsocket.TYPE= SERVER;
                tempsocket.nextExpected= 1;
                tempsocket.lastRead=0;
        tempsocket.dest.port=0;
         tempsocket.lastRead = 0;
     call SocketsTable.insert(fd, tempsocket);

      
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
                //call TCPtimer.startOneShot(12000);
                
     }
     
     
  
 
   
   }
   
    event void CommandHandler.ClientClose(uint16_t dest, uint16_t destPort, uint16_t srcPort){
	socket_addr_t socket_address;
      socket_addr_t socket_server;
        socket_store_t tempsocket;
         socket_t fd;
        tempsocket =  call Transport.getSocket(fd);
        if(tempsocket.lastAck==tempsocket.Transfer_Buffer){
              dbg(TRANSPORT_CHANNEL, "Client Closed %d!\n", srcPort);
        
        
        
        }
	 
	 
	 }

   event void CommandHandler.setAppServer(uint8_t *payload, uint16_t srcPort){



   
   }

   event void CommandHandler.setAppClient(uint8_t *payload, uint16_t srcPort){
   uint8_t cmd;
   socket_addr_t socket_address;
      socket_addr_t socket_server;
        socket_store_t tempsocket;
   socket_t fd = call Transport.socket();
   uint8_t user[20]={0};
uint8_t whitespaces=0,i=0,j=0,w=0;
cmd = payload[0];


   socket_address.addr = TOS_NODE_ID;
   socket_address.port = srcPort;
   socket_server.addr = 1;
   socket_server.port = 41;
    if(call Transport.bindClient(fd, &socket_address, &socket_server) == SUCCESS){
       dbg(TRANSPORT_CHANNEL, "Client: Binding to port: %d!\n", srcPort);
       //get socket
     tempsocket =  call Transport.getSocket(fd);
            //dbg(TRANSPORT_CHANNEL, "src port..%d!\n",fd );
      tempsocket.state = SYN_SENT;
      tempsocket.TYPE= CLIENT;
      tempsocket.lastAck=0;
      call SocketsTable.insert(fd, tempsocket);
                }
tempsocket = call SocketsTable.get(1);

 call SocketsTable.remove(1);


                    dbg(TRANSPORT_CHANNEL, "SEND COMMAND---------------- %d!\n", tempsocket.dest.port);
                                        dbg(TRANSPORT_CHANNEL, "SEND COMMAND %c!\n", payload[12]);
                    

               dbg(TRANSPORT_CHANNEL, "SEND COMMAND %d!\n", cmd);
                    if(cmd == 104){
                  while(whitespaces<2){
               
               
               // dbg(TRANSPORT_CHANNEL, "Payload[%d] =%c!\n", i,payload[i]);
                  
                  if(payload[i]==32){
                  whitespaces++;
                  if(whitespaces==1&&w==0){
                  w=i;
                  }
                  }
                                    i++;
                  }
                  i--;
          dbg(TRANSPORT_CHANNEL, "First Whitespace found at: %d Second whitespace found at %d!\n", w,i);
                  tempsocket.Transfer_Buffer = i-w;
                  tempsocket.flag = 104;
                        tempsocket.effectiveWindow=tempsocket.Transfer_Buffer%16;
                  
                       call SocketsTable.insert(1, tempsocket);
                            synPacket(1,  41,  srcPort, 1, tempsocket.effectiveWindow);
                                memcpy(Gpayload, payload, 20);
                            
                                  call TCPtimer.startOneShot(12000);
                  
                    }
                                     
                    
                    }
      
   
   
   
   

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