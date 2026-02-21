Shader "Custom/FullAnimeShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OutlineThickness ("Outline Thickness", Range(0.5,3.0)) = 1.5
        _OutlineStrength ("Outline Strength", Range(0,1)) = 1.0
        _ShadowThreshold1 ("Shadow Threshold 1 (Dark)", Range(0.1,0.5)) = 0.25
        _ShadowThreshold2 ("Shadow Threshold 2 (Mid)", Range(0.3,0.7)) = 0.52
        _SaturationBoost ("Saturation Boost", Range(1.0,3.0)) = 1.8
        _ColorSteps ("Color Quantization Steps", Range(3,8)) = 5
        _WarmTint ("Warm Tint", Color) = (1.08,1.02,0.92,1)
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
            float _OutlineThickness;
            float _OutlineStrength;
            float _ShadowThreshold1;
            float _ShadowThreshold2;
            float _SaturationBoost;
            float _ColorSteps;
            float4 _WarmTint;

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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float luminance(float3 c)
            {
                return dot(c, float3(0.299, 0.587, 0.114));
            }

            // Boost saturation so colors look vivid and anime-like
            float3 saturate_boost(float3 col, float amount)
            {
                float lum = luminance(col);
                return lerp(float3(lum, lum, lum), col, amount);
            }

            // Quantize a value into exactly 'steps' discrete levels across [0,1]
            float quantize(float v, float steps)
            {
                return floor(v * (steps - 1)) / (steps - 1);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float2 texel = 1.0 / _ScreenParams.xy;
                float2 offset = texel * _OutlineThickness;

                // Sobel edge detection using 8 neighbours for clean anime outlines
                float3 s00 = tex2D(_MainTex, i.uv + float2(-offset.x,  offset.y)).rgb;
                float3 s10 = tex2D(_MainTex, i.uv + float2(        0,  offset.y)).rgb;
                float3 s20 = tex2D(_MainTex, i.uv + float2( offset.x,  offset.y)).rgb;
                float3 s01 = tex2D(_MainTex, i.uv + float2(-offset.x,         0)).rgb;
                float3 s21 = tex2D(_MainTex, i.uv + float2( offset.x,         0)).rgb;
                float3 s02 = tex2D(_MainTex, i.uv + float2(-offset.x, -offset.y)).rgb;
                float3 s12 = tex2D(_MainTex, i.uv + float2(        0, -offset.y)).rgb;
                float3 s22 = tex2D(_MainTex, i.uv + float2( offset.x, -offset.y)).rgb;

                float gx = luminance(-s00 - 2*s01 - s02 + s20 + 2*s21 + s22);
                float gy = luminance(-s00 - 2*s10 - s20 + s02 + 2*s12 + s22);
                float edge = sqrt(gx*gx + gy*gy);
                float edgeMask = step(0.15, edge); // hard cut — clean anime ink line

                // Base color with mild smoothing
                float3 col =
                    (tex2D(_MainTex, i.uv).rgb +
                     tex2D(_MainTex, i.uv + float2( offset.x, 0)).rgb +
                     tex2D(_MainTex, i.uv + float2(-offset.x, 0)).rgb +
                     tex2D(_MainTex, i.uv + float2(0,  offset.y)).rgb +
                     tex2D(_MainTex, i.uv + float2(0, -offset.y)).rgb) / 5.0;

                // Anime warm tint
                col *= _WarmTint.rgb;

                // Saturation boost for vibrant anime colours
                col = saturate_boost(col, _SaturationBoost);

                // Hard 3-band cel shading (dark shadow / mid shadow / lit)
                float lum = luminance(col);
                float3 darkShadow = col * 0.45;
                float3 midShadow  = col * 0.72;
                float3 lit        = col;

                float3 celCol = darkShadow;
                celCol = lerp(celCol, midShadow, step(_ShadowThreshold1, lum));
                celCol = lerp(celCol, lit,       step(_ShadowThreshold2, lum));

                // Quantize colours to flatten photorealistic gradients
                celCol.r = quantize(celCol.r, _ColorSteps);
                celCol.g = quantize(celCol.g, _ColorSteps);
                celCol.b = quantize(celCol.b, _ColorSteps);

                // Apply strong black outlines
                celCol = lerp(celCol, float3(0,0,0), edgeMask * _OutlineStrength);

                return float4(celCol, 1);
            }
            ENDCG
        }
    }
}