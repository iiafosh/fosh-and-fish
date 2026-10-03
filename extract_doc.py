import re
import json

with open('wiki_dump/encyclopedia.txt', encoding='utf-8') as f:
    content = f.read()

chunks = re.findall(r'DOCS_modelChunk\s*=\s*(\{.+?\});(?:\s*DOCS_modelChunk|\s*<\/script>)', content, re.DOTALL)
print('Found chunks:', len(chunks))

all_text = []
for c in chunks:
    try:
        data = json.loads(c)
        for item in data.get('chunk', []):
            if 's' in item:
                all_text.append(item['s'])
    except Exception:
        strs = re.findall(r'"s":"((?:[^"\\]|\\.)*)"', c)
        for s in strs:
            try:
                all_text.append(json.loads('"' + s + '"'))
            except Exception:
                all_text.append(s)

full_doc = ''.join(all_text)
with open('wiki_dump/encyclopedia_clean.txt', 'w', encoding='utf-8') as out:
    out.write(full_doc)

print('Wrote clean doc, total chars:', len(full_doc))
print('--- FIRST 2000 CHARS ---')
print(full_doc[:2000])
