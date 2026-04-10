import { fetchWT, sb, logSync, json, hashContent } from './lib/shared.js';
import { buildSystemPrompt, validateArticle, buildLiveContext, SEASON_CONTEXT } from './lib/accuracy.js';

const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY;
const WORD_TARGETS = {
  breaking: '150-200', race_recap: '450-500', qualifying_recap: '350-400', practice_analysis: '300-350',
  preview: '400-450', strategy_analysis: '350-400', championship_update: '250-300', morning_briefing: '300-350', analysis: '400-500',
};

export default async (req, context) => {
  const start = Date.now();
  try {
    if (!ANTHROPIC_KEY) throw new Error('ANTHROPIC_API_KEY not set');

    // 1. Get highest priority pending topic
    let topics = await sb('content_topics?status=eq.pending&order=priority.desc&limit=1');
    let topic = topics[0];
    let contentType = topic?.content_type || 'analysis';
    let topicText = topic?.topic || 'F1 2026 Season Analysis';

    if (!topic) {
      const hour = new Date().getUTCHours();
      if (hour < 8) { contentType = 'morning_briefing'; topicText = 'Morning Briefing'; }
      else {
        await logSync('generate-content', 'success', 0, 'No pending topics', Date.now() - start);
        return json({ ok: true, generated: 0 });
      }
    }

    // 2. Build context — picksContext FIRST (never change this order)
    const picks = await sb('betting_picks?status=eq.active&order=created_at.desc&limit=10');
    let picksContext = '';
    if (picks.length) {
      picksContext = 'CURRENT PICKS:\n' + picks.map(p => `${p.pick_type}: ${p.driver_name} ${p.odds} — ${p.analysis || ''}`).join('\n');
    }

    // Live driver data from driver_facts
    const liveContext = await buildLiveContext();

    // Leaderboard
    const board = await sb('leaderboard?order=fetched_at.desc,position.asc&limit=10');
    const boardText = board.length ? 'LATEST SESSION:\n' + board.map(r => `P${r.position}: ${r.driver_name} (${r.team_name})`).join('\n') : '';

    const contextBlock = [liveContext, boardText].filter(Boolean).join('\n\n');
    const fullContext = [picksContext, contextBlock].filter(Boolean).join('\n\n');

    // 3. Build prompt with full accuracy guards
    const wordTarget = WORD_TARGETS[contentType] || '400-500';
    const systemPrompt = buildSystemPrompt(`OUTPUT: Return ONLY valid JSON with no markdown fences:\n{"title":"...","excerpt":"first 150 chars","body":"full article","tags":["RACE"],"content_type":"${contentType}"}`);

    const userPrompt = `Write a ${contentType.replace(/_/g, ' ')} article. Topic: ${topicText}\n\n${fullContext}\n\nTarget: ${wordTarget} words. JSON only.`;

    // 4. Call Claude
    const response = await fetchWT('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'x-api-key': ANTHROPIC_KEY, 'anthropic-version': '2023-06-01', 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: 'claude-haiku-4-5-20251001', max_tokens: 1500, system: systemPrompt, messages: [{ role: 'user', content: userPrompt }] }),
    }, 25000);

    const rJson = await response.json();
    const text = rJson.content?.[0]?.text || '';

    // 5. Parse JSON
    let parsed;
    try {
      const clean = text.replace(/```json\s*/g, '').replace(/```\s*/g, '');
      parsed = JSON.parse(clean.match(/\{[\s\S]*\}/)?.[0] || clean);
    } catch {
      parsed = { title: topicText, body: text, excerpt: text.slice(0, 150), tags: ['ANALYSIS'], content_type: contentType };
    }

    // 6. VALIDATION — reject hallucinated content
    const validation = validateArticle(parsed);
    if (!validation.valid) {
      console.error('[GridFeed] Validation failed:', validation.reason);
      await logSync('generate-content', 'validation_failed', 0, validation.reason, Date.now() - start);
      return json({ ok: true, generated: 0, skipped: 'Validation failed', reason: validation.reason });
    }

    // 7. Dedup check
    const h = hashContent(parsed.body || '');
    const existing = await sb(`content_hashes?hash=eq.${h}&limit=1`);
    if (existing.length) {
      await logSync('generate-content', 'success', 0, 'Duplicate content skipped', Date.now() - start);
      return json({ ok: true, generated: 0, reason: 'duplicate' });
    }

    // 8. Insert draft
    await sb('content_drafts', 'POST', {
      title: parsed.title, body: parsed.body, excerpt: parsed.excerpt,
      tags: parsed.tags || ['ANALYSIS'], content_type: parsed.content_type || contentType,
      review_status: 'pending', source_context: { topic: topicText, context_length: fullContext.length },
      priority_score: topic?.priority || 5, generation_model: 'claude-haiku-4-5-20251001',
      race_id: topic?.race_id || null,
    });

    // 9. Hash + topic update
    await sb('content_hashes', 'POST', { hash: h, type: contentType, source: 'generate-content' });
    if (topic?.id) await sb(`content_topics?id=eq.${topic.id}`, 'PATCH', { status: 'drafted' });

    // 10. Notify (fire and forget)
    fetchWT('/.netlify/functions/notify-draft', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ title: parsed.title, content_type: contentType, priority_score: topic?.priority || 5, excerpt: (parsed.excerpt || '').slice(0, 200) }) }, 5000).catch(() => {});

    await logSync('generate-content', 'success', 1, `Draft: "${parsed.title}" (${contentType})`, Date.now() - start);
    return json({ ok: true, generated: 1, title: parsed.title });
  } catch (err) {
    await logSync('generate-content', 'error', 0, err.message, Date.now() - start, err.stack);
    return json({ error: err.message }, 500);
  }
};

export const config = { schedule: '*/30 * * * *' };
