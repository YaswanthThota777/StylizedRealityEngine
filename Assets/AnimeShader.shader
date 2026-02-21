Shader "Custom/AnimeShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}

        // Outline
        _OutlineStrength  ("Outline Strength",   Range(0, 2))      = 0.55
        _OutlineThickness ("Outline Thickness",  Range(1, 4))      = 1.3
        _OutlineThreshold ("Outline Threshold",  Range(0.01, 0.3)) = 0.05

        // Cel-Shading
        _ShadowSteps      ("Shadow Steps",        Range(2, 8))      = 5.0
        _ShadowThreshold  ("Shadow Threshold",    Range(0.1, 0.8))  = 0.38
        _ShadowSoftness   ("Shadow Softness",     Range(0.0, 0.3))  = 0.12
        _ShadowDark       ("Shadow Darkness",     Range(0.3, 1.0))  = 0.72
        _CoolTint         ("Shadow Cool Tint",    Color) = (0.72, 0.80, 1.15, 1)
        _WarmTint         ("Highlight Warm Tint", Color) = (1.15, 1.05, 0.88, 1)

        // Color Enhancement
        _Saturation  ("Saturation",  Range(0.5, 4.0)) = 2.20
        _Contrast    ("Contrast",    Range(0.5, 2.5)) = 1.28
        _Brightness  ("Brightness",  Range(0.5, 1.5)) = 1.05

        // Smoothing
        _SmoothStrength   ("Smooth Strength",     Range(0.0, 1.0)) = 0.45
        _BilateralSharp   ("Bilateral Sharpness", Range(5.0, 80.0)) = 55.0

        // Cel quantisation blend (0 = full continuous, 1 = full quantised)
        _CelBlend ("Cel Blend", Range(0.0, 1.0)) = 0.45

        // Bloom / Light Glow (Shinkai-style light scattering)
        _BloomThreshold  ("Bloom Threshold",  Range(0.3, 1.0)) = 0.62
        _BloomIntensity  ("Bloom Intensity",  Range(0.0, 3.0)) = 1.20
        _BloomRadius     ("Bloom Spread",     Range(1.0, 8.0)) = 4.0

        // Atmospheric Haze (Shinkai dreamy-sky quality)
        _HazeColor     ("Atmospheric Haze Color",     Color) = (0.55, 0.65, 0.90, 1)
        _HazeIntensity ("Atmospheric Haze Intensity", Range(0.0, 0.6)) = 0.14

        // Vignette (cinematic framing)
        _VignetteStrength ("Vignette Strength", Range(0.0, 2.0)) = 0.60
        _VignetteRadius   ("Vignette Radius",   Range(0.3, 1.0)) = 0.68

        // Chromatic Aberration (cinematic lens effect)
        _ChromaStrength ("Chromatic Aberration", Range(0.0, 0.015)) = 0.004
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            float4    _MainTex_TexelSize;

            float _OutlineStrength;
            float _OutlineThickness;
            float _OutlineThreshold;

            float _ShadowSteps;
            float _ShadowThreshold;
            float _ShadowSoftness;
            float _ShadowDark;
            float4 _CoolTint;
            float4 _WarmTint;

            float _Saturation;
            float _Contrast;
            float _Brightness;
            float _SmoothStrength;
            float _BilateralSharp;
            float _CelBlend;

            float  _BloomThreshold;
            float  _BloomIntensity;
            float  _BloomRadius;

            float4 _HazeColor;
            float  _HazeIntensity;

            float _VignetteStrength;
            float _VignetteRadius;

            float _ChromaStrength;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            // RGB <-> HSV helpers for saturation control
            float3 RGBtoHSV(float3 c)
            {
                float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
                float  d = q.x - min(q.w, q.y);
                float  e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0*d + e)), d / (q.x + e), q.x);
            }

            float3 HSVtoRGB(float3 c)
            {
                float4 K = float4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
                float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
                return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
            }

            float Lum(float3 c) { return dot(c, float3(0.299, 0.587, 0.114)); }

            // 8-direction neighbor offsets (compile-time constant, unrolled by compiler)
            static const float2 kOffsets[8] = {
                float2(-1,-1), float2( 0,-1), float2( 1,-1),
                float2(-1, 0),               float2( 1, 0),
                float2(-1, 1), float2( 0, 1), float2( 1, 1)
            };

            // 4×4 tent-kernel offsets for bloom approximation
            static const float2 kBloomOffsets[16] = {
                float2(-1.5,-1.5), float2(-0.5,-1.5), float2( 0.5,-1.5), float2( 1.5,-1.5),
                float2(-1.5,-0.5), float2(-0.5,-0.5), float2( 0.5,-0.5), float2( 1.5,-0.5),
                float2(-1.5, 0.5), float2(-0.5, 0.5), float2( 0.5, 0.5), float2( 1.5, 0.5),
                float2(-1.5, 1.5), float2(-0.5, 1.5), float2( 0.5, 1.5), float2( 1.5, 1.5)
            };

            fixed4 frag(v2f i) : SV_Target
            {
                float2 texel = _MainTex_TexelSize.xy;

                // === PASS 1: Chromatic Aberration (cinematic lens effect) ===
                // Shifts R and B channels outward from center for a subtle lens look.
                float2 dir = i.uv - 0.5;
                float  ca  = _ChromaStrength * length(dir);
                float  cr  = tex2D(_MainTex, i.uv + dir * ca).r;
                float  cg  = tex2D(_MainTex, i.uv).g;
                float  cb  = tex2D(_MainTex, i.uv - dir * ca).b;
                float3 caCol = float3(cr, cg, cb);

                // === PASS 2: Bilateral Smoothing ===
                // Averages neighbors weighted by color similarity → smooth flat
                // areas while keeping sharp edges (like anime's clean look).
                float3 center = caCol;
                float3 acc    = center;
                float  wSum   = 1.0;
                float  sharp  = _BilateralSharp;

                [unroll]
                for (int k = 0; k < 8; k++)
                {
                    float3 nb = tex2D(_MainTex, i.uv + kOffsets[k] * texel).rgb;
                    float  dn = length(center - nb);
                    float  w  = exp(-dn * dn * sharp);
                    acc  += nb * w;
                    wSum += w;
                }
                float3 col = lerp(center, acc / wSum, _SmoothStrength);

                // === PASS 3: Sobel Edge Detection → Anime Outlines ===
                // Full 3×3 Sobel on luminance; thickness scaled by _OutlineThickness.
                float2 et = texel * _OutlineThickness;
                float l00 = Lum(tex2D(_MainTex, i.uv + float2(-1,-1)*et).rgb);
                float l10 = Lum(tex2D(_MainTex, i.uv + float2( 0,-1)*et).rgb);
                float l20 = Lum(tex2D(_MainTex, i.uv + float2( 1,-1)*et).rgb);
                float l01 = Lum(tex2D(_MainTex, i.uv + float2(-1, 0)*et).rgb);
                float l21 = Lum(tex2D(_MainTex, i.uv + float2( 1, 0)*et).rgb);
                float l02 = Lum(tex2D(_MainTex, i.uv + float2(-1, 1)*et).rgb);
                float l12 = Lum(tex2D(_MainTex, i.uv + float2( 0, 1)*et).rgb);
                float l22 = Lum(tex2D(_MainTex, i.uv + float2( 1, 1)*et).rgb);

                float gx = -l00 - 2.0*l01 - l02 + l20 + 2.0*l21 + l22;
                float gy = -l00 - 2.0*l10 - l20 + l02 + 2.0*l12 + l22;
                // Smoothstep upper bound = 3× threshold to keep outline width consistent
                static const float kEdgeRangeMul = 3.0;
                float edge     = sqrt(gx*gx + gy*gy);
                float edgeMask = smoothstep(_OutlineThreshold,
                                            _OutlineThreshold * kEdgeRangeMul, edge);

                // === PASS 4: Saturation + Contrast + Brightness ===
                float3 hsv = RGBtoHSV(col);
                hsv.y = saturate(hsv.y * _Saturation);     // vivid anime colors
                hsv.z = saturate(hsv.z * _Brightness);
                col   = HSVtoRGB(hsv);
                col   = saturate((col - 0.5) * _Contrast + 0.5);

                // === PASS 5: Warm/Cool Cel-Shading ===
                // Highlights get a warm golden tint; shadows get a cool/purple tint.
                float br = Lum(col);
                float shadowMask = smoothstep(
                    _ShadowThreshold - _ShadowSoftness,
                    _ShadowThreshold + _ShadowSoftness,
                    br
                );
                float3 shadowCol    = col * _CoolTint.rgb * _ShadowDark;
                float3 highlightCol = col * _WarmTint.rgb;
                col = lerp(shadowCol, highlightCol, shadowMask);

                // === PASS 6: Luminance Quantisation (cel bands) ===
                // Snap luminance to N discrete steps for the flat cel-shaded look.
                float lumNow   = Lum(col);
                float steps    = max(2.0, _ShadowSteps);
                float lumSnap  = floor(lumNow * steps + 0.5) / steps;
                float lumScale = (lumNow > 0.001) ? (lumSnap / lumNow) : 1.0;
                col = saturate(col * lerp(1.0, lumScale, _CelBlend));

                // === PASS 7: Bloom / Light Glow (Shinkai hallmark) ===
                // Samples a wide neighbourhood to accumulate light from bright
                // regions and scatter it back as a warm glow — the distinctive
                // Makoto Shinkai golden-sunlight bloom.
                float3 bloomAcc = float3(0, 0, 0);
                float  bloomW   = 0.0;
                [unroll]
                for (int b = 0; b < 16; b++)
                {
                    float3 s = tex2D(_MainTex, i.uv + kBloomOffsets[b] * texel * _BloomRadius).rgb;
                    float bright = max(Lum(s) - _BloomThreshold, 0.0);
                    float w = bright * bright;   // weight by squared brightness above threshold
                    bloomAcc += s * w;
                    bloomW   += w;
                }
                float3 bloom = (bloomW > 0.001)
                    ? (bloomAcc / bloomW) * _BloomIntensity * (bloomW / 16.0)
                    : float3(0, 0, 0);
                bloom *= _WarmTint.rgb;   // warm tint on bloom for Shinkai golden-light feel
                col = saturate(col + bloom * 0.30);

                // === PASS 8: Atmospheric Haze ===
                // Blends a cool-blue haze into the brightest regions to recreate
                // Shinkai's signature dreamy, over-exposed sky look.
                float hazeMask = smoothstep(0.55, 0.95, Lum(col));
                col = lerp(col,
                           col * _HazeColor.rgb + _HazeColor.rgb * 0.05,
                           hazeMask * _HazeIntensity);

                // === PASS 9: Draw Outlines ===
                col = lerp(col, float3(0.0, 0.0, 0.0), edgeMask * _OutlineStrength);

                // === PASS 10: Vignette (cinematic framing) ===
                float  vigDist  = length(i.uv - 0.5) / _VignetteRadius;
                float  vignette = 1.0 - smoothstep(0.5, 1.0, vigDist) * _VignetteStrength;
                col *= vignette;

                return float4(saturate(col), 1.0);
            }
            ENDCG
        }
    }
}