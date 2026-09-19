Shader "Custom/UnlitURP01"
{
    Properties
    {
        [Header (Base (Lit) Settings)][Space(2)]
        [MainColor] _BaseColor("Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseTex("Texture", 2D) = "white" {}

        //Shade Settings
        [Space(5)][Header (Shade Settings)][Space(2)]
        _ShadeTex("Texture", 2D) = "black" {}
        _ShadeThresh("Threshold", Float) = 0.1
        _ShadePat("Pattern", 2D) = "white" {}

        //Metallic, Rimlight, Reflection mask
        [Space(5)][Header (Effect Masking)][Space(2)]
        _EffectTex("Effects Texture", 2D) = "green"{} 
        _MetalTintTex("Metallic Tint (Additive)", 2D) = "white" {}

        [Space(5)][Header (Anisotropic Settings)][Space(2)]
        _AnisoPow("Power", Float) = 3
        _AnisoIntensity("Intensity", Float) = 6.3
        _AnisoThresh("Threshold", Float) = 0.6

        //Rimlight Settings
        [Space(5)][Header (Rimlight Settings)][Space(2)]
        _RimThickness("Thickness", Float) = 20
        _RimThicknessMultiplier("Thickness Multiplier", Float) = 0.001
        _RimNoiseVelocity ("Noise Velocity", Float) = 0.1
        _RimNoiseMag ("Noise Magnitude", Range(0.0, 1.0)) = 0.7
        _RimNoiseScale ("Noise Scale", Float) = 20
        _RimColor("Color", Color) = (1, 0.6, 1, 1)
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
                float3 positionWS : TEXCOORD2;
            };

            TEXTURE2D(_BaseTex);
            SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ShadeTex);
            SAMPLER(sampler_ShadeTex);
            TEXTURE2D(_ShadePat);
            SAMPLER(sampler_ShadePat);
            TEXTURE2D(_EffectTex);
            SAMPLER(sampler_EffectTex);
            TEXTURE2D(_MetalTintTex);
            SAMPLER(sampler_MetalTintTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _RimColor;
                half4 _LineColor;
                float _ShadeThresh;
                float _RimThickness;
                float _RimThicknessMultiplier;
                float _RimNoiseVelocity;
                float _RimNoiseMag;
                float _RimNoiseScale;
                float _AnisoPow;
                float _AnisoIntensity;
                float _AnisoThresh;
                float4 _BaseTex_ST;
                float4 _ShadeTexST_ST;
                float4 _ShadePat_ST;
                float4 _EffectTex_ST;
                float4 _MetalTintTex_ST;
            CBUFFER_END

            //Vertex Shader
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.positionWS = TransformObjectToWorld(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseTex);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }

            //Fragment Shader
            half4 frag(Varyings IN) : SV_Target
            {
                //get blue&red pass of effects tex
                half4 mask = SAMPLE_TEXTURE2D_LOD(
                    _EffectTex,
                    sampler_EffectTex,
                    IN.uv,
                    0
                    );
                float metalMask = mask.b;
                float anisoMask = mask.r;

                //calculating dot product between mainlight and vertex normal
                Light mainLight = GetMainLight();
                float3 vertexNormal = normalize(IN.normalWS);
                float3 lightDirection = normalize(mainLight.direction);
                float3 viewDirection = normalize (GetWorldSpaceViewDir(IN.positionWS));
                half4 lightColor = half4(mainLight.color, 1.0);
                float VNdotLD = saturate(dot(vertexNormal, lightDirection));
                float lightValue = step(_ShadeThresh, VNdotLD);
                float2 metallicUV = pow (dot(vertexNormal, normalize(viewDirection + lightDirection)), 2);
                float anisoFresnel = pow((1.0 - saturate(dot(vertexNormal, viewDirection))), _AnisoPow) * _AnisoIntensity;
                float anisoShade = saturate(1-anisoFresnel)* anisoMask * VNdotLD;
                float anisoStepped = step(_AnisoThresh, anisoShade);

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

                //combine base and metal
                half4 metalicColor = SAMPLE_TEXTURE2D(
                                _MetalTintTex,
                                sampler_MetalTintTex,
                                metallicUV
                                );

                half4 metalShade = finalColor + metalicColor;

                half4 metalMixColor = lerp(
                    finalColor + 0.5 * anisoStepped * lightColor,
                    metalShade,
                    metalMask
                    );

                return metalMixColor;
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
            TEXTURE2D(_ShadePat);
            SAMPLER(sampler_ShadePat);
            TEXTURE2D(_EffectTex);
            SAMPLER(sampler_EffectTex);
            TEXTURE2D(_MetalTintTex);
            SAMPLER(sampler_MetalTintTex);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _RimColor;
                half4 _LineColor;
                float _ShadeThresh;
                float _RimThickness;
                float _RimThicknessMultiplier;
                float _RimNoiseVelocity;
                float _RimNoiseMag;
                float _RimNoiseScale;
                float _AnisoPow;
                float _AnisoIntensity;
                float _AnisoThresh;
                float4 _BaseTex_ST;
                float4 _ShadeTexST_ST;
                float4 _ShadePat_ST;
                float4 _EffectTex_ST;
                float4 _MetalTintTex_ST;
            CBUFFER_END


            //noise generation

            float Random2D(float2 p)
            {
                return frac(
                    sin(dot(p, float2(12.9898, 78.233)))
                    * 43758.5453
                );
            }

            float ValueNoise2D(float2 q)
            {
                // Integer grid cell
                float2 cell = floor(q);
                // Position inside that cell: 0 -> 1
                float2 local = frac(q);
                // Random value at each corner
                float a = Random2D(cell);
                float b = Random2D(cell + float2(1.0, 0.0));
                float c = Random2D(cell + float2(0.0, 1.0));
                float d = Random2D(cell + float2(1.0, 1.0));
                // Smooth interpolation curve
                float2 smoothUV =
                    local * local * (3.0 - 2.0 * local);
                // Interpolate horizontally
                float bottom = lerp(a, b, smoothUV.x);
                float top    = lerp(c, d, smoothUV.x);
                // Then vertically
                return lerp(bottom, top, smoothUV.y);
            }

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
                // Animate the noise by modifying the UV over time
                float rimUpdateSpeed = 10 * _RimNoiseVelocity;
                float2 animateMultiplier = IN.uv * _RimNoiseScale
                                         + float2(_Time.y * rimUpdateSpeed,
                                                  _Time.y * rimUpdateSpeed * 1.5);
                
                // Calculate raw noise value
                float noise = (1 -_RimNoiseMag) + _RimNoiseMag * ValueNoise2D(animateMultiplier);

                //shifting the hull in the opposite direction of the light
                Light mainLight = GetMainLight();
                float3 lightDirection = normalize(mainLight.direction);
                float3 extrusionAmount = -1 * lightDirection * _RimThickness * noise * _RimThicknessMultiplier * rimMask;
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
