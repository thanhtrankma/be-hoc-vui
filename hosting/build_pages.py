#!/usr/bin/env python3
"""Sinh trang web tĩnh cho Firebase Hosting (hosting/public/) từ cùng nguồn với trang trong app.

  python3 hosting/build_pages.py

Nguồn:
  assets/legal/about_vi.md, about_en.md      → public/index.html (Giới thiệu, vi + en)
  assets/legal/privacy_vi.md                 → public/privacy/index.html
  assets/legal/privacy_en.md                 → public/privacy/en/index.html
  assets/data/photos.json, assets/sfx/CREDITS.txt, assets/sprites/**/CREDITS*  → public/credits/index.html

Trang tự chứa (CSS nhúng), không script, không phông ngoài, không trình theo dõi.
Sửa nội dung thì sửa file .md / dữ liệu rồi chạy lại script này (test/hosting/hosting_pages_test.dart kiểm trang khớp nguồn).
"""
import html
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PUB = os.path.join(ROOT, 'hosting', 'public')
BASE = 'https://bevuihoc-app.web.app'

CSS = """
:root{--ink:#23324d;--soft:#5b6b88;--line:#e3ecf7;--card:#fff;--bg1:#8fd3ff;--bg2:#e6f7ff;--accent:#e86a3a;--link:#1c6fb8;--mark:#fff3bf}
*{box-sizing:border-box}
html{-webkit-text-size-adjust:100%}
body{margin:0;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,"Noto Sans","Helvetica Neue",Arial,sans-serif;
  color:var(--ink);line-height:1.6;background:linear-gradient(180deg,var(--bg1),var(--bg2) 320px,var(--bg2));min-height:100vh}
header{padding:28px 16px 8px;text-align:center}
.logo{font-size:2.2rem;font-weight:800;color:#fff;text-shadow:0 3px 0 var(--accent);letter-spacing:.5px;text-decoration:none}
.logo b{color:#ffc93c;text-shadow:0 3px 0 #e0a800}
nav{display:flex;flex-wrap:wrap;gap:8px;justify-content:center;margin:14px 0 4px}
nav a{background:rgba(255,255,255,.85);color:var(--ink);text-decoration:none;font-weight:700;padding:6px 14px;border-radius:999px;font-size:.95rem}
nav a[aria-current=page]{background:var(--ink);color:#fff}
main{max-width:820px;margin:12px auto 32px;padding:0 16px}
.card{background:var(--card);border-radius:22px;padding:22px 20px;box-shadow:0 6px 24px rgba(35,50,77,.10);margin-bottom:18px;overflow-wrap:anywhere}
h1{font-size:1.6rem;line-height:1.25;margin:.2em 0 .6em}
h2{font-size:1.2rem;margin:1.4em 0 .4em}
ul{padding-left:1.3em}
li{margin:.3em 0}
a{color:var(--link)}
mark{background:var(--mark);padding:0 4px;border-radius:4px;font-weight:700}
.muted{color:var(--soft);font-size:.92rem}
.lang{float:right;font-size:.9rem;font-weight:700}
table{width:100%;border-collapse:collapse;font-size:.88rem}
th,td{text-align:left;padding:6px 6px;border-bottom:1px solid var(--line);vertical-align:top}
th{font-weight:800}
pre{white-space:pre-wrap;font:inherit;font-size:.88rem;margin:0}
footer{text-align:center;color:var(--soft);font-size:.85rem;padding:0 16px 28px}
@media (max-width:520px){.card{padding:18px 14px}h1{font-size:1.35rem}table{font-size:.8rem}}
"""


def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'(https?://[^\s<)]+[^\s<).,;])', r'<a href="\1">\1</a>', s)
    s = s.replace('[EMAIL LIÊN HỆ]', '<mark>[EMAIL LIÊN HỆ]</mark>')
    return s


