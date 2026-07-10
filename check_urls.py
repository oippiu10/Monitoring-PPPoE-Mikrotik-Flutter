import urllib.request

urls = [
    "https://cmmnetwork.online/files/app-release.apk",
    "https://billing.marzuqnetwork.online/files/app-release.apk",
]

for url in urls:
    try:
        req = urllib.request.Request(url, method='HEAD')
        req.add_header('User-Agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36')
        resp = urllib.request.urlopen(req, timeout=5)
        print(f"{url} -> {resp.status} {resp.reason} ({resp.headers.get('Content-Length')} bytes)")
    except Exception as e:
        print(f"{url} -> ERROR: {e}")
