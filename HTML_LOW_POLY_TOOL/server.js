import express from 'express';
import Anthropic from '@anthropic-ai/sdk';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

if (!process.env.ANTHROPIC_API_KEY) {
  console.error('\n  ERROR: ANTHROPIC_API_KEY environment variable is not set.\n');
  process.exit(1);
}

const anthropic = new Anthropic();
const app = express();
app.use(express.json());
app.use(express.static(__dirname));

const SYSTEM_PROMPT = `You are a 3D low-poly model generator. When given a description, you generate a JSON object describing a low-poly 3D mesh.

CRITICAL: Respond ONLY with a valid JSON object. No markdown code blocks, no explanations, no extra text whatsoever.

Required JSON format:
{
  "name": "descriptive name of the model",
  "vertices": [[x, y, z], ...],
  "faces": [
    {"indices": [a, b, c], "color": "#RRGGBB"},
    ...
  ]
}

Design guidelines:
- Use 30-80 vertices for a genuine low-poly aesthetic
- All faces must be triangles (exactly 3 vertex indices each, zero-based)
- Vertices should fit within [-1.5, 1.5] on all axes
- Center the model near the origin (0, 0, 0)
- Use harmonious, vibrant colors appropriate to the object and style
- Aim for 40-120 triangular faces so the shape reads clearly
- Make the model immediately recognizable and well-proportioned
- Use different shades/tints on adjacent faces to give the model visual depth`;

app.post('/api/generate', async (req, res) => {
  const { description, style } = req.body;

  if (!description?.trim()) {
    return res.status(400).json({ error: 'Description is required' });
  }

  const userMsg = style
    ? `Generate a low-poly 3D model of: ${description}\nStyle: ${style}`
    : `Generate a low-poly 3D model of: ${description}`;

  try {
    const message = await anthropic.messages.create({
      model: 'claude-opus-4-7',
      max_tokens: 8192,
      system: SYSTEM_PROMPT,
      messages: [{ role: 'user', content: userMsg }],
    });

    const raw = message.content[0].text.trim();

    // Strip any accidental markdown fences
    const jsonMatch = raw.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('Response contained no JSON object');

    const modelData = JSON.parse(jsonMatch[0]);

    if (!Array.isArray(modelData.vertices) || !Array.isArray(modelData.faces)) {
      throw new Error('Model data is missing vertices or faces arrays');
    }

    console.log(`Generated: "${modelData.name}" — ${modelData.vertices.length}v ${modelData.faces.length}f`);
    res.json(modelData);

  } catch (err) {
    console.error('Generation error:', err.message);
    if (err instanceof SyntaxError) {
      res.status(500).json({ error: 'Model generation returned invalid JSON — please try again.' });
    } else {
      res.status(500).json({ error: err.message });
    }
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`\n  Low-Poly Model Generator → http://localhost:${PORT}\n`);
});
