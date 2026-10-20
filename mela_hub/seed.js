// Demo staging: inject realistic cards through the NORMAL sync protocol.
// Run AFTER the hub is up:  node seed.js [ws://127.0.0.1:8765]
const WebSocket = require('ws');

const url = process.argv[2] || 'ws://127.0.0.1:8765';
const now = Math.floor(Date.now() / 1000);

const card = (o) => ({
  station: 'A', status: 'open', clothing_bottom: 'unknown', hair: 'unknown',
  marks: 'unknown', glasses: 'unknown', notes: '', ...o,
});

const cards = [
  card({ id: 'A-97', kind: 'lost', updated_at: now - 5400, age_range: '4-6',
    gender: 'female', name_response: 'Guddi', clothing_top: 'pink frock',
    hair: 'two plaits', last_seen: 'Triveni Ghat seedhi' }),
  card({ id: 'A-98', kind: 'lost', updated_at: now - 4100, age_range: '60-70',
    gender: 'female', name_response: 'Kamla Devi', clothing_top: 'green saree',
    glasses: 'none', marks: 'walking stick', last_seen: 'annakshetra line' }),
  card({ id: 'B-61', kind: 'lost', updated_at: now - 3300, age_range: '8-10',
    gender: 'male', name_response: 'Raju', clothing_top: 'blue shirt',
    clothing_bottom: 'khaki shorts', last_seen: 'Ram Ghat parking',
    station: 'B' }),
  card({ id: 'B-62', kind: 'found', updated_at: now - 2500, age_range: '60-70',
    gender: 'female', clothing_top: 'green saree', glasses: 'none',
    marks: 'walking stick', station: 'B', status: 'candidate' }),
  card({ id: 'A-99', kind: 'lost', updated_at: now - 1200, age_range: '5-7',
    gender: 'male', name_response: 'Chotu', clothing_top: 'red kurta',
    glasses: 'black frame', last_seen: 'Ram Ghat' }),
  card({ id: 'B-59', kind: 'found', updated_at: now - 7200, age_range: '4-6',
    gender: 'female', clothing_top: 'pink frock', hair: 'two plaits',
    station: 'B', status: 'resolved' }),
];

const ws = new WebSocket(url);
ws.on('open', () => {
  ws.send(JSON.stringify({ type: 'HELLO', station: 'seeder' }));
  for (const c of cards) {
    ws.send(JSON.stringify({ type: 'CARD_UPSERT', card: c }));
  }
  console.log(`seeded ${cards.length} cards -> ${url}`);
  setTimeout(() => process.exit(0), 500);
});
ws.on('error', (e) => { console.error('seed failed:', e.message); process.exit(1); });
