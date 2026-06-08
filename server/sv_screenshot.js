const path = require('path');
const fs = require('fs');
const { PNG } = require('pngjs');

const RESOURCE = GetCurrentResourceName();
const RES_PATH = GetResourcePath(RESOURCE);
const OUTPUT_DIR = path.resolve(path.join(RES_PATH, 'web/dist/assets/furniture'));

try {
    if (!fs.existsSync(OUTPUT_DIR)) fs.mkdirSync(OUTPUT_DIR, { recursive: true });
} catch (err) {
    console.log('^1[LNS_Housing]^0 Output dir error: ' + err.message);
}

function stripDataUri(b64) {
    if (typeof b64 !== 'string') return b64;
    if (!b64.startsWith('data:')) return b64;
    const comma = b64.indexOf(',');
    return comma === -1 ? b64 : b64.slice(comma + 1);
}

function checkPermission(src) {
    const esx = global.exports['es_extended'];
    if (esx) {
        try {
            const ESX = esx.getSharedObject();
            const p = ESX.GetPlayerFromId(src);
            const group = p && p.getGroup && p.getGroup();
            if (group === 'admin' || group === 'god') {
                return true;
            }
        } catch (e) { }
        return false;
    }

    if (IsPlayerAceAllowed(src.toString(), "admin")) {
        return true;
    }

    return false;
}

function removeChromaKey(pngBuffer, mode) {
    const png = PNG.sync.read(pngBuffer);
    const d = png.data;
    const w = png.width, h = png.height;
    let removed = 0;
    const isMagenta = mode === 'magenta';

    for (let i = 0; i < d.length; i += 4) {
        const r = d[i], g = d[i + 1], b = d[i + 2];
        let keyness = 0;

        if (isMagenta) {
            const rOverG = r - g;
            const bOverG = b - g;
            const minOver = rOverG < bOverG ? rOverG : bOverG;
            const primary = r < b ? r : b;
            if (minOver > 0 && primary > 10) {
                const edgeSoft = minOver < 20 ? minOver / 20 : 1;
                const primarySoft = primary < 40 ? (primary - 10) / 30 : 1;
                keyness = Math.min(1, (rOverG + bOverG) / (r + b + 1)) * edgeSoft * primarySoft;
            }
        } else {
            const gOverR = g - r;
            const gOverB = g - b;
            const minOver = gOverR < gOverB ? gOverR : gOverB;
            if (minOver > 0 && g > 10) {
                const edgeSoft = minOver < 20 ? minOver / 20 : 1;
                const primarySoft = g < 40 ? (g - 10) / 30 : 1;
                keyness = Math.min(1, (gOverR + gOverB) / (g + 1)) * edgeSoft * primarySoft;
            }
        }

        if (keyness > 0) {
            d[i + 3] = (255 * (1 - keyness) + 0.5) | 0;
            if (isMagenta) {
                d[i] = (r - (r - g) * keyness + 0.5) | 0;
                d[i + 2] = (b - (b - g) * keyness + 0.5) | 0;
            } else {
                const cap = r > b ? r : b;
                d[i + 1] = (g - (g - cap) * keyness + 0.5) | 0;
            }
            removed++;
        }
    }

    const RADIUS = 2;
    const KERNEL = (RADIUS * 2 + 1) * (RADIUS * 2 + 1);
    const totalPx = w * h;
    const src = new Uint8Array(totalPx);

    for (let pass = 0; pass < 2; pass++) {
        for (let i = 0; i < totalPx; i++) src[i] = d[(i << 2) + 3];

        for (let y = RADIUS; y < h - RADIUS; y++) {
            for (let x = RADIUS; x < w - RADIUS; x++) {
                const idx = y * w + x;
                const a = src[idx];
                if ((a === 0 || a === 255) &&
                    src[idx - 1] === a && src[idx + 1] === a &&
                    src[idx - w] === a && src[idx + w] === a) continue;

                let sum = 0;
                for (let ky = -RADIUS; ky <= RADIUS; ky++) {
                    const rowOff = (y + ky) * w + x;
                    for (let kx = -RADIUS; kx <= RADIUS; kx++) {
                        sum += src[rowOff + kx];
                    }
                }
                d[(idx << 2) + 3] = (sum / KERNEL + 0.5) | 0;
            }
        }
    }

    console.log('^2[LNS_Housing]^0 Chroma key (' + mode + '): ' + removed + '/' + totalPx + ' pixels removed');
    return PNG.sync.write(png, { colorType: 6 });
}

