# Deploy — nulldrift-godot

## Live URLs

- **CloudFront (use this):** https://d3t6i5nybjge43.cloudfront.net/
  - Distribution ID: `E1G83D30N3XZ5P`
  - ~10 min after creation before first reachable; allow ~5 min for invalidations.
- **S3 website (origin, live immediately):** http://nulldrift-game-25623.s3-website-us-east-1.amazonaws.com/

## Pattern

Mirrors the working soundtrack deploy (`nulldrift-soundtrack-40105` → `d27v3l1cfej3x5.cloudfront.net`):

- S3 bucket configured as a **static website** (NOT REST API endpoint).
- Block-public-access disabled; bucket policy grants `s3:GetObject` to `*`.
- CloudFront origin uses **`http-only`** to the S3 *website* endpoint (no SSE/SigV4 dance).
- Default root object: `index.html`. `redirect-to-https` viewer protocol.

Amplify was abandoned — its build environment (AL2023, non-root, no apt-get) made installing Godot + export templates hostile. Local export is one command and far simpler.

## Redeploy

```bash
# 1. Export from Godot (uses the "Web" preset in export_presets.cfg)
cd ~/code/nulldrift-godot
rm -rf build && mkdir -p build
godot --headless --export-release "Web" build/index.html

# 2. Upload to S3 (set correct content-types on large binaries)
BUCKET=nulldrift-game-25623
aws s3 sync build/ "s3://$BUCKET/" --delete \
  --exclude "index.pck" --exclude "index.wasm"
aws s3 cp build/index.pck  "s3://$BUCKET/index.pck"  --content-type application/octet-stream
aws s3 cp build/index.wasm "s3://$BUCKET/index.wasm" --content-type application/wasm

# 3. Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id E1G83D30N3XZ5P \
  --paths "/*"
```

## Notes

- Web export is **`web_nothreads`** — no SharedArrayBuffer / COOP-COEP needed. If we ever switch to threaded export, the CloudFront default cache policy will need a response-headers policy injecting `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.
- Build is ~295 MB (index.pck = 257 MB, index.wasm = 37 MB). CloudFront compression cuts that on the wire.
- Coordinated with the soundtrack session via `art-director` — they're on a separate bucket and we shipped on theirs as a reference, not as a sub-path.
