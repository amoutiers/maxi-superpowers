/**
 * Maxi plugin for OpenCode.ai
 *
 * Injects maxi bootstrap context via system prompt transform.
 * Auto-registers skills directory via config hook (no symlinks needed).
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const stripFrontmatter = (content) => {
  const match = content.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
  return match ? match[1] : content;
};

// Normalize a path: trim whitespace, expand ~, resolve to absolute
const normalizePath = (p, homeDir) => {
  if (!p || typeof p !== 'string') return null;
  let normalized = p.trim();
  if (!normalized) return null;
  if (normalized.startsWith('~/')) {
    normalized = path.join(homeDir, normalized.slice(2));
  } else if (normalized === '~') {
    normalized = homeDir;
  }
  return path.resolve(normalized);
};

// Module-level cache for bootstrap content, keyed by project directory.
// The SKILL.md file does not change during a session, so reading + parsing it
// once per project eliminates redundant fs.existsSync + fs.readFileSync + regex
// work on every agent step.
const _bootstrapCacheByProject = new Map();

export const MaxiPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();
  const maxiSkillsDir = path.resolve(__dirname, '../../skills');
  const envConfigDir = normalizePath(process.env.OPENCODE_CONFIG_DIR, homeDir);
  const configDir = envConfigDir || path.join(homeDir, '.config/opencode');

  // Helper to generate bootstrap content (cached after first call)
  const getBootstrapContent = () => {
    // Only inject in maxi projects — skip in projects without docs/maxi/.
    // Derive from the project `directory` (passed to MaxiPlugin); fall back to
    // process.cwd() only if the host did not provide it.
    const baseDir = directory || process.cwd();
    const cacheKey = path.resolve(baseDir);
    if (_bootstrapCacheByProject.has(cacheKey)) return _bootstrapCacheByProject.get(cacheKey);

    const maxiDir = path.join(baseDir, 'docs/maxi');
    let isMaxiProject = false;
    try {
      isMaxiProject = fs.statSync(maxiDir).isDirectory();
    } catch {}
    if (!isMaxiProject) {
      _bootstrapCacheByProject.set(cacheKey, null);
      return null;
    }

    // Try to load using-maxi skill
    const skillPath = path.join(maxiSkillsDir, 'using-maxi', 'SKILL.md');
    if (!fs.existsSync(skillPath)) {
      _bootstrapCacheByProject.set(cacheKey, null);
      return null;
    }

    const fullContent = fs.readFileSync(skillPath, 'utf8');
    const content = stripFrontmatter(fullContent);

    const toolMapping = `**Tool Mapping for OpenCode:**
When skills reference tools you don't have, substitute OpenCode equivalents:
- \`TodoWrite\` → \`todowrite\`
- \`Task\` tool with subagents → Use OpenCode's subagent system (@mention)
- \`Skill\` tool → OpenCode's native \`skill\` tool
- \`Read\`, \`Write\`, \`Edit\`, \`Bash\` → Your native tools

Use OpenCode's native \`skill\` tool to list and load skills.`;

    const bootstrap = `<EXTREMELY_IMPORTANT>
You have maxi.

**Below is the full content of your 'maxi:using-maxi' skill - your introduction to the maxi spec-driven pipeline. For all other maxi skills, use the 'Skill' tool:**

${content}

${toolMapping}
</EXTREMELY_IMPORTANT>`;

    _bootstrapCacheByProject.set(cacheKey, bootstrap);
    return bootstrap;
  };

  return {
    // Inject skills path into live config so OpenCode discovers maxi skills
    // without requiring manual symlinks or config file edits.
    // This works because Config.get() returns a cached singleton — modifications
    // here are visible when skills are lazily discovered later.
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];
      if (!config.skills.paths.includes(maxiSkillsDir)) {
        config.skills.paths.push(maxiSkillsDir);
      }
    },

    // Inject bootstrap into the first user message of each session.
    // Using a user message instead of a system message avoids:
    //   1. Token bloat from system messages repeated every turn
    //   2. Multiple system messages breaking Qwen and other models
    //
    // The hook fires on every agent step (not just every turn) because
    // opencode's prompt.ts reloads messages from DB each step.  Fresh message
    // arrays may need injection again, so getBootstrapContent() must not do
    // repeated disk work.
    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;
      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      // Guard: skip if first user message already contains bootstrap.
      // This prevents double injection when OpenCode passes an already
      // transformed in-memory message array through the hook again.
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('EXTREMELY_IMPORTANT'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
