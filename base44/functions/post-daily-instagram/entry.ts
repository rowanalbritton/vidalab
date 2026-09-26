import { createClientFromRequest } from 'npm:@base44/sdk@0.8.44';
import { initSupabase } from "../../shared/supabaseServer.ts";

const SUBSTACK_URL = "https://vidalab.substack.com";

const STYLE_VARIATIONS = [
  'with soft watercolor textures and gentle gradients',
  'with clean vector-style illustration and crisp lines',
  'with delicate fine line art and subtle shading',
  'with abstract geometric patterns and modern composition',
  'with organic flowing shapes and natural forms',
  'with minimal scientific diagram aesthetics',
  'with subtle gradient washes and airy negative space',
  'with fine botanical illustration style and elegant detail',
  'with soft pastel layering and dreamy depth',
  'with structured editorial layout and refined typography motifs',
];

function buildImagePrompt(topic: any, type: string, styleVariation: string): string {
  const name = topic.name || topic.title;
  const summary = (topic.summary || topic.subtitle || '').slice(0, 200);

  const visualMotifs = type === 'condition'
    ? `subtle abstract biological or cellular motifs, stylized anatomical references, microscopic imagery`
    : `organic natural elements, soft geometric patterns, gentle abstract wellness imagery`;

  return `Create a square 1:1 Instagram post image for a health research education brand called VIDA LAB.
Topic: ${name}. ${summary}
Style: clean, minimal, aesthetic scientific illustration with editorial magazine quality, ${styleVariation}.
Color palette: warm cream background (#F9F8F5), forest green (#2E463E) and soft sky blue (#BDE0E9) accents, with touches of sage green.
Include ${visualMotifs} related to ${name}.
The image should feel calm, intelligent, and quietly feminine — like a wellness research journal cover.
Soft natural lighting, generous negative space, refined and modern.
No text, no words, no letters, no watermarks, no logos in the image. Pure illustration only.`;
}

function buildCaptionPrompt(topic: any, type: string): string {
  const name = topic.name || topic.title;
  const summary = (topic.summary || topic.subtitle || '').slice(0, 300);
  const detail = (topic.overview || topic.content || '').slice(0, 1500);
  const category = topic.category || '';

  const context = type === 'condition'
    ? `This post educates about the health condition "${name}" (category: ${category}). Summary: ${summary}. Key info: ${detail}`
    : `This post educates about the health topic "${name}" in the category "${category}". Subtitle: ${summary}. Content: ${detail}`;

  return `Write an Instagram caption for VIDA LAB, a health research education account run by a student researcher (not a doctor).
${context}

Requirements:
- 150-280 words, warm and accessible tone
- Open with a hook that makes someone stop scrolling — a surprising fact or thoughtful question
- Share 1-2 key insights about ${name} that most people don't know
- Be educational and curious, never diagnostic or prescriptive
- End with a soft call to action to read more on the Substack
- Include this exact line near the end: "Read more → ${SUBSTACK_URL}"
- Add 5-8 relevant hashtags at the very end, each on a new line
- Sound like a thoughtful student researcher who translates complex science into plain language
- Do NOT include medical advice, diagnosis, or treatment recommendations
- Do NOT start with "Hey" or "Hi" — jump straight into the hook

Return only the caption text, ready to post.`;
}

