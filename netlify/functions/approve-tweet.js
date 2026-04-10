import { sb, logSync, json } from './lib/shared.js';

export default async (req) => {
  const start = Date.now();
  try {
    const body = await req.json();
    const { id, tweet_text } = body;
    if (!id) return json({ error: 'Missing tweet id' }, 400);

    if (tweet_text) await sb(`tweets?id=eq.${id}`, 'PATCH', { tweet_text });
    await sb(`tweets?id=eq.${id}`, 'PATCH', { status: 'approved' });

    await logSync('approve-tweet', 'success', 1, `Approved tweet ${id}`, Date.now() - start);
    return json({ ok: true });
  } catch (err) {
    await logSync('approve-tweet', 'error', 0, err.message, Date.now() - start);
    return json({ error: err.message }, 500);
  }
};