def md_to_html(md):
    out, para, items = [], [], []

    def flush():
        if para:
            out.append('<p>' + inline(' '.join(para)) + '</p>')
            para.clear()
        if items:
            out.append('<ul>' + ''.join('<li>' + inline(x) + '</li>' for x in items) + '</ul>')
            items.clear()

    for raw in md.split('\n'):
        line = raw.rstrip()
        if not line:
            flush()
        elif line.startswith('# '):
            flush()
            out.append('<h1>' + inline(line[2:]) + '</h1>')
        elif line.startswith('## '):
            flush()
            out.append('<h2>' + inline(line[3:]) + '</h2>')
        elif line.startswith('- '):
            if para:
                out.append('<p>' + inline(' '.join(para)) + '</p>')
                para.clear()
            items.append(line[2:])
        else:
            if items:
                flush()
            para.append(line)
    flush()
    return '\n'.join(out)


NAV = [('/', {'vi': 'Giới thiệu', 'en': 'About'}), ('/privacy', {'vi': 'Quyền riêng tư', 'en': 'Privacy'}), ('/credits', {'vi': 'Ghi công', 'en': 'Credits'})]


def page(title, body, lang='vi', current='/', desc=''):
    nav = ''.join(
        f'<a href="{href if not (lang == "en" and href == "/privacy") else "/privacy/en"}"' + (' aria-current="page"' if href == current else '') + f'>{labels[lang]}</a>'
        for href, labels in NAV)
    return f"""<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<meta name="description" content="{html.escape(desc)}">
<meta name="referrer" content="no-referrer">
<style>{CSS}</style>
</head>
<body>
<header><a class="logo" href="/">Bé <b>Vui</b> Học</a><nav>{nav}</nav></header>
<main>
{body}
</main>
<footer>Bé Vui Học · {'học mà chơi cho bé 6–8 tuổi' if lang == 'vi' else 'learn through play for ages 6–8'} · {'Không quảng cáo, không theo dõi' if lang == 'vi' else 'No ads, no tracking'}</footer>
</body>
</html>
"""


def license_url(lic):
    """'CC BY-SA 4.0' → https://creativecommons.org/licenses/by-sa/4.0/ (khớp photoLicenseUrl() trong lib/core/content/models.dart)."""
    lic = (lic or '').strip()
    if lic == 'CC0':
        return 'https://creativecommons.org/publicdomain/zero/1.0/'
    m = re.match(r'^CC (BY(?:-SA)?) (\d\.\d)(?: ([a-z]{2}))?$', lic)
    if not m:
        return None
    return f'https://creativecommons.org/licenses/{m[1].lower()}/{m[2]}/' + (f'{m[3]}/' if m[3] else '')


def lic_cell(lic):
    url = license_url(lic)
    return f'<a href="{html.escape(url)}">{html.escape(lic)}</a>' if url else html.escape(lic or '')


def read(p):
    with open(os.path.join(ROOT, p), encoding='utf-8') as f:
        return f.read()


def write(p, s):
    full = os.path.join(PUB, p)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, 'w', encoding='utf-8') as f:
        f.write(s)


