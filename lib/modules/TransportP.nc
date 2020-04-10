
#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#define MAX_NUM_OF_SOCKETS 10


module TransportP
{
   provides interface Transport;

    uses interface Hashmap<socket_store_t> as SocketsTable;
 	uses interface SimpleSend as Sender;
}
implementation{

command socket_t Transport.socket(){
    socket_t fd;
   socket_store_t socket;
    uint16_t size;
if(call SocketsTable.size()<= MAX_NUM_OF_SOCKETS){

fd = call SocketsTable.size()+1;


socket.fd=fd;

call SocketsTable.insert(fd, socket);

 dbg(TRANSPORT_CHANNEL,"fd %d .\n", fd);


      
    }
    else
    {
      dbg(TRANSPORT_CHANNEL, "No Available Socket: return NULL\n");
      fd = NULL;
    }
    return fd;
  }
  
   /**
    * Bind a socket with an address.
    * @param
    *    socket_t fd: file descriptor that is associated with the socket
    *       you are binding.
    * @param
    *    socket_addr_t *addr: the source port and source address that
    *       you are biding to the socket, fd.
    * @Side Client/Server
    * @return error_t - SUCCESS if you were able to bind this socket, FAIL
    *       if you were unable to bind.
    */
  
   
    command error_t Transport.bindS(socket_t fd, socket_addr_t *addr){
   socket_store_t temp;
   socket_addr_t temp_addy;
   error_t e;
   bool suc = FALSE;
   uint16_t size = call SocketsTable.size();
   uint8_t i =1;
   if(call SocketsTable.isEmpty()){
   return e = FAIL;
   
   }
   
   for(i;i<=size;i++){
   
   temp = call SocketsTable.get(i);
   call SocketsTable.remove(i);
   if(temp.fd ==fd&&!suc){
   suc = TRUE;
   temp_addy.port = addr->port;
      temp_addy.addr = addr->addr;
      temp.src=temp_addy;
   }
    call SocketsTable.insert(i, temp);
   }
       //  dbg(TRANSPORT_CHANNEL, "size of table %d \n", temp.fd);
   
      if(suc) return e = SUCCESS;
    else      return e = FAIL;
  }
  
 //-------------------------------------------------------------------------------------------------------
  
      command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
   socket_store_t temp;
   socket_addr_t temp_addy;
   error_t e;
   bool suc = FALSE;
   uint16_t size = call SocketsTable.size();
   uint8_t i =1;
   if(call SocketsTable.isEmpty()){
   return e = FAIL;
   
   }
   
   for(i;i<=size;i++){
   
   temp = call SocketsTable.get(i);
   call SocketsTable.remove(i);
   if(temp.fd ==fd&&!suc){
   suc = TRUE;
   temp_addy.port = addr->port;
      temp_addy.addr = addr->addr;
      temp.dest=temp_addy;
   }
    call SocketsTable.insert(i, temp);
   }
   
      if(suc) return e = SUCCESS;
    else      return e = FAIL;
  }
//------------------------------------------------------------------------------------------------------------------

  command error_t Transport.listen(socket_t fd){
    socket_store_t temp;
 error_t e;
    uint16_t size = call SocketsTable.size();
 bool suc = FALSE;
   uint8_t i =0;
   if(call SocketsTable.isEmpty()){
   return e = FAIL;
   
   }
       for(i;i<=size;i++){
   
   temp = call SocketsTable.get(i);
      call SocketsTable.remove(i);
   if(temp.fd ==fd&&!suc){
   suc = TRUE;
 temp.state =LISTEN;
 if(temp.state==LISTEN){
 dbg(TRANSPORT_CHANNEL,"fd %d ..... Changed state to %d\n", fd, temp.state);
 }
 
 call SocketsTable.insert(temp.fd,temp);
   }
   }

   if(suc) return e = SUCCESS;
    else      return e = FAIL;
  }

command error_t Transport.connect(socket_t fd, socket_addr_t * addr){

error_t e;
 socket_store_t temp;

pack synPack;
TCPpack* TCP_PACKET;

socket_store_t Socket;
TCP_PACKET = (TCPpack*)(synPack.payload);
TCP_PACKET->destport = Socket.dest.port;
TCP_PACKET ->srcport = Socket.src.port;
TCP_PACKET ->ACK =0;
TCP_PACKET ->seq =1;
TCP_PACKET->flag = SYN_Flag;

dbg(PROTOCOL_TCP, "NODE %u is in State %u \n", Socket.dest.addr, temp.state);
if(TCP_PACKET->seq!=1) return e = SUCCESS;
    else      return e = FAIL;

}





}