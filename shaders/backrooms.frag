#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float uResX;
  float uResY;
  float uTime;
  float uFlicker;
  float uCamX;
  float uCamY;
  float uCamZ;
  float uYaw;
  float uPitch;
  float uDark;
  float uScare;
  float uShake;
  float uSanity;
  float uE1X;
  float uE1Y;
  float uE1Z;
  float uE1Op;
  float uE2X;
  float uE2Y;
  float uE2Z;
  float uE2Op;
};

const float PI = 3.141592653589793;
const int MAX_STEPS = 80;
const float MAX_DIST = 34.0;
const float SURF_EPS = 0.0022;
const float CELL = 6.0;
const float CEIL_H = 3.0;
const float PANEL = 3.0;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise21(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash21(i);
  float b = hash21(i + vec2(1.0, 0.0));
  float c = hash21(i + vec2(0.0, 1.0));
  float d = hash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 4; i++) {
    v += a * noise21(p);
    p *= 2.17;
    a *= 0.5;
  }
  return v;
}

float sdBoxXZ(vec2 p, vec2 b) {
  vec2 d = abs(p) - b;
  return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float map(vec3 p, out int mat) {
  mat = 0;
  float d = p.y;
  float dc = CEIL_H - p.y;
  if (dc < d) { d = dc; mat = 1; }

  vec2 cid = floor(p.xz / CELL);
  float h = hash21(cid);

  if (h < 0.55) {
    vec2 off = (vec2(hash21(cid + 7.13), hash21(cid + 3.71)) - 0.5) * CELL * 0.18;
    float dp = sdBoxXZ(p.xz - ((cid + 0.5) * CELL + off), vec2(0.62));
    if (dp < d) { d = dp; mat = 2; }
  }

  if (h > 0.78) {
    float axis = step(0.5, hash21(cid + 11.37));
    vec2 half_ = mix(vec2(CELL * 0.5, 0.14), vec2(0.14, CELL * 0.5), axis);
    float dw = sdBoxXZ(p.xz - (cid + 0.5) * CELL, half_);
    if (dw < d) { d = dw; mat = 3; }
  }
  return d;
}

vec3 calcNormal(vec3 p) {
  const vec2 e = vec2(0.0018, -0.0018);
  int m;
  return normalize(
    e.xyy * map(p + e.xyy, m) +
    e.yyx * map(p + e.yyx, m) +
    e.yxy * map(p + e.yxy, m) +
    e.xxx * map(p + e.xxx, m));
}

float shadowRay(vec3 ro, vec3 rd) {
  float res = 1.0;
  float t = 0.06;
  int m;
  for (int i = 0; i < 18; i++) {
    float h = map(ro + rd * t, m);
    res = min(res, 10.0 * h / t);
    t += clamp(h, 0.06, 0.45);
    if (res < 0.02 || t > 4.5) break;
  }
  return clamp(res, 0.0, 1.0);
}

bool panelRect(vec2 xz, out vec2 g) {
  g = mod(xz + PANEL * 0.5, PANEL) - PANEL * 0.5;
  return abs(g.x) < 0.55 && abs(g.y) < 0.28;
}

void main() {
  float aspect = uResX / max(uResY, 1.0);
  vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
  uv.x *= aspect;

  if (uShake > 0.001) {
    uv += (vec2(noise21(vec2(uTime * 47.0, 1.7)), noise21(vec2(uTime * 53.0, 9.2))) - 0.5)
          * uShake * 0.09;
  }

  float cy = cos(uYaw), sy = sin(uYaw);
  float cp = cos(uPitch), sp = sin(uPitch);
  vec3 fw = normalize(vec3(sy * cp, sp, -cy * cp));
  vec3 rt = normalize(vec3(cy, 0.0, sy));
  vec3 up = cross(fw, rt);

  vec3 ro = vec3(uCamX, uCamY, uCamZ);
  float focal = 1.15;
  vec3 rd = normalize(fw * focal + rt * uv.x + up * uv.y);

  float t = 0.0;
  int mat = 0;
  bool hit = false;
  for (int i = 0; i < MAX_STEPS; i++) {
    vec3 p = ro + rd * t;
    float d = map(p, mat);
    if (d < SURF_EPS) { hit = true; break; }
    t += d * 0.92;
    if (t > MAX_DIST) break;
  }

  vec3 fogCol = vec3(0.235, 0.205, 0.115);
  vec3 col;

  if (hit && t <= MAX_DIST) {
    vec3 p = ro + rd * t;
    vec3 n = calcNormal(p);

    vec3 alb;
    if (mat == 0) {
      float sp1 = fbm(p.xz * 9.0);
      float sp2 = fbm(p.xz * 37.0);
      alb = mix(vec3(0.30, 0.25, 0.12), vec3(0.43, 0.37, 0.19), sp1 * 0.6 + sp2 * 0.4);
      alb *= 0.82 + 0.18 * fbm(p.xz * 2.6 + 31.0);
    } else if (mat == 1) {
      vec2 tg = abs(fract(p.xz / 0.61) - 0.5);
      float seam = smoothstep(0.44, 0.49, max(tg.x, tg.y));
      alb = mix(vec3(0.50, 0.48, 0.40), vec3(0.26, 0.24, 0.19), seam);
      alb *= 0.88 + 0.12 * fbm(p.xz * 6.0);
      if (p.y > CEIL_H - 0.05 && p.y < CEIL_H + 0.05) {
        alb = vec3(0.55, 0.52, 0.44);
      }
    } else {
      float stain = fbm(p.xz * 1.6 + vec2(p.y * 0.85, 17.0));
      float tone = fbm(p.xz * 4.2 + 53.0);
      alb = mix(vec3(0.58, 0.51, 0.23), vec3(0.68, 0.61, 0.30), tone);
      alb *= 0.72 + 0.42 * stain;
      float grime = smoothstep(0.5, 0.0, p.y) * fbm(p.xz * 2.1);
      alb *= 1.0 - 0.42 * grime;
      if (p.y < 0.10) alb = vec3(0.22, 0.19, 0.12);
      if (p.y > CEIL_H - 0.10) alb = vec3(0.35, 0.32, 0.22);
    }

    vec3 emis = vec3(0.0);
    if (mat == 1 && p.y > CEIL_H - 0.03) {
      vec2 pg;
      if (panelRect(p.xz, pg)) {
        float rib = 0.90 + 0.10 * sin(pg.x * 170.0);
        emis = vec3(1.0, 0.95, 0.80) * 2.8 * (0.55 + 0.45 * uFlicker) * rib;
      }
    }

    vec2 pcid = floor(p.xz / PANEL + 0.5) * PANEL;
    vec3 lp = vec3(pcid.x, CEIL_H - 0.04, pcid.y);
    vec3 ld = lp - p;
    float distL = length(ld);
    ld /= max(distL, 0.001);
    float dif = max(dot(n, ld), 0.0);
    float sh = shadowRay(p + n * 0.02, ld);
    float atten = 1.0 / (1.0 + 0.30 * distL * distL);
    vec3 key = vec3(1.0, 0.92, 0.70) * dif * sh * atten * 5.2 * (0.45 + 0.55 * uFlicker);

    float ambK = n.y > 0.5 ? 1.0 : 0.55;
    vec3 amb = vec3(0.30, 0.26, 0.15) * ambK * (0.50 + 0.50 * uFlicker);

    col = alb * (key + amb) + emis;
  } else {
    col = fogCol;
  }

  float fog = hit ? clamp(1.0 - exp(-t * 0.088), 0.0, 1.0) : 1.0;
  col = mix(col, fogCol, fog);

  col *= 1.0 - 0.88 * uDark;

  float lum = dot(col, vec3(0.299, 0.587, 0.114));
  col = mix(col, vec3(lum) * vec3(0.92, 0.96, 1.04), (1.0 - uSanity) * 0.5);

  col = col / (col + 0.92);
  col = pow(max(col, 0.0), vec3(0.4545));

  float gn = hash21(qt_TexCoord0 * vec2(uResX, uResY) + fract(uTime) * 137.0) - 0.5;
  col += gn * (0.045 + 0.05 * (1.0 - uSanity));

  col *= 0.975 + 0.025 * sin(qt_TexCoord0.y * uResY * PI);

  float vig = smoothstep(1.55, 0.30, length(qt_TexCoord0 - 0.5) * 2.0);
  float pulse = 1.0 - 0.10 * (1.0 - uSanity) * (0.5 + 0.5 * sin(uTime * 5.2));
  col *= mix(0.45, 1.0, vig) * pulse;

  if (uScare > 0.001) {
    vec2 suv = qt_TexCoord0 - 0.5;
    suv.x *= aspect;
    suv *= 1.0 + 0.035 * sin(qt_TexCoord0.y * 46.0 + uTime * 88.0) * uScare;

    float s = 1.65;
    vec2 hq = suv - vec2(0.0, 0.16);
    float head = length(hq / s) * s;
    vec2 bq = suv - vec2(0.0, -0.72);
    vec2 bd = abs(bq / s) - vec2(0.62, 0.75);
    float body = length(max(bd, 0.0)) + min(max(bd.x, bd.y), 0.0);
    body = body * s - 0.28;
    float ent = min(head - 0.20, body);

    float eyeL = length((suv - vec2(-0.085, 0.185)) / (s * 0.34)) * s * 0.34;
    float eyeR = length((suv - vec2(0.085, 0.185)) / (s * 0.34)) * s * 0.34;
    float eye = min(eyeL, eyeR) - 0.026;

    float bodyMask = smoothstep(0.006, -0.006, ent) * uScare;
    col = mix(col, vec3(0.012, 0.006, 0.005), bodyMask * 0.97);
    float glow = smoothstep(0.012, 0.0, eye) * bodyMask;
    col += vec3(0.85, 0.04, 0.02) * glow * (0.75 + 0.25 * sin(uTime * 63.0));

    float edge = smoothstep(0.55, 1.25, length(suv) * 1.55);
    col = mix(col, vec3(0.42, 0.015, 0.01), edge * uScare * 0.5);
  }

  // In-world entities (ghosts/monsters emerging from behind pillars)
  for (int ei = 0; ei < 2; ei++) {
    float eX = ei == 0 ? uE1X : uE2X;
    float eY = ei == 0 ? uE1Y : uE2Y;
    float eZ = ei == 0 ? uE1Z : uE2Z;
    float eOp = ei == 0 ? uE1Op : uE2Op;
    if (eOp < 0.01) continue;

    vec3 eWorld = vec3(eX, eY, eZ);
    vec3 toE = eWorld - ro;
    float eDist = length(toE);
    if (eDist < 0.5 || eDist > 28.0) continue;

    vec3 eForward = toE / eDist;
    float eRight = dot(eForward, rt);
    float eUp = dot(eForward, up);
    float eDepth = dot(eForward, fw);
    if (eDepth < 0.1) continue;

    float eFov = focal / max(eDepth, 0.1);
    vec2 eScreen = vec2(eRight, eUp) * eFov;
    vec2 eDelta = eScreen - uv;

    float eBodyH = 0.38 / eDepth;
    float eBodyW = 0.16 / eDepth;
    float eHeadR = 0.09 / eDepth;

    float dBx = abs(eDelta.x) - eBodyW;
    float dBy = abs(eDelta.y + eBodyH * 0.35) - eBodyH;
    float eBody = length(max(vec2(dBx, dBy), 0.0)) + min(max(dBx, dBy), 0.0);

    float eHead = length(eDelta - vec2(0.0, eBodyH * 0.85)) - eHeadR;
    float eShape = min(eBody, eHead);

    float eMask = smoothstep(0.008 / eDepth, -0.002 / eDepth, eShape);
    if (eMask < 0.001) continue;

    float eFog = 1.0 - exp(-eDist * 0.088);
    vec3 eColor = vec3(0.008, 0.004, 0.003);
    eColor = mix(eColor, fogCol, eFog * 0.6);
    col = mix(col, eColor, eMask * eOp);

    float elL = length((eDelta - vec2(-0.038 / eDepth, eBodyH * 0.92)) / (eHeadR * 0.35)) * eHeadR * 0.35;
    float elR = length((eDelta - vec2(0.038 / eDepth, eBodyH * 0.92)) / (eHeadR * 0.35)) * eHeadR * 0.35;
    float eEye = min(elL, elR) - 0.012 / eDepth;
    float eEyeMask = smoothstep(0.006 / eDepth, 0.0, eEye) * eMask * eOp;
    col += vec3(0.9, 0.05, 0.02) * eEyeMask * (0.7 + 0.3 * sin(uTime * 55.0 + float(ei) * 3.0));

    float eVig = smoothstep(0.8, 0.2, length(eDelta) * 2.5);
    col = mix(col, vec3(0.12, 0.01, 0.005), eVig * eOp * 0.12);
  }

  fragColor = vec4(col * qt_Opacity, 1.0);
}
