/** Maxi plugin for OpenCode V1 and V2. */
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const skillsDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../skills');
const bootstrapCache = new Map();

const extractFrontmatter = (source) => {
  const match = source.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?([\s\S]*)$/);
  if (!match) return { frontmatter: {}, content: source };
  const frontmatter = {};
  let key;
  for (const raw of match[1].split('\n')) {
    const line = raw.replace(/\r$/, '');
    const colon = line.indexOf(':');
    if (colon > 0 && !/^\s/.test(line)) {
      key = line.slice(0, colon).trim();
      const value = line.slice(colon + 1).trim();
      frontmatter[key] = /^(>[+-]?|\|[+-]?)$/.test(value) ? '' : value;
    } else if (key && line.trim()) {
      frontmatter[key] = `${frontmatter[key]} ${line.trim()}`.trim();
    }
  }
  for (const name of Object.keys(frontmatter)) {
    frontmatter[name] = frontmatter[name].replace(/^(["'])([\s\S]*)\1$/, '$2');
  }
  return { frontmatter, content: match[2] };
};

const V1_MAPPING = `**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`todowrite\`
- \`Task\` tool with subagents → Use OpenCode's \`task\` tool with \`subagent_type: "general"\`
- \`Skill\` tool → OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Your native tools

Use OpenCode's native \`skill\` tool to list and load skills.`;

const V2_MAPPING = `**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → Track the plan in a markdown file
- \`Task\` tool with subagents → Use \`subagent\` with \`agent: "general"\`, \`description\` and \`prompt\`
- \`Skill\` tool → OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Use \`read\`, \`patch\`, \`write\`, \`edit\` or \`shell\`

Use OpenCode's native \`skill\` tool to list and load skills.`;

function bootstrap(mapping, directory) {
  if (typeof directory !== 'string' || !path.isAbsolute(directory)) return null;
  const base = path.resolve(directory);
  const key = `${mapping}\0${base}`;
  if (bootstrapCache.has(key)) return bootstrapCache.get(key);
  let enabled = false;
  try { enabled = fs.statSync(path.join(base, 'docs/maxi')).isDirectory(); } catch {}
  const skillPath = path.join(skillsDir, 'using-maxi', 'SKILL.md');
  if (!enabled || !fs.existsSync(skillPath)) {
    bootstrapCache.set(key, null);
    return null;
  }
  const { content } = extractFrontmatter(fs.readFileSync(skillPath, 'utf8'));
  const value = `<EXTREMELY_IMPORTANT>
You have maxi.

**Below is the full content of your 'maxi:using-maxi' skill - your introduction to the maxi spec-driven pipeline. For all other maxi skills, use the 'Skill' tool:**

${content}

${mapping}
</EXTREMELY_IMPORTANT>`;
  bootstrapCache.set(key, value);
  return value;
}

async function sessionInfo(fetch, id) {
  if (!id) return null;
  try {
    const result = await fetch(id);
    if (!result || typeof result !== 'object' || result.error || result.response?.ok === false) return null;
    const info = 'data' in result ? result.data : result;
    if (!info || info.id !== id || (info.parentID !== undefined &&
      (typeof info.parentID !== 'string' || !info.parentID))) return null;
    return info;
  } catch {
    return null;
  }
}

export const MaxiPlugin = async ({ client, directory }) => ({
  config: async (config) => {
    if (Array.isArray(config.skills)) return;
    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    if (!config.skills.paths.includes(skillsDir)) config.skills.paths.push(skillsDir);
  },
  'experimental.chat.messages.transform': async (_input, output) => {
    const first = output.messages?.find((m) => m.info.role === 'user');
    if (!first?.parts?.length) return;
    if (first.parts.some((p) => p.type === 'text' && p.text?.includes('EXTREMELY_IMPORTANT'))) return;
    const id = first.info.sessionID;
    const info = client?.session?.get && await sessionInfo((key) => client.session.get({ path: { id: key } }), id);
    if (!info || info.parentID) return;
    const text = bootstrap(V1_MAPPING, info.directory || directory);
    if (text) first.parts.unshift({ ...first.parts[0], type: 'text', text });
  },
});

async function setup(ctx) {
  if (!ctx?.skill || typeof ctx.skill.transform !== 'function' ||
      !ctx.session || typeof ctx.session.hook !== 'function') return;
  try {
    const skills = fs.readdirSync(skillsDir, { withFileTypes: true })
      .filter((entry) => entry.isDirectory() && !entry.name.startsWith('.'))
      .map((entry) => path.join(skillsDir, entry.name, 'SKILL.md'))
      .filter((file) => fs.existsSync(file))
      .map((file) => {
        const id = path.basename(path.dirname(file));
        const { frontmatter, content } = extractFrontmatter(fs.readFileSync(file, 'utf8'));
        return { id, name: frontmatter.name || id,
          ...(frontmatter.description ? { description: frontmatter.description } : {}),
          path: file, content };
      });
    await ctx.skill.transform((draft) => {
      for (const skill of skills) {
        try { draft.add(skill); }
        catch (error) { console.error(`[maxi] skill ${skill.id} rejected:`, error); }
      }
    });
  } catch (error) {
    console.error('[maxi] skill registration failed:', error);
  }
  try {
    await ctx.session.hook('context', async (event) => {
      try {
        if (!event.messages?.length || !event.sessionID) return;
        const first = event.messages.find((m) => m.role === 'user');
        if (first && !first.content?.length) return;
        if (first?.content.some((p) => p.type === 'text' && p.text?.includes('EXTREMELY_IMPORTANT'))) return;
        const info = await sessionInfo((id) => ctx.session.get({ sessionID: id }), event.sessionID);
        if (!info || info.parentID) return;
        const text = bootstrap(V2_MAPPING, info.location?.directory);
        if (!text) return;
        if (first) first.content.unshift({ type: 'text', text });
        else event.messages.push({ role: 'user', content: [{ type: 'text', text }] });
      } catch (error) {
        console.error('[maxi] context hook failed:', error);
      }
    });
  } catch (error) {
    console.error('[maxi] context hook registration failed:', error);
  }
}

export default { id: 'maxi', server: MaxiPlugin, setup };
