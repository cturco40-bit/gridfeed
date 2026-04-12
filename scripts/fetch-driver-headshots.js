import { writeFileSync, mkdirSync } from 'fs';

const OPENF1 = 'https://api.openf1.org/v1';
const drivers = [
  { num: 12, name: 'antonelli' },
  { num: 63, name: 'russell' },
  { num: 16, name: 'leclerc' },
  { num: 44, name: 'hamilton' },
  { num: 4, name: 'norris' },
  { num: 81, name: 'piastri' },
  { num: 1, name: 'verstappen' },
  { num: 20, name: 'hadjar' },
  { num: 14, name: 'alonso' },
  { num: 18, name: 'stroll' },
  { num: 10, name: 'gasly' },
  { num: 43, name: 'colapinto' },
  { num: 55, name: 'sainz' },
  { num: 23, name: 'albon' },
  { num: 31, name: 'ocon' },
  { num: 87, name: 'bearman' },
  { num: 30, name: 'lawson' },
  { num: 40, name: 'lindblad' },
  { num: 27, name: 'hulkenberg' },
  { num: 5, name: 'bortoleto' },
  { num: 11, name: 'perez' },
  { num: 77, name: 'bottas' }
];

mkdirSync('public/drivers', { recursive: true });

for (const driver of drivers) {
  const r = await fetch(OPENF1 + '/drivers?driver_number=' + driver.num);
  const data = await r.json();
  const headshot = data[data.length - 1]?.headshot_url;
  if (!headshot) {
    console.warn('No headshot for', driver.name);
    continue;
  }
  const img = await fetch(headshot);
  const buf = await img.arrayBuffer();
  writeFileSync('public/drivers/' + driver.name + '.png', Buffer.from(buf));
  console.log('Saved', driver.name);
}
