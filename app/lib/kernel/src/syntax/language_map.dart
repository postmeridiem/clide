/// Maps file extensions and special filenames to grammar asset names.
library;

String? grammarForPath(String path) {
  final name = path.split('/').last;
  final special = _filenameMap[name];
  if (special != null) return special;

  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = name.substring(dot).toLowerCase();
  return _extMap[ext];
}

const _filenameMap = <String, String>{
  'Makefile': 'make',
  'makefile': 'make',
  'GNUmakefile': 'make',
  'Dockerfile': 'dockerfile',
  'dockerfile': 'dockerfile',
  '.gitignore': 'gitignore',
  '.gitconfig': 'git-config',
  '.gitmodules': 'git-config',
  'justfile': 'just',
  'Justfile': 'just',
};

const _extMap = <String, String>{
  // Systems
  '.c': 'c',
  '.h': 'c',
  '.cpp': 'cpp',
  '.cxx': 'cpp',
  '.cc': 'cpp',
  '.hpp': 'cpp',
  '.hxx': 'cpp',
  '.cs': 'c-sharp',

  // Application
  '.dart': 'dart',
  '.go': 'go',
  '.rs': 'rust',
  '.java': 'java',
  '.kt': 'kotlin',
  '.kts': 'kotlin',
  '.swift': 'swift',
  '.rb': 'ruby',
  '.py': 'python',
  '.pyw': 'python',
  '.ex': 'elixir',
  '.exs': 'elixir',
  '.erl': 'erlang',
  '.hrl': 'erlang',
  '.hs': 'haskell',
  '.lhs': 'haskell',
  '.jl': 'julia',
  '.r': 'r',
  '.R': 'r',
  '.zig': 'zig',
  '.nix': 'nix',
  '.lua': 'lua',
  '.php': 'php',
  '.nkl': 'nickel',

  // Web
  '.js': 'javascript',
  '.mjs': 'javascript',
  '.cjs': 'javascript',
  '.jsx': 'javascript',
  '.ts': 'typescript',
  '.tsx': 'typescript',
  '.html': 'html',
  '.htm': 'html',
  '.css': 'css',
  '.svelte': 'svelte',
  '.vue': 'vue',

  // Data / Config
  '.json': 'json',
  '.yaml': 'yaml',
  '.yml': 'yaml',
  '.toml': 'toml',
  '.xml': 'xml',
  '.svg': 'xml',
  '.plist': 'xml',
  '.hcl': 'hcl',
  '.tf': 'hcl',
  '.tfvars': 'hcl',
  '.proto': 'proto',
  '.regex': 'regex',

  // Markdown
  '.md': 'markdown',
  '.mdx': 'markdown',
  '.markdown': 'markdown',

  // Shell
  '.sh': 'bash',
  '.bash': 'bash',
  '.zsh': 'bash',
  '.fish': 'bash',

  // Game dev
  '.gd': 'gdscript',
  '.glsl': 'glsl',
  '.vert': 'glsl',
  '.frag': 'glsl',
  '.hlsl': 'hlsl',
  '.wgsl': 'wgsl',

  // Data / Query
  '.sql': 'sqlite',
  '.sqlite': 'sqlite',

  // Other
  '.diff': 'diff',
  '.patch': 'diff',
};
