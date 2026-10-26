"""Reject microscopic text and action styles before Flutter/browser review.

Run from any directory: python tools/qa/check_ui_contract.py
This is a source guard, not a substitute for the painted-size widget/browser QA.
"""
from pathlib import Path
import re
import sys
import subprocess

ROOT = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, str(ROOT / 'tools/sync_version.py'), '--check'], check=True)
subprocess.run([sys.executable, str(ROOT / 'tools/center_ui_text.py'), '--check'], check=True)
errors = []


def fail(path, source, offset, message):
    line = source.count('\n', 0, offset) + 1
    errors.append(f'{path.relative_to(ROOT)}:{line}: {message}')


def calls(source, name):
    # Mask strings/comments without changing offsets before balancing calls.
    masked = re.sub(r"//[^\n]*|/\*[\s\S]*?\*/|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\"",
                    lambda m: ' ' * len(m[0]), source)
    for start in re.finditer(r'\b' + name + r'(?:\.\w+)?\s*\(', masked):
        pos = start.end()
        depth = 1
        while pos < len(masked) and depth:
            depth += (masked[pos] == '(') - (masked[pos] == ')')
            pos += 1
        yield start.start(), source[start.start():pos]


files = sorted((ROOT / 'lib/ui').rglob('*.dart')) + [ROOT / 'lib/main.dart']
for path in files:
    source = path.read_text(encoding='utf-8')
    for match in re.finditer(r'fontSize:\s*(\d+(?:\.\d+)?)\b', source):
        if float(match[1]) < 12:
            fail(path, source, match.start(), 'Text below 12px; use the documented role and reflow layout.')
    if path.name == 'game_ui.dart':
        continue  # Its painted dimensions/text are asserted by ui_contract_test.
    for match in re.finditer(r'(?:minimumSize|fixedSize):\s*(?:const\s+)?Size\(\s*\d+(?:\.\d+)?\s*,\s*(\d+(?:\.\d+)?)', source):
        if float(match[1]) < 48:
            fail(path, source, match.start(), 'Action height below 48px; keep the documented role minimum.')
    for button in ['FilledButton', 'OutlinedButton']:
        for offset, block in calls(source, button):
            for match in re.finditer(r'fontSize:\s*(\d+(?:\.\d+)?)\b', block):
                if float(match[1]) < 15:
                    fail(path, source, offset + match.start(), 'Action text below 15px; use GameUi.compactButton for cells.')
            for icon_offset, icon in calls(block, 'RasterIcon'):
                match = re.search(r'\bsize:\s*(\d+(?:\.\d+)?)\b', icon)
                if match and float(match[1]) < 28:
                    fail(path, source, offset + icon_offset, 'Action icon below 28px (major decisions require 32/36px).')
            # v12.15: a compact row button (받기 / 출격 / a price) may scale its
            # one short label into the cell; main decisions still wrap and grow.
            if re.search(r'TextOverflow\.(?:ellipsis|fade)', block) or (
                    re.search(r'\bFittedBox\s*\(', block)
                    and 'GameUi.compactButton' not in block):
                fail(path, source, offset, 'Do not shrink or truncate an action label; wrap and grow.')

# v12.9: every screen title bar is the shared game bar, never a plain AppBar.
for path in sorted((ROOT / 'lib/ui').rglob('*.dart')):
    if re.search(r'appBar:\s*AppBar\(', path.read_text(encoding='utf-8')):
        errors.append(f'{path.name}: use GameAppBar for screen title bars')

# Critical decisions must keep the shared bounded component, not a local style.
battle = (ROOT / 'lib/ui/battle.dart').read_text(encoding='utf-8')
decisions = battle[battle.index('  Widget _pausePanel()'):]
if re.search(r'\b(?:FilledButton|OutlinedButton)\s*[.(]', decisions):
    errors.append('battle decisions must use GameActionButton')
# v12.4.3 user rule: pause/result are one fixed page (no pager, no scroll);
# secondary facts live in the result's reward popup.
if 'GamePages(' in decisions or 'return _scrim(' not in decisions or 'Widget _result()' not in decisions or decisions.count('GameActionButton(') + decisions.count('AdOfferButton(') < 3 or "label: '조작·음향 설정'" not in decisions or "label: '보상 내역'" not in decisions or 'AdOfferButton(' not in decisions or 'AdOffer.runBonus' not in decisions:
    errors.append('pause/result must retain bounded decisions, shared actions, battle save/receipt and the configured optional reward action')
for filename, marker in [('fixed_lobby.dart', "key: const Key('launch')")]:
    source = (ROOT / 'lib/ui' / filename).read_text(encoding='utf-8')
    if not any(marker in block for _, block in calls(source, 'GameActionButton')):
        errors.append(f'{filename}: launch must use GameActionButton')

