Shader "Custom/UnlitURP01"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseTex("Lit Texture", 2D) = "white" {}
        _ShadeTex("Shade Texture", 2D) = "black" {} //unimplemented
        _ShadeThresh("Shade Threshold", Float) = 0.1

        //Metallic, Rimlight, Reflection mask
        _EffectTex("Effects Texture", 2D) = "green"{} //unimplemented

        //Rimlight Settings 
        _RimThickness("Rimlight Thickness", Float) = 10
        _RimThicknessMultiplier("Rimlight Thickness Multiplier", Float) = 0.001
        _RimColor("Rimlight Color", Color) = (1, 1, 1, 1)
        _LineColor("Secondary Line Color", Color) = (1, 1, 1, 0) 
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ShadeTex);
            SAMPLER(sampler_ShadeTex);
            TEXTURE2D(_EffectTex);
            SAMPLER(sampler_EffectTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _RimColor;
                half4 _LineColor;
                float _ShadeThresh;
                float _RimThickness;
                float _RimThicknessMultiplier;
                float4 _BaseTex_ST;
                float4 _ShadeTexST_ST;
                float4 _EffectTex_ST;
            CBUFFER_END

            //Vertex Shader
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            //Fragment Shader
            half4 frag(Varyings IN) : SV_Target
            {
                
                //calculating dot product between mainlight and vertex normal
                Light mainLight = GetMainLight();
                float3 vertexNormal = normalize(IN.normalWS);
                float3 lightDirection = normalize(mainLight.direction);
                half4 lightColor = half4(mainLight.color, 1.0);
                float VNdotLD = saturate(dot(vertexNormal, lightDirection));
                float lightValue = step(_ShadeThresh, VNdotLD);

                //base lit color
                half4 baseColor = SAMPLE_TEXTURE2D(
                                _BaseTex,
                                sampler_BaseTex,
                                IN.uv
                                ) *_BaseColor * lightColor;
                // shadow color
                half4 shadowColor = SAMPLE_TEXTURE2D(
                                _ShadeTex,
                                sampler_ShadeTex,
                                IN.uv
                                ) * _BaseColor * lightColor;

                //combined shadow and base color
                half4 finalColor = lerp(
                    shadowColor,
                    baseColor,
                    lightValue
                    );

                return finalColor;
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
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAl;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ShadeTex);
            SAMPLER(sampler_ShadeTex);
            TEXTURE2D(_EffectTex);
            SAMPLER(sampler_EffectTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _RimColor;
                half4 _LineColor;
                float _ShadeThresh;
                float _RimThickness;
                float _RimThicknessMultiplier;
                float4 _BaseTex_ST;
                float4 _ShadeTexST_ST;
                float4 _EffectTex_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                half4 mask = SAMPLE_TEXTURE2D_LOD(
                    _EffectTex,
                    sampler_EffectTex,
                    IN.uv,
                    0
                    );
                float rimMask = mask.g;
                //shifting the hull in the opposite direction of the light
                Light mainLight = GetMainLight();
                float3 lightDirection = normalize(mainLight.direction);
                float3 extrusionAmount = -1 * lightDirection * _RimThickness  * _RimThicknessMultiplier * rimMask;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz + extrusionAmount) ;
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                //calculating dot product between mainlight and vertex normal
                Light mainLight = GetMainLight();
                float3 vertexNormal = normalize(IN.normalWS);
                float3 lightDirection = normalize(mainLight.direction);
                float VNdotLD = saturate(dot(vertexNormal, lightDirection));
                float lightValue = step(_ShadeThresh, VNdotLD);

                half4 finalColor = lerp(
                    _RimColor,
                    _LineColor,
                    lightValue
                    );

                clip(finalColor.a - 0.001);
                return finalColor;
            }
            ENDHLSL
        }

    }
}
