interface CommandHandler{
   // Events
   event void ping(uint16_t destination, uint8_t *payload);
   event void printNeighbors();
   event void printRouteTable();
   event void printLinkState();
   event void printDistanceVector();
   event void setTestServer(uint16_t  port);
   event void setTestClient(uint16_t dest, uint16_t destPort, uint16_t srcPort, uint16_t transfer);
   event void ClientClose(uint16_t dest, uint16_t destPort, uint16_t srcPort);
   event void setAppServer(uint8_t *payload, uint16_t srcPort);
   event void setAppClient(uint8_t *payload, uint16_t srcPort);
}