function resizePNG(pngBuffer, targetW, targetH) {
    const src = PNG.sync.read(pngBuffer);
    if (src.width === targetW && src.height === targetH) return pngBuffer;

    const srcAspect = src.width / src.height;
    const dstAspect = targetW / targetH;

    let cropX = 0, cropY = 0, cropW = src.width, cropH = src.height;
    if (srcAspect > dstAspect) {
        cropW = Math.round(src.height * dstAspect);
        cropX = Math.round((src.width - cropW) / 2);
    } else if (srcAspect < dstAspect) {
        cropH = Math.round(src.width / dstAspect);
        cropY = Math.round((src.height - cropH) / 2);
    }

    const dst = new PNG({ width: targetW, height: targetH, fill: true });
    const sd = src.data, dd = dst.data;
    const sw = src.width;
    const xRatio = cropW / targetW;
    const yRatio = cropH / targetH;

    for (let y = 0; y < targetH; y++) {
        const sy0 = cropY + y * yRatio;
        const sy1 = cropY + (y + 1) * yRatio;
        const iy0 = sy0 | 0;
        const iy1 = Math.min((sy1 | 0) + 1, cropY + cropH);

        for (let x = 0; x < targetW; x++) {
            const sx0 = cropX + x * xRatio;
            const sx1 = cropX + (x + 1) * xRatio;
            const ix0 = sx0 | 0;
            const ix1 = Math.min((sx1 | 0) + 1, cropX + cropW);

            let r = 0, g = 0, b = 0, a = 0, totalW = 0;

            for (let sy = iy0; sy < iy1; sy++) {
                const wy = (sy < sy0 ? 1 - (sy0 - sy) : sy + 1 > sy1 ? sy1 - sy : 1);
                const rowOff = sy * sw;

                for (let sx = ix0; sx < ix1; sx++) {
                    const wx = (sx < sx0 ? 1 - (sx0 - sx) : sx + 1 > sx1 ? sx1 - sx : 1);
                    const w = wx * wy;
                    const si = (rowOff + sx) << 2;
                    r += sd[si] * w;
                    g += sd[si + 1] * w;
                    b += sd[si + 2] * w;
                    a += sd[si + 3] * w;
                    totalW += w;
                }
            }

            const di = (y * targetW + x) << 2;
            const inv = 1 / totalW;
            dd[di] = (r * inv + 0.5) | 0;
            dd[di + 1] = (g * inv + 0.5) | 0;
            dd[di + 2] = (b * inv + 0.5) | 0;
            dd[di + 3] = (a * inv + 0.5) | 0;
        }
    }

    const STRENGTH = 0.3;
    for (let y = 1; y < targetH - 1; y++) {
        for (let x = 1; x < targetW - 1; x++) {
            const ci = (y * targetW + x) << 2;
            if (dd[ci + 3] === 0) continue;
            const t = (ci - (targetW << 2));
            const b = (ci + (targetW << 2));
            for (let c = 0; c < 3; c++) {
                const sharp = 5 * dd[ci + c] - dd[t + c] - dd[b + c] - dd[ci - 4 + c] - dd[ci + 4 + c];
                const blended = dd[ci + c] + (sharp - dd[ci + c]) * STRENGTH;
                dd[ci + c] = blended < 0 ? 0 : blended > 255 ? 255 : (blended + 0.5) | 0;
            }
        }
    }

    return PNG.sync.write(dst, { colorType: 6 });
}

onNet('LNS_Housing:server:processScreenshot', (payload) => {
    const src = source;
    if (!checkPermission(src)) {
        console.log(`^1[LNS_Housing]^0 Refused screenshot process: Player ${src} lacks permission.`);
        return;
    }
    if (!payload || typeof payload !== 'object') return;

    const modelName = typeof payload.model === 'string' ? payload.model : '';
    const imageData = payload.imageData;

    if (!modelName || modelName.includes('..') || modelName.includes('/') || modelName.includes('\\')) {
        console.log('^1[LNS_Housing]^0 Refused capture: invalid model name: ' + modelName);
        return;
    }
    if (typeof imageData !== 'string' || imageData.length === 0) {
        console.log('^1[LNS_Housing]^0 Refused capture: empty image data for ' + modelName);
        return;
    }

    try {
        let outputData = Buffer.from(stripDataUri(imageData), 'base64');
        if (!outputData || outputData.length === 0) {
            console.log('^1[LNS_Housing]^0 Refused capture: invalid base64 for ' + modelName);
            return;
        }

        // Apply green screen chroma-key removal
        try {
            outputData = removeChromaKey(outputData, 'green');
        } catch (e) {
            console.log('^3[LNS_Housing]^0 Chroma key failed: ' + e.message);
        }

        // Resize to standard 256x256 icon size
        try {
            outputData = resizePNG(outputData, 256, 256);
        } catch (e) {
            console.log('^3[LNS_Housing]^0 Resize failed: ' + e.message);
        }

        const outputPath = path.resolve(path.join(OUTPUT_DIR, modelName + '.png'));
        if (!outputPath.startsWith(OUTPUT_DIR + path.sep)) {
            console.log('^1[LNS_Housing]^0 Refused capture: path traversal blocked for ' + modelName);
            return;
        }

        fs.writeFileSync(outputPath, outputData);
        console.log('^2[LNS_Housing]^0 Saved transparent furniture screenshot: ' + modelName + '.png (' + Math.round(outputData.length / 1024) + ' KB)');
    } catch (err) {
        console.log('^1[LNS_Housing]^0 Process error: ' + (err && err.message ? err.message : err));
    }
});

onNet('LNS_Housing:server:setScreenshotBucket', (bucket) => {
    const src = source;
    if (!checkPermission(src)) return;
    SetPlayerRoutingBucket(src.toString(), bucket);
    console.log(`^2[LNS_Housing]^0 Player ${src} set to routing bucket ${bucket}`);
});

onNet('LNS_Housing:server:resetScreenshotBucket', () => {
    const src = source;
    if (!checkPermission(src)) return;
    SetPlayerRoutingBucket(src.toString(), 0);
    console.log(`^2[LNS_Housing]^0 Player ${src} reset to routing bucket 0`);
});
