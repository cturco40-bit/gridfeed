import { sb, logSync, json, makeSlug } from './lib/shared.js';
import { fixEncoding } from './lib/accuracy.js';

export default async (req) => {
  const start = Date.now();
  try {
    const body = await req.json();
    const { id, title, articleBody, excerpt, tags } = body;

    if (!id) return json({ error: 'Missing draft id' }, 400);
    if (!articleBody) return json({ error: 'Article body is empty' }, 400);

    const cleanTitle = fixEncoding(title || 'Untitled');
    const cleanBody = fixEncoding(articleBody || '');
    const cleanExcerpt = fixEncoding(excerpt || '');
    const slug = makeSlug(cleanTitle);

    // 1. Insert into articles (service role key — bypasses RLS)
    const article = await sb('articles', 'POST', {
      title: cleanTitle, slug, body: cleanBody, excerpt: cleanExcerpt,
      tags: tags || ['ANALYSIS'], author: 'GridFeed Staff',
      status: 'published', published_at: new Date().toISOString(),
    });

    const articleId = Array.isArray(article) ? article[0]?.id : article?.id;
    if (!articleId) {
      await logSync('approve-draft', 'error', 0, 'Article insert failed for: ' + cleanTitle, Date.now() - start);
      return json({ error: 'Publish failed' }, 500);
    }

    // 2. Update draft status
    await sb(`content_drafts?id=eq.${id}`, 'PATCH', {
      review_status: 'approved', reviewed_at: new Date().toISOString(), reviewed_by: 'admin',
      published_article_id: articleId, title: cleanTitle, body: cleanBody, excerpt: cleanExcerpt, tags,
    });

    await logSync('approve-draft', 'success', 1, `Published: "${cleanTitle}"`, Date.now() - start);
    return json({ ok: true, articleId, slug });
  } catch (err) {
    await logSync('approve-draft', 'error', 0, err.message, Date.now() - start);
    return json({ error: err.message }, 500);
  }
};
