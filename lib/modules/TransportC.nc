#include "../../includes/socket.h"
#include "../../includes/packet.h"
#include "../../includes/sendInfo.h"
#include "../../includes/channels.h"

configuration TransportC{
   provides interface Transport;
}


implementation{
    components TransportP;
    Transport = TransportP;


}