Shader "Custom/UnlitURP01"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseTex("Lit Texture", 2D) = "white" {}
        _ShadeTex("Shade Texture", 2D) = "black" {} //unimplemented

        //Rimlight Settings 
        _RimThickness("Rimlight Thickness", Float) = 1
        _RimThicknessMultiplier("Rimlight Thickness Multiplier", Float) = 0.001
        _RimColor("Rimlight Color", Color) = (1, 1, 1, 1) 
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        
        //Regular Pass with no backface culling
        
        Pass
        {
            Name "Regular Pass"
            Tags {
                "LightMode" = "UniversalForward"
                "Queue" = "Geometry"

                }

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
                half4 _RimColor;
                float _RimThickness;
                float _RimThicknessMultiplier;
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
            Name "Rimlight Pass"
            Tags {
                "LightMode" = "SRPDefaultUnlit" 
                "Queue" = "Geometry - 1"
                }

            Cull Front

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
                half4 _BaseColor;
                half4 _RimColor;
                float _RimThickness;
                float _RimThicknessMultiplier;
                float4 _BaseTex_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz + (IN.normal * _RimThickness  * _RimThicknessMultiplier)) ;
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
