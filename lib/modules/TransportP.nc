
#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"
#define MAX_NUM_OF_SOCKETS 10


module TransportP
{
   provides interface Transport;

 
}
implementation{

command socket_t Transport.socket(){
    socket_t fd;
    socket_store_t SOC;
   
    return fd;
  }








}