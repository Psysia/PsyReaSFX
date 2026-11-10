"""Compile a real Win32 regression against a candidate's corresponding source.

Only process-owned offscreen windows are created; REAPER is never launched.
The JSON report, not a text-pattern guess, decides whether a candidate may ship.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path)
parser.add_argument('--report', required=True, type=Path)
args = parser.parse_args()
result = {'compatible': False, 'status': 'unverified'}
try:
    locator = Path(os.environ.get('ProgramFiles(x86)', 'C:/Program Files (x86)')) / 'Microsoft Visual Studio/Installer/vswhere.exe'
    install = subprocess.check_output([str(locator), '-latest', '-products', '*', '-requires',
        'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'], text=True).strip()
    if not install:
        raise RuntimeError('MSVC x64 compiler unavailable; candidate remains unverified')
    args.report.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='prs-dock-', dir=args.report.parent.resolve()) as temporary:
        folder = Path(temporary)
        with zipfile.ZipFile(args.source) as archive:
            headers = [name for name in archive.namelist() if name.endswith('/src/platform/windows/win_dock_redraw.hpp')]
            if len(headers) != 1:
                raise RuntimeError('Unknown Docker implementation; manual compatibility review required')
            data = archive.read(headers[0])
        header = folder / 'platform/windows/win_dock_redraw.hpp'
        header.parent.mkdir(parents=True)
        header.write_bytes(data)
        result['header_sha256'] = hashlib.sha256(data).hexdigest()
        source = Path(__file__).with_name('windows_dock_redraw.cpp').resolve()
        vcvars = Path(install) / 'Common7/Tools/VsDevCmd.bat'
        for path in (folder, source, vcvars):
            if any(c in str(path) for c in '\r\n"%&|<>^'):
                raise RuntimeError('Unsupported build path')
        batch = folder / 'compile.cmd'
        batch.write_text(f'@echo off\ncall "{vcvars}" -no_logo -arch=x64 -host_arch=x64 >nul\n'
            'if errorlevel 1 exit /b 1\n'
            f'cl /nologo /EHsc /std:c++17 /DUNICODE /D_UNICODE /DNOMINMAX /I"{folder}" '
            f'"{source}" /Fe"{folder / "dock.exe"}" /link user32.lib comctl32.lib\n'
            'exit /b %errorlevel%\n', encoding='utf-8')
        built = subprocess.run([os.environ.get('COMSPEC', 'cmd.exe'), '/d', '/c', str(batch)],
            cwd=folder, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=90,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        if built.returncode:
            raise RuntimeError('Regression did not compile: ' + built.stdout[-3000:])
        checked = subprocess.run([str(folder / 'dock.exe')], cwd=folder, text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=20,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        result.update(compatible=checked.returncode == 0,
            status='passed' if checked.returncode == 0 else 'failed', detail=checked.stdout.strip())
except Exception as error:
    result['detail'] = str(error)
args.report.parent.mkdir(parents=True, exist_ok=True)
args.report.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result))
