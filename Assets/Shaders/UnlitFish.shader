Shader "Custom/UnlitFish"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        _FishWaviness("Fish Waviness", Float) = 0.2
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
                float _FishWaviness;
            CBUFFER_END

            float3 rotate_vector(float3 v, float4 q) {
                return v + 2.0 * cross(q.xyz, cross(q.xyz, v) + q.w * v);
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float wiggleVal = -1 * IN.positionOS.y * _FishWaviness + (_Time.y * 3);
                float s = sin(wiggleVal);
                float yaw = s * 0.1; 
                float4 wiggleQuat = float4(0, sin(yaw), sin(yaw), cos(yaw));
                float3 posAdj = rotate_vector(IN.positionOS.xyz, wiggleQuat);
                OUT.positionHCS = TransformObjectToHClip(posAdj);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.uv) * _BaseColor;
                return color;
            }
            ENDHLSL
        }
    }
}
