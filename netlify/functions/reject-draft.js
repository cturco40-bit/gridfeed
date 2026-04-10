import { sb, logSync, json } from './lib/shared.js';

export default async (req) => {
  const start = Date.now();
  try {
    const body = await req.json();
    const { id, type } = body;
    if (!id) return json({ error: 'Missing id' }, 400);

    if (type === 'tweet') {
      await sb(`tweets?id=eq.${id}`, 'PATCH', { status: 'failed' });
    } else {
      await sb(`content_drafts?id=eq.${id}`, 'PATCH', { review_status: 'rejected', reviewed_at: new Date().toISOString(), reviewed_by: 'admin' });
    }

    await logSync('reject-draft', 'success', 1, `Rejected ${type || 'draft'} ${id}`, Date.now() - start);
    return json({ ok: true });
  } catch (err) {
    return json({ error: err.message }, 500);
  }
};
