import os, json, urllib.request, ssl
from fontTools.ttLib import TTFont

ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE

# deployed Cairo
fp = os.path.join(os.environ["TEMP"], "CairoDeployed.ttf")
urllib.request.urlretrieve("https://kinder-world-bd9e3.web.app/assets/fonts/Cairo-Regular.ttf", fp)
cmap = set(TTFont(fp).getBestCmap().keys())

# backend content
url = "https://graduation-project-gnbb.onrender.com/api/v1/content/child/items"
data = json.loads(urllib.request.urlopen(urllib.request.Request(url), context=ctx, timeout=60).read().decode("utf-8"))
items = data.get("items", data if isinstance(data, list) else [])

chars = set()
def walk(o):
    if isinstance(o, dict):
        for v in o.values(): walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
    elif isinstance(o, str):
        for ch in o: chars.add(ord(ch))
walk(items)

arabic = sorted(c for c in chars if 0x0600 <= c <= 0x06FF or 0x0750<=c<=0x077F or 0xFB50<=c<=0xFEFF)
missing = [c for c in arabic if c not in cmap]
print("backend arabic-range codepoints used:", len(arabic))
print("MISSING from deployed Cairo:", len(missing))
for c in missing[:40]:
    print(f"  U+{c:04X}  {chr(c)!r}")
