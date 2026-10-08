"""Builds assets/quran/tajweed.json.gz from open tajweed annotations.

Sources (both downloaded by hand, see docs/gated-work.md):
  * cpfair/quran-tajweed output/tajweed.hafs.uthmani-pause-sajdah.json
    (CC BY 4.0): rule spans as code-point offsets into
  * the Tanzil.net Uthmani text of April 2017 ("surah|ayah|text" lines),
    which those offsets index exactly (Tanzil terms: verbatim copies).

The spans are re-anchored onto the words of assets/quran/mushaf_lines.json,
the text the reader draws, and written in the markup that
lib/core/offline_tajweed.dart parses:
  <tajweed class=RULE>…</tajweed> … <span class=end>N</span>

Usage: python3 tool/build_tajweed_asset.py ANNOTATIONS.json TANZIL.txt
"""

import difflib
import gzip
import json
import sys

RULES = {
    'hamzat_wasl': 'ham_wasl',
    'lam_shamsiyyah': 'laam_shamsiyah',
    'silent': 'slnt',
    'madd_2': 'madda_normal',
    'madd_246': 'madda_permissible',
    'madd_munfasil': 'madda_permissible',
    'madd_muttasil': 'madda_obligatory',
    'madd_6': 'madda_necessary',
    'ghunnah': 'ghunnah',
    'ikhfa': 'ikhafa',
    'ikhfa_shafawi': 'ikhafa_shafawi',
    'idghaam_ghunnah': 'idgham_ghunnah',
    'idghaam_no_ghunnah': 'idgham_wo_ghunnah',
    'idghaam_shafawi': 'idgham_shafawi',
    'idghaam_mutajanisayn': 'idgham_mutajanisayn',
    'idghaam_mutaqaribayn': 'idgham_mutaqaribayn',
    'iqlab': 'iqlab',
    'qalqalah': 'qalaqah',
}
# Where spans overlap, the specific rule wins over plain ghunnah.
GENERAL = {'ghunnah'}
BASMALA = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ '
ARABIC_DIGITS = str.maketrans('0123456789', '٠١٢٣٤٥٦٧٨٩')


def tanzil(path):
    texts = {}
    with open(path, encoding='utf-8-sig') as source:
        for line in source:
            parts = line.rstrip('\n').split('|', 2)
            if len(parts) == 3 and parts[0].isdigit():
                texts[(int(parts[0]), int(parts[1]))] = parts[2]
    return texts


def mushaf_words():
    words = {}
    with open('assets/quran/mushaf_lines.json', encoding='utf-8') as source:
        pages = json.load(source)
    for page in pages:
        for line in page:
            if not line or isinstance(line[0], str):
                continue  # Surah header ("h") or basmala ("b") line.
            for token in line:
                if len(token) == 2:
                    words.setdefault(token[0], []).append(token[1])
    return words


def char_map(old, new):
    """Old code-point index -> new index for characters both texts share."""
    mapping = {}
    matcher = difflib.SequenceMatcher(None, old, new, autojunk=False)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == 'equal' or (tag == 'replace' and i2 - i1 == j2 - j1):
            for offset in range(i2 - i1):
                mapping[i1 + offset] = j1 + offset
    return mapping


def markup(text, rules, number):
    out, current = [], None
    for char, rule in zip(text, rules):
        if char == ' ' or rule != current:
            if current is not None:
                out.append('</tajweed>')
                current = None
        if char != ' ' and rule is not None and rule != current:
            out.append(f'<tajweed class={rule}>')
            current = rule
        out.append(char)
    if current is not None:
        out.append('</tajweed>')
    end = str(number).translate(ARABIC_DIGITS)
    return ''.join(out) + f' <span class=end>{end}</span>'


def main(annotations_path, tanzil_path):
    old_texts = tanzil(tanzil_path)
    words = mushaf_words()
    with open(annotations_path, encoding='utf-8') as source:
        annotations = json.load(source)
    verses, checked, misplaced, dropped, total = [], 0, 0, 0, 0
    for verse in annotations:
        surah, ayah = verse['surah'], verse['ayah']
        key = f'{surah}:{ayah}'
        old = old_texts[(surah, ayah)]
        shift = 0
        if ayah == 1 and surah not in (1, 9) and old.startswith(BASMALA):
            shift = len(BASMALA)
            old = old[shift:]
        new = ' '.join(words[key])
        mapping = char_map(old, new)
        rules = [None] * len(new)
        spans = sorted(
            verse['annotations'],
            key=lambda span: span['rule'] not in GENERAL,
        )
        for span in spans:
            rule = RULES[span['rule']]
            for index in range(span['start'] - shift, span['end'] - shift):
                if index < 0:
                    continue  # Inside the stripped basmala.
                total += 1
                target = mapping.get(index)
                if target is None:
                    dropped += 1
                    continue
                rules[target] = rule
                if span['rule'] in ('hamzat_wasl', 'lam_shamsiyyah'):
                    checked += 1
                    # Hamzat al-wasl is sometimes written as a plain alef.
                    misplaced += new[target] not in 'ٱال'
        # Inserted letters (e.g. tatweel) inside one rule take that rule.
        for index in range(1, len(new) - 1):
            if rules[index] is None and new[index] != ' ':
                if rules[index - 1] is not None and rules[index - 1] == rules[index + 1]:
                    rules[index] = rules[index - 1]
        verses.append({
            'verse_key': key,
            'text_uthmani_tajweed': markup(new, rules, ayah),
        })
    if len(verses) != 6236 or misplaced or dropped > total * 0.01:
        sys.exit(f'Alignment failed: {misplaced} misplaced, {dropped}/{total} dropped')
    payload = json.dumps({'verses': verses}, ensure_ascii=False).encode('utf-8')
    with gzip.open('assets/quran/tajweed.json.gz', 'wb', compresslevel=9) as out:
        out.write(payload)
    print(f'{len(verses)} verses, {total} annotated letters, '
          f'{dropped} without a counterpart, {checked} anchor letters checked')


if __name__ == '__main__':
    main(*sys.argv[1:3])
