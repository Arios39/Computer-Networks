
#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#define MAX_NUM_OF_SOCKETS 10


module TransportP
{
   provides interface Transport;

    uses interface List<socket_store_t> as SocketsList;
 
}
implementation{

command socket_t Transport.socket(){
    socket_t fd;
   socket_store_t socket;
    if(call SocketsList.size() < MAX_NUM_OF_SOCKETS)
    {
      socket.fd = call SocketsList.size();
          //  dbg(TRANSPORT_CHANNEL, "Socket id %d\n", socket.fd);
      fd = call SocketsList.size();
      call SocketsList.pushback(socket);
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
  
    command error_t Transport.bind(socket_t fd, socket_addr_t *addr){
   socket_store_t temp;
   socket_addr_t temp_addy;
   error_t e;
   bool suc = FALSE;
   uint16_t size = call SocketsList.size();
   uint8_t i =0;
   if(call SocketsList.isEmpty()){
   return e = FAIL;
   
   }
   
   for(i;i<size;i++){
   
   temp = call SocketsList.get(i);
   if(temp.fd ==fd&&!suc){
   suc = TRUE;
   temp_addy.port = addr->port;
      temp_addy.addr = addr->addr;
      temp.dest=temp_addy;
   }
   }
      if(suc) return e = SUCCESS;
    else      return e = FAIL;
  }
  


  command error_t Transport.listen(socket_t fd){
    socket_store_t temp;
 error_t e;
    uint16_t size = call SocketsList.size();
 bool suc = FALSE;
   uint8_t i =0;
   if(call SocketsList.isEmpty()){
   return e = FAIL;
   
   }
       for(i;i<size;i++){
   
   temp = call SocketsList.get(i);
   if(temp.fd ==fd&&!suc){
   suc = TRUE;
 temp.state =LISTEN;
 if(temp.state==LISTEN){
 dbg(TRANSPORT_CHANNEL,"fd %d ..... Changed state to %d\n", fd, temp.state);
 }
 
 call SocketsList.pushback(temp);
   }
   }

   if(suc) return e = SUCCESS;
    else      return e = FAIL;
  
 
 
 
  }
  
  








}