import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { initSupabase } from "../../shared/supabaseServer.ts";

export default async function (req: Request) {
  try {
    const base44 = createClientFromRequest(req);
    const { user } = await initSupabase(req);
    if (!user) return Response.json({ error: 'Unauthorized' }, { status: 401 });
    if (user.role !== 'admin') return Response.json({ error: 'Admin access required' }, { status: 403 });

    const { accessToken } = await base44.asServiceRole.connectors.getConnection('instagram');
    if (!accessToken) return Response.json({ error: 'Instagram not connected' }, { status: 400 });

    // Get Instagram user
    const userRes = await fetch(`https://graph.instagram.com/me?fields=id,username&access_token=${accessToken}`);
    const igUser = await userRes.json();
    if (igUser.error) return Response.json({ error: igUser.error.message }, { status: 502 });

    // Get recent media (25 posts)
    const mediaRes = await fetch(
      `https://graph.instagram.com/${igUser.id}/media?fields=id,caption,media_type,media_url,thumbnail_url,permalink,timestamp,like_count,comments_count&limit=25&access_token=${accessToken}`
    );
    const mediaData = await mediaRes.json();
    const posts = mediaData.data || [];

    // Fetch comments for top 10 posts
    const postsWithComments = await Promise.all(
      posts.slice(0, 10).map(async (post) => {
        if (!post.comments_count) return { ...post, comments: [] };
        try {
          const commentsRes = await fetch(
            `https://graph.instagram.com/${post.id}/comments?fields=id,text,timestamp,username&access_token=${accessToken}`
          );
          const commentsData = await commentsRes.json();
          return { ...post, comments: commentsData.data || [] };
        } catch {
          return { ...post, comments: [] };
        }
      })
    );

    const allComments = postsWithComments
      .flatMap((p) => (p.comments || []).map((c) => c.text || ''))
      .filter(Boolean);

    // Prepare condensed data for LLM
    const postsForLLM = postsWithComments.map((p) => ({
      caption: (p.caption || '').slice(0, 300),
      likes: p.like_count || 0,
      comments: p.comments_count || 0,
      timestamp: p.timestamp,
      permalink: p.permalink,
      comment_texts: (p.comments || []).map((c) => c.text || ''),
    }));

    const analysis = await base44.asServiceRole.integrations.Core.InvokeLLM({
      prompt: `You are analyzing Instagram data for @${igUser.username}, a health research education account run by a student researcher.

Recent posts with metrics and their comments:
${JSON.stringify(postsForLLM)}

Analyze this data and provide:
1. SENTIMENT: Break down comment sentiment into positive/neutral/negative percentages (must total 100). Identify 3-5 key themes in what people are saying. Write a 2-3 sentence summary.
2. ENGAGEMENT: Identify the top 3-5 best-performing posts (by combined likes + comments). For each, include caption, likes, comments, permalink, and a short reason it resonated. Write a trends summary noting what content type performs best.
3. FEEDBACK: Summarize what the community is saying in 2-3 sentences. List common questions people ask (3-5). List actionable feedback for the account (3-5 items).

Be specific, concise, and helpful. This is a health education account — keep the tone supportive and non-clinical.`,
      response_json_schema: {
        type: 'object',
        properties: {
          sentiment: {
            type: 'object',
            properties: {
              summary: { type: 'string' },
              positive_pct: { type: 'number' },
              neutral_pct: { type: 'number' },
              negative_pct: { type: 'number' },
              themes: { type: 'array', items: { type: 'string' } },
            },
            required: ['summary', 'positive_pct', 'neutral_pct', 'negative_pct', 'themes'],
          },
          engagement: {
            type: 'object',
            properties: {
              summary: { type: 'string' },
              top_posts: {
                type: 'array',
                items: {
                  type: 'object',
                  properties: {
                    caption: { type: 'string' },
                    likes: { type: 'number' },
                    comments: { type: 'number' },
                    permalink: { type: 'string' },
                    why: { type: 'string' },
                  },
                },
              },
              trends: { type: 'string' },
            },
            required: ['summary', 'top_posts', 'trends'],
          },
          feedback: {
            type: 'object',
            properties: {
              summary: { type: 'string' },
              common_questions: { type: 'array', items: { type: 'string' } },
              actionable: { type: 'array', items: { type: 'string' } },
            },
            required: ['summary', 'common_questions', 'actionable'],
          },
        },
        required: ['sentiment', 'engagement', 'feedback'],
      },
    });

    return Response.json({
      username: igUser.username,
      postCount: posts.length,
      totalComments: allComments.length,
      posts: postsWithComments.map((p) => ({
        id: p.id,
        caption: p.caption,
        permalink: p.permalink,
        timestamp: p.timestamp,
        like_count: p.like_count || 0,
        comments_count: p.comments_count || 0,
        media_type: p.media_type,
        media_url: p.media_url,
        thumbnail_url: p.thumbnail_url,
        comments: (p.comments || []).map((c) => ({ text: c.text, timestamp: c.timestamp, username: c.username })),
      })),
      analysis,
    });
  } catch (error) {
    console.error('instagram-insights error:', error);
    return Response.json({ error: error.message }, { status: 500 });
  }
}