def build():
    about = ('<div class="card">' + md_to_html(read('assets/legal/about_vi.md')).replace('Danh sách đầy đủ có ở mục Ghi công.', 'Danh sách đầy đủ: <a href="/credits">Ghi công</a>.') + '</div>'
             + '<div class="card" lang="en">' + md_to_html(read('assets/legal/about_en.md')).replace('The full list is under Credits.', 'Full list: <a href="/credits">Credits</a>.') + '</div>'
             + '<div class="card"><p><strong>Chính sách quyền riêng tư / Privacy policy:</strong> <a href="/privacy">Tiếng Việt</a> · <a href="/privacy/en">English</a></p></div>')
    write('index.html', page('Bé Vui Học', about, current='/', desc='Bé Vui Học — ứng dụng học mà chơi miễn phí cho bé 6–8 tuổi. Không quảng cáo, không tài khoản.'))

    vi = '<div class="card"><a class="lang" href="/privacy/en" hreflang="en">English</a>' + md_to_html(read('assets/legal/privacy_vi.md')) + '</div>'
    write('privacy/index.html', page('Chính sách quyền riêng tư — Bé Vui Học', vi, current='/privacy', desc='Chính sách quyền riêng tư của ứng dụng Bé Vui Học.'))
    en = '<div class="card"><a class="lang" href="/privacy" hreflang="vi">Tiếng Việt</a>' + md_to_html(read('assets/legal/privacy_en.md')) + '</div>'
    write('privacy/en/index.html', page('Privacy Policy — Bé Vui Học', en, lang='en', current='/privacy', desc='Privacy policy of the Bé Vui Học app.'))

    photos = json.loads(read('assets/data/photos.json'))
    rows = ''.join(
        '<tr><td>{}</td><td>{}</td><td>{}</td><td>{}</td></tr>'.format(
            html.escape(name), html.escape(p.get('by') or '?'), lic_cell(p.get('lic')),
            f'<a href="{html.escape(p["src"])}">Wikimedia Commons</a>' if p.get('src') else 'Wikimedia Commons')
        for name, p in photos.items())
    sprite_files = []
    for d, _, files in os.walk(os.path.join(ROOT, 'assets', 'sprites')):
        for fn in files:
            if fn.upper().startswith('CREDITS'):
                sprite_files.append(os.path.relpath(os.path.join(d, fn), ROOT))
    sprite_files.sort()
    sprites = ''.join('<pre>' + inline(read(p).strip()) + '</pre>' for p in sprite_files)
    credits = f"""<div class="card">
<h1>Ghi công <span class="muted">/ Credits</span></h1>
<p>Bé Vui Học dùng ảnh, âm thanh và hình vẽ có giấy phép tự do. Cảm ơn các tác giả! <span class="muted">Bé Vui Học uses freely licensed photos, sounds and artwork. Thank you to all authors!</span></p>
<h2>Ảnh chụp trong bài học <span class="muted">/ Lesson photos ({len(photos)})</span></h2>
<p class="muted">Wikimedia Commons — CC0, CC BY, CC BY-SA. Mỗi dòng ghi tác giả, giấy phép (dẫn tới trang giấy phép) và dẫn tới trang tệp gốc. Ảnh đã thu nhỏ/cắt và đổi sang định dạng WebP để dùng trong ứng dụng. <span lang="en">Each row gives the author, the license (linked) and the original file. Photos were resized/cropped and converted to WebP for use in the app.</span></p>
<table><thead><tr><th>Ảnh / Photo</th><th>Tác giả / Author</th><th>Giấy phép / License</th><th>Nguồn / Source</th></tr></thead><tbody>{rows}</tbody></table>
<h2>Tiếng thú cưng <span class="muted">/ Pet sounds</span></h2>
<pre>{inline(read('assets/sfx/CREDITS.txt').strip())}</pre>
<h2>Hình trong game <span class="muted">/ Game sprites</span></h2>
{sprites}
<h2>Hình hoạt hình và phông chữ <span class="muted">/ Cartoons and font</span></h2>
<ul><li>Fluent Emoji — Microsoft — MIT License — <a href="https://github.com/microsoft/fluentui-emoji">https://github.com/microsoft/fluentui-emoji</a></li>
<li>Baloo 2 — Ek Type — SIL Open Font License 1.1 — <a href="https://github.com/EkType/Baloo2">https://github.com/EkType/Baloo2</a></li></ul>
</div>"""
    write('credits/index.html', page('Ghi công — Bé Vui Học', credits, current='/credits', desc='Nguồn ảnh, âm thanh và hình vẽ dùng trong Bé Vui Học.'))

    write('404.html', page('Không tìm thấy — Bé Vui Học', '<div class="card"><h1>Không tìm thấy trang</h1><p><a href="/">Về trang Bé Vui Học</a> · <a href="/privacy">Quyền riêng tư</a> · <a href="/credits">Ghi công</a></p></div>'))


if __name__ == '__main__':
    build()
    print('wrote', PUB)
