Shader "Custom/SoftAnimeShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ShadowThreshold ("Shadow Threshold", Range(0.3,0.7)) = 0.5
        _ShadowSoftness ("Shadow Softness", Range(0.01,0.2)) = 0.08
        _EdgeStrength ("Edge Strength", Range(0,2)) = 1.0
        _WarmTint ("Warm Tint", Color) = (1.05,1.02,1.0,1)
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
            float _ShadowThreshold;
            float _ShadowSoftness;
            float _EdgeStrength;
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

            fixed4 frag(v2f i) : SV_Target
            {
                float2 texel = 1.0 / _ScreenParams.xy;

                // Slight smoothing
                float3 col =
                    (tex2D(_MainTex, i.uv).rgb +
                     tex2D(_MainTex, i.uv + float2(texel.x,0)).rgb +
                     tex2D(_MainTex, i.uv - float2(texel.x,0)).rgb +
                     tex2D(_MainTex, i.uv + float2(0,texel.y)).rgb +
                     tex2D(_MainTex, i.uv - float2(0,texel.y)).rgb) / 5.0;

                // Apply warm anime tint
                col *= _WarmTint.rgb;

                // Soft shadow ramp
                float light = luminance(col);
                float shadowMask = smoothstep(
                    _ShadowThreshold - _ShadowSoftness,
                    _ShadowThreshold + _ShadowSoftness,
                    light
                );

                float3 shadowColor = col * 0.75; // darker soft shadow
                col = lerp(shadowColor, col, shadowMask);

                // Subtle edge detection (clean)
                float3 right = tex2D(_MainTex, i.uv + float2(texel.x,0)).rgb;
                float3 up = tex2D(_MainTex, i.uv + float2(0,texel.y)).rgb;

                float edge = abs(luminance(col) - luminance(right)) +
                             abs(luminance(col) - luminance(up));

                float edgeMask = smoothstep(0.15, 0.25, edge);
                col = lerp(col, float3(0,0,0), edgeMask * 0.5 * _EdgeStrength);

                return float4(col, 1);
            }
            ENDCG
        }
    }
}