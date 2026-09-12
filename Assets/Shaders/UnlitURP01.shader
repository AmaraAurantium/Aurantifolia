Shader "Custom/UnlitURP01"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseTex("Lit Texture", 2D) = "white" {}
        _ShadeTex("Shade Texture", 2D) = "black" {} //unimplemented

        //Rimlight Settings 
        _RimThickness("Rimlight Thickness", Float) = 0.02 //unimplemented
        _RimColor("Rimlight Color", Color) = (1, 1, 1, 1) //unimplemented
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        
        //Regular Pass with no backface culling
        
        Pass
        {
            Cull Off
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

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseTex_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, IN.uv) * _BaseColor;
                return color;
            }
            ENDHLSL
        }
        
        //Rimlight Pass through Inverse hull
        Pass
        {
            Cull Front
            ZTest Always
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAl;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _RimColor;
                float _RimThickness;
                float4 _BaseTex_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz + (IN.normal * _RimThickness)) ;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = _RimColor;
                return color;
            }
            ENDHLSL
        }

    }
}
