#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

configuration TransportC{
   provides interface Transport;
   //provides interface Node;
}


implementation{
    components TransportP;
    Transport = TransportP;

components new HashmapC(socket_store_t,10) as SocketsTable;
TransportP.SocketsTable -> SocketsTable;	



}