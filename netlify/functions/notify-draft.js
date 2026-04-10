import { fetchWT, logSync, json } from './lib/shared.js';

export default async (req, context) => {
  const start = Date.now();
  try {
    let body;
    try { body = await req.json(); } catch { return json({ ok: true, skipped: 'No body' }); }

    const score = body.priority_score || 0;
    const emoji = score >= 12 ? '\ud83d\udea8' : score >= 7 ? '\u26a1' : '\ud83d\udcdd';

    // Send push notification only
    const siteUrl = process.env.URL || 'https://gridfeed.co';
    await fetchWT(siteUrl + '/.netlify/functions/send-push', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        title: `${emoji} ${body.content_type || 'Draft'}`,
        body: body.title || 'New draft ready for review',
        url: '/gf-admin-drafts',
        priority: score,
      }),
    }, 8000);

    await logSync('notify-draft', 'success', 1, `Push sent: ${body.title || 'draft'}`, Date.now() - start);
    return json({ ok: true, push: true });
  } catch (err) {
    await logSync('notify-draft', 'error', 0, err.message, Date.now() - start);
    return json({ ok: true, error: err.message });
  }
};
