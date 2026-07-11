// mela_hub — dumb WebSocket relay. No AI, no authority. Stage 2 fills in the protocol.
// Run: node server.js   (laptop LAN IP: `ipconfig getifaddr en0`)
const { WebSocketServer } = require('ws');

const PORT = 8765;
const wss = new WebSocketServer({ host: '0.0.0.0', port: PORT });

wss.on('connection', (ws, req) => {
  console.log(`[hub] connected: ${req.socket.remoteAddress}`);
  ws.on('message', (data) => {
    console.log(`[hub] recv: ${data}`);
    // Stage 2: HELLO -> SNAPSHOT, CARD_UPSERT/MATCH_CANDIDATE/RESOLVE -> broadcast
  });
  ws.on('close', () => console.log('[hub] disconnected'));
});

console.log(`[hub] listening on ws://0.0.0.0:${PORT}`);