# These detail flows have been brought onto the full dialog/action contract.
for filename in ['pet_bond_screen.dart', 'daily_challenge_screen.dart',
                 'catalog_screens.dart', 'collection_screen.dart', 'guild_screen.dart',
                 'hangar_presets.dart', 'campaign_selector.dart',
                 'account_screen.dart', 'settings_screen.dart', 'evolution_codex.dart']:
    source = (ROOT / 'lib/ui' / filename).read_text(encoding='utf-8')
    # v12.15: compact row buttons (GameUi.compactButton) are the shared
    # mobile-game cell action; any other local button style is not.
    if re.search(r'\b(?:OutlinedButton|TextButton|RasterAlertDialog)\s*\(', source) or any(
            'GameUi.compactButton' not in block for _, block in calls(source, 'FilledButton')):
        errors.append(f'{filename}: use shared decisions, choice tiles and GameDialog throughout')
for filename in ['fleet_activity_screen.dart', 'daily_challenge_screen.dart', 'content_hub.dart']:
    if 'claimWithRewardPopup(' not in (ROOT / 'lib/ui' / filename).read_text(encoding='utf-8'):
        errors.append(f'{filename}: successful earned rewards must present an actual receipt')

# An overview/detail/form/modal may never scroll. Only audited repeated item
# viewports may instantiate a ListView; adding another requires a list audit.
item_lists = {
    'settings_screen.dart': 2,   # license package entries; one license's paragraphs in its popup
    'item_slots.dart': 1,        # shared repeated 3+ column item rows only
    'evolution_codex.dart': 0,    # shared item slots
    'collection_screen.dart': 0,
    'catalog_screens.dart': 0,
    'campaign_selector.dart': 1, # chapter choices
    'battle.dart': 0,            # fixed choice slots; pause/result are fixed pages
    'home.dart': 0,              # preparation uses fixed pages; slots own item scrolling
    'hangar_presets.dart': 0,
    'ship_hangar.dart': 0,
    'guild_screen.dart': 1,      # members or recruiting guild entries only; forms use GamePages
    'daily_challenge_screen.dart': 1, # difficulty and exchange items
    'fleet_activity_screen.dart': 4, # attendance board, quest rows, house rewards, patrol rows
    'guardian_quest_screen.dart': 1, # achievement rows
    'game_pages.dart': 1,        # GameItemList: damage/build/challenge entries
}
for path in (ROOT / 'lib/ui').glob('*.dart'):
    source = path.read_text(encoding='utf-8')
    if re.search(r'\b(?:SingleChildScrollView|CustomScrollView|GridView|Scrollable|PageView)\s*\(', source):
        errors.append(f'{path.name}: generic scroll containers are forbidden; use fixed pages or audited item lists')
    if len(list(calls(source, 'ListView'))) != item_lists.get(path.name, 0):
        errors.append(f'{path.name}: item list inventory changed; verify that only repeated items scroll')
lobby = (ROOT / 'lib/ui/fixed_lobby.dart').read_text(encoding='utf-8')
if re.search(r'\b(?:ListView|Scrollable|GamePages|GameItemList|PageView)\s*\(', lobby):
    errors.append('fixed_lobby.dart: every lobby control must fit one fixed board')
dialog = (ROOT / 'lib/ui/game_dialog.dart').read_text(encoding='utf-8')
if 'GamePages(' not in dialog:
    errors.append('GameDialog must retain fixed pages and a persistent close control')
for filename in ['pet_bond_screen.dart']:
    source = (ROOT / 'lib/ui' / filename).read_text(encoding='utf-8')
    for _, notice in calls(source, 'SnackBar'):
        margin = re.search(r'EdgeInsets\.fromLTRB\(\s*[\d.]+,\s*[\d.]+,\s*[\d.]+,\s*([\d.]+)', notice)
        if 'SnackBarBehavior.floating' not in notice or not margin or float(margin[1]) < 80:
            errors.append(f'{filename}: growth notices must leave the fixed page controls clear (80px bottom margin)')

guide = (ROOT / 'lib/ui/components.dart').read_text(encoding='utf-8').split('Future<void> showGuide(', 1)[1]
if 'GameDialog(' not in guide or re.search(r'\b(?:FilledButton|OutlinedButton|TextButton|RasterAlertDialog)\s*[.(]', guide):
    errors.append('flight guide must retain GameDialog and shared decisions')
home = (ROOT / 'lib/ui/home.dart').read_text(encoding='utf-8')
if 'BuildVersionFooter' in home or 'AppVersion.label' in home:
    errors.append('home must not show a version footer; compiled version belongs in settings')
settings = (ROOT / 'lib/ui/settings_screen.dart').read_text(encoding='utf-8')
if 'AppVersion.label' not in settings or "Key('settings-version')" not in settings:
    errors.append('settings must retain the compiled version and developer authentication entry')
if 'showFlightSettings(context, p)' not in home or 'showLicensePage(' in home:
    errors.append('home settings must use the audited fixed-page settings/license flow')

if errors:
    print('\n'.join(errors))
    sys.exit(1)
print(f'UI contract passed: {len(files)} files; text floor, action labels/icons, bounded decisions.')
