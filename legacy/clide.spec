# -*- mode: python ; coding: utf-8 -*-
"""PyInstaller spec file for Clide.

Cross-platform configuration that produces:
- macOS: .app bundle (universal2 for Intel + Apple Silicon)
- Linux: Single executable (for AppImage packaging)
- Windows: Single executable (for Inno Setup packaging)
"""

import sys

block_cipher = None

# Collect data files
datas = [
    ('clide/templates', 'clide/templates'),  # Skill templates (SKILL.md files)
]

# Hidden imports for dynamic modules
hiddenimports = [
    # Textual internals
    'textual._context',
    'textual.css',
    # Tree-sitter grammars
    'tree_sitter_python',
    'tree_sitter_javascript',
    'tree_sitter_typescript',
    'tree_sitter_html',
    'tree_sitter_css',
    'tree_sitter_json',
    'tree_sitter_yaml',
    'tree_sitter_toml',
    'tree_sitter_markdown',
    'tree_sitter_rust',
    'tree_sitter_go',
    'tree_sitter_java',
    'tree_sitter_bash',
    # Watchdog backends
    'watchdog.observers.fsevents',  # macOS
    'watchdog.observers.inotify',   # Linux
    'watchdog.observers.read_directory_changes',  # Windows
    # Pydantic
    'pydantic',
    'pydantic_settings',
    # Vendored pyte
    'clide.vendor.pyte',
]

# Exclude dev/test dependencies
excludes = [
    'pytest',
    'mypy',
    'ruff',
    'pre_commit',
    'pytest_asyncio',
    'pytest_textual_snapshot',
    'pytest_cov',
]

a = Analysis(
    ['clide/__main__.py'],
    pathex=[],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=excludes,
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, cipher=block_cipher)

# Platform-specific executable settings
if sys.platform == 'darwin':
    # macOS: Create .app bundle
    # Use CLIDE_UNIVERSAL=1 env var for universal binary (requires fat Python)
    import os
    target_arch = 'universal2' if os.environ.get('CLIDE_UNIVERSAL') else None

    exe = EXE(
        pyz,
        a.scripts,
        [],
        exclude_binaries=True,
        name='clide',
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=False,  # UPX breaks macOS code signing
        console=True,
        target_arch=target_arch,
    )
    coll = COLLECT(
        exe,
        a.binaries,
        a.datas,
        strip=False,
        upx=False,
        name='Clide',
    )
    app = BUNDLE(
        coll,
        name='Clide.app',
        icon=None,  # TODO: Add icon.icns
        bundle_identifier='net.schweitz.clide',
        info_plist={
            'CFBundleShortVersionString': '1.0.0',
            'CFBundleName': 'Clide',
            'CFBundleDisplayName': 'Clide',
            'NSHighResolutionCapable': True,
            'LSEnvironment': {
                'TERM': 'xterm-256color',
            },
        },
    )
elif sys.platform == 'win32':
    # Windows: Single executable
    exe = EXE(
        pyz,
        a.scripts,
        a.binaries,
        a.datas,
        [],
        name='clide',
        debug=False,
        bootloader_ignore_signals=False,
        strip=False,
        upx=True,
        console=True,
        icon=None,  # TODO: Add icon.ico
    )
else:
    # Linux: Single executable (for AppImage packaging)
    exe = EXE(
        pyz,
        a.scripts,
        a.binaries,
        a.datas,
        [],
        name='clide',
        debug=False,
        bootloader_ignore_signals=False,
        strip=True,
        upx=True,
        console=True,
    )