export default async function (req: Request) {
  try {
    const base44 = createClientFromRequest(req);
    const { user, serviceEntities } = await initSupabase(req);

    // If called with a user token, require admin. Workflow calls (no token) are allowed.
    if (user && user.role !== "admin") {
      return Response.json({ error: "Forbidden" }, { status: 403 });
    }

    // Get Instagram connection
    const { accessToken } = await base44.asServiceRole.connectors.getConnection('instagram');
    if (!accessToken) return Response.json({ error: 'Instagram not connected' }, { status: 400 });

    // Get Instagram user ID
    const userRes = await fetch(`https://graph.instagram.com/me?fields=id,username&access_token=${accessToken}`);
    const igUser = await userRes.json();
    if (igUser.error) return Response.json({ error: igUser.error.message }, { status: 502 });

    // Idempotency: skip if already posted today
    const mediaRes = await fetch(`https://graph.instagram.com/${igUser.id}/media?fields=id,timestamp&limit=1&access_token=${accessToken}`);
    const mediaData = await mediaRes.json();
    const lastPost = mediaData.data?.[0];
    if (lastPost) {
      const lastDate = new Date(lastPost.timestamp).toISOString().split('T')[0];
      const today = new Date().toISOString().split('T')[0];
      if (lastDate === today) {
        return Response.json({ skipped: true, reason: 'Already posted today' });
      }
    }

    // Pick topic: alternate between conditions and explainers by day
    const dayOfYear = Math.floor((Date.now() - new Date(new Date().getFullYear(), 0, 0).getTime()) / 86400000);
    const useCondition = dayOfYear % 2 === 0;
    const styleVariation = STYLE_VARIATIONS[dayOfYear % STYLE_VARIATIONS.length];

    let topic: any;
    let type: string;

    if (useCondition) {
      const conditions = await serviceEntities.DiseaseReport.list('-updated_date', 50);
      const publicOnes = conditions.filter((c: any) => c.is_public !== false);
      if (publicOnes.length === 0) return Response.json({ error: 'No public conditions available' }, { status: 404 });
      topic = publicOnes[Math.floor(Math.random() * publicOnes.length)];
      type = 'condition';
    } else {
      const explainers = await serviceEntities.Explainer.list('-updated_date', 50);
      const publicOnes = explainers.filter((e: any) => e.is_public !== false);
      if (publicOnes.length === 0) return Response.json({ error: 'No public explainers available' }, { status: 404 });
      topic = publicOnes[Math.floor(Math.random() * publicOnes.length)];
      type = 'explainer';
    }

    const topicName = topic.name || topic.title;
    console.log(`post-daily-instagram: selected ${type} "${topicName}"`);

    // Generate unique aesthetic image
    const imagePrompt = buildImagePrompt(topic, type, styleVariation);
    const imageResult = await base44.asServiceRole.integrations.Core.GenerateImage({ prompt: imagePrompt });
    const imageUrl = imageResult.url;
    if (!imageUrl) return Response.json({ error: 'Image generation failed' }, { status: 502 });
    console.log(`post-daily-instagram: image generated at ${imageUrl}`);

    // Generate thoughtful caption
    const captionResult = await base44.asServiceRole.integrations.Core.InvokeLLM({
      prompt: buildCaptionPrompt(topic, type),
      response_json_schema: {
        type: 'object',
        properties: {
          caption: { type: 'string' },
        },
        required: ['caption'],
      },
    });
    let caption = captionResult.caption || '';
    if (caption.length > 2200) caption = caption.slice(0, 2190) + '...';
    console.log(`post-daily-instagram: caption generated (${caption.length} chars)`);

    // Create media container on Instagram
    const createRes = await fetch(`https://graph.instagram.com/${igUser.id}/media?access_token=${accessToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        image_url: imageUrl,
        caption: caption,
      }),
    });
    const createData = await createRes.json();
    if (createData.error) {
      console.error('Instagram media creation failed:', createData.error);
      return Response.json({ error: createData.error.message }, { status: 502 });
    }
    const creationId = createData.id;
    console.log(`post-daily-instagram: media container created (${creationId})`);

    // Poll for media readiness (Instagram needs to fetch and process the image)
    let attempts = 0;
    let mediaStatus = 'IN_PROGRESS';
    while (mediaStatus !== 'FINISHED' && attempts < 12) {
      await new Promise((resolve) => setTimeout(resolve, 5000));
      const statusRes = await fetch(`https://graph.instagram.com/${creationId}?fields=status_code&access_token=${accessToken}`);
      const statusData = await statusRes.json();
      mediaStatus = statusData.status_code || 'IN_PROGRESS';
      attempts++;
    }
    if (mediaStatus !== 'FINISHED') {
      console.error('Instagram media processing timed out');
      return Response.json({ error: 'Media processing timed out', status: mediaStatus }, { status: 504 });
    }
    console.log(`post-daily-instagram: media ready after ${attempts * 5}s`);

    // Publish the media
    const publishRes = await fetch(`https://graph.instagram.com/${igUser.id}/media_publish?access_token=${accessToken}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creation_id: creationId,
      }),
    });
    const publishData = await publishRes.json();
    if (publishData.error) {
      console.error('Instagram publish failed:', publishData.error);
      return Response.json({ error: publishData.error.message }, { status: 502 });
    }

    console.log(`post-daily-instagram: posted to @${igUser.username} — "${topicName}" (${type}), post ID ${publishData.id}`);
    return Response.json({
      success: true,
      postId: publishData.id,
      username: igUser.username,
      topic: topicName,
      type,
      imageUrl,
    });
  } catch (error) {
    console.error('post-daily-instagram error:', error);
    return Response.json({ error: error.message }, { status: 500 });
  }
}