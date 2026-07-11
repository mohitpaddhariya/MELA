// mela_hub — dumb WebSocket relay. No AI, no authority. A message passer with a log.
//
// Protocol (FROZEN — see CLAUDE.md):
//   client -> HELLO {station}            -> hub replies SNAPSHOT {cards:[...]}
//   client -> CARD_UPSERT {card}         -> hub keeps newer updated_at, broadcasts to ALL
//   client -> MATCH_CANDIDATE {...}      -> broadcast to ALL
//   client -> RESOLVE {card_id, by}      -> broadcast to ALL (hub marks card resolved too)
//
// Run: node server.js         Laptop LAN IP: ipconfig getifaddr en0
const { WebSocketServer, WebSocket } = require('ws');

const PORT = 8765;
const cards = new Map(); // id -> card object (in-memory; hub is not the authority)
const stations = new Map(); // ws -> station name

const wss = new WebSocketServer({ host: '0.0.0.0', port: PORT });

const now = () => new Date().toTimeString().slice(0, 8);
const log = (...a) => console.log(`[${now()}]`, ...a);

function broadcast(obj, except = null) {
  const raw = JSON.stringify(obj);
  for (const client of wss.clients) {
    if (client !== except && client.readyState === WebSocket.OPEN) client.send(raw);
  }
}

wss.on('connection', (ws, req) => {
  log(`connect ${req.socket.remoteAddress}`);
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(data); } catch { return log('bad json, dropped'); }

    switch (msg.type) {
      case 'HELLO': {
        stations.set(ws, msg.station || '?');
        log(`HELLO from station ${msg.station} — snapshot ${cards.size} cards`);
        ws.send(JSON.stringify({ type: 'SNAPSHOT', cards: [...cards.values()] }));
        break;
      }
      case 'CARD_UPSERT': {
        const card = msg.card;
        if (!card || !card.id) return log('CARD_UPSERT without card.id, dropped');
        const prev = cards.get(card.id);
        if (prev && prev.updated_at > card.updated_at) {
          log(`upsert ${card.id} STALE (kept newer local) — echoing newer back`);
          ws.send(JSON.stringify({ type: 'CARD_UPSERT', card: prev }));
          return;
        }
        cards.set(card.id, card);
        log(`upsert ${card.id} [${card.kind}/${card.status}] from ${stations.get(ws) || '?'}`);
        broadcast(msg, ws); // sender already has it
        break;
      }
      case 'MATCH_CANDIDATE': {
        log(`MATCH_CANDIDATE for ${msg.card_id} at ${msg.found_at}`);
        broadcast(msg, ws);
        break;
      }
      case 'RESOLVE': {
        log(`RESOLVE ${msg.card_id} by ${msg.by}`);
        const c = cards.get(msg.card_id);
        if (c) { c.status = 'resolved'; c.updated_at = Math.floor(Date.now() / 1000); }
        broadcast(msg, ws);
        break;
      }
      default:
        log(`unknown type ${msg.type}, dropped`);
    }
  });

  ws.on('close', () => {
    log(`disconnect station ${stations.get(ws) || '?'}`);
    stations.delete(ws);
  });
  ws.on('error', (e) => log(`ws error: ${e.message}`));
});

// Heartbeat: drop dead phone connections so broadcasts don't stall.
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 10_000);

log(`mela_hub listening on ws://0.0.0.0:${PORT}`);
