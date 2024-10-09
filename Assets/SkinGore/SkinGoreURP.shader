Shader "Organic/Skin Gore" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		[NoScaleOffset] _NormalMap ("Normal Map", 2D) = "bump" {}
		_NrmStrength ("Normal Strength", Range(-2,2)) = 1
		[NoScaleOffset] _Metallic ("Smoothness/Metallic Map", 2D) = "white" {}
		_Glossiness ("Smoothness", Range(0,1)) = 1
		_Metal ("Metallic", Range(0,1)) = 1
		_DetailMap ("Blending Detail Map", 2D) = "grey" {}
		_Hardness ("Blending Hardness", Range(0,1)) = 0.5
		_EdgeSize ("Edge Size", Range(0,1)) = 0.2
		_EdgeColor("Edge Color", Color) = (1,1,1,1)
		_EdgeGlossiness ("Edge Smoothness", Range(0,1)) = 1
		[PerRendererData] _GoreDamage ("Gore Damage Map", 2D) = "white" {}

	}

	SubShader {
		Tags { "RenderType"="TransparentCutout" "Queue"="Geometry"}
		LOD 200

		AlphaToMask On
		Pass
        {
            HLSLPROGRAM
		    #pragma vertex vert
            #pragma fragment frag

		    #pragma target 5.0

            #define SHADERPASS SHADERPASS_FORWARD
            #define _NORMAL_DROPOFF_TS 1
            #define _EMISSION
            #define _NORMALMAP 1

            #if defined(SHADER_API_MOBILE)
                #define _ADDITIONAL_LIGHTS_VERTEX
            #else              
                #pragma multi_compile_fragment  _  _MAIN_LIGHT_SHADOWS_CASCADE

            //#define DYNAMIC_SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

            //#define DYNAMIC_ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS


            //#define DYNAMIC_ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS

                #define _SHADOWS_SOFT 1

                #define _REFLECTION_PROBE_BLENDING
                //#pragma shader_feature_fragment _REFLECTION_PROBE_BOX_PROJECTION
                // We don't need a keyword for this! the w component of the probe position already branches box vs non-box, & so little cost on pc it doesn't matter
                #define _REFLECTION_PROBE_BOX_PROJECTION 

            // Begin Injection STANDALONE_DEFINES from Injection_SSR.hlsl ----------------------------------------------------------
            #pragma multi_compile _ _SLZ_SSR_ENABLED
            #pragma shader_feature_local _ _NO_SSR
            #if defined(_SLZ_SSR_ENABLED) && !defined(_NO_SSR) && !defined(SHADER_API_MOBILE)
            	#define _SSR_ENABLED
            #endif
            // End Injection STANDALONE_DEFINES from Injection_SSR.hlsl ----------------------------------------------------------

            #endif

            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _VOLUMETRICS_ENABLED
            #pragma multi_compile_fog
            #pragma skip_variants FOG_LINEAR FOG_EXP
            //#pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma multi_compile_fragment _ _DETAILS_ON
            //#pragma multi_compile_fragment _ _EMISSION_ON

            // Begin Injection UNIVERSAL_DEFINES from Injection_SSR_CBuffer_Posespace.hlsl ----------------------------------------------------------
            #define _SSRTemporalMul 0
            // End Injection UNIVERSAL_DEFINES from Injection_SSR_CBuffer_Posespace.hlsl ----------------------------------------------------------

            #if defined(LITMAS_FEATURE_LIGHTMAPPING)
                #pragma multi_compile _ LIGHTMAP_ON
                #pragma multi_compile _ DYNAMICLIGHTMAP_ON
                #pragma multi_compile _ DIRLIGHTMAP_COMBINED
                #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #endif


            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/TextureStack.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Editor/ShaderGraph/Includes/ShaderPass.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZLighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZBlueNoise.hlsl"

            // Begin Injection INCLUDES from Injection_Impacts_CBuffer.hlsl ----------------------------------------------------------
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PosespaceImpacts.hlsl"
            // End Injection INCLUDES from Injection_Impacts_CBuffer.hlsl ----------------------------------------------------------
            // Begin Injection INCLUDES from Injection_Impacts.hlsl ----------------------------------------------------------
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/PosespaceImpacts.hlsl"
            // End Injection INCLUDES from Injection_Impacts.hlsl ----------------------------------------------------------
            // Begin Injection INCLUDES from Injection_SSR.hlsl ----------------------------------------------------------
            #if !defined(SHADER_API_MOBILE)
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SLZLightingSSR.hlsl"
            #endif
            // End Injection INCLUDES from Injection_SSR.hlsl ----------------------------------------------------------



            struct VertIn
            {
                float4 vertex   : POSITION;
                float3 normal    : NORMAL;
                float4 tangent   : TANGENT;
            	float4 uv0 : TEXCOORD0;
            	float4 uv1 : TEXCOORD1;
            	float4 uv2 : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VertOut
            {
                float4 vertex       : SV_POSITION;
            	float4 uv0XY_bitZ_fog : TEXCOORD0;
            #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
            	float4 uv1 : TEXCOORD1;
            #endif
            	half4 SHVertLights : TEXCOORD2;
            	half4 normXYZ_tanX : TEXCOORD3;
            	float3 wPos : TEXCOORD4;

            // Begin Injection INTERPOLATORS from Injection_SSR.hlsl ----------------------------------------------------------
            	float4 lastVertex : TEXCOORD5;
            // End Injection INTERPOLATORS from Injection_SSR.hlsl ----------------------------------------------------------
            // Begin Injection INTERPOLATORS from Injection_NormalMaps.hlsl ----------------------------------------------------------
            	half4 tanYZ_bitXY : TEXCOORD6;
            // End Injection INTERPOLATORS from Injection_NormalMaps.hlsl ----------------------------------------------------------
            // Begin Injection INTERPOLATORS from Injection_Impacts.hlsl ----------------------------------------------------------
            	float3 unskinnedObjPos : TEXCOORD7;
            // End Injection INTERPOLATORS from Injection_Impacts.hlsl ----------------------------------------------------------

                UNITY_VERTEX_INPUT_INSTANCE_ID
                    UNITY_VERTEX_OUTPUT_STEREO
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            TEXTURE2D(_NormalMap);
            TEXTURE2D(_Metallic);

            TEXTURE2D(_DetailMap);
            SAMPLER(sampler_DetailMap);

            // Begin Injection UNIFORMS from Injection_Emission.hlsl ----------------------------------------------------------
            TEXTURE2D(_EmissionMap);
            // End Injection UNIFORMS from Injection_Emission.hlsl ----------------------------------------------------------

            CBUFFER_START(UnityPerMaterial)
            // Begin Injection MATERIAL_CBUFFER_EARLY from Injection_Impacts_CBuffer.hlsl ----------------------------------------------------------
                half4x4 EllipsoidPosArray[HitMatrixCount];
                int _NumberOfHits;
                half4 _HitColor;

            // End Injection MATERIAL_CBUFFER_EARLY from Injection_Impacts_CBuffer.hlsl ----------------------------------------------------------
                half _NrmStrength;
		        half _Glossiness;
		        half _Metal;
		        fixed4 _Color;
		        half _Hardness;
		        half _EdgeSize;
		        fixed4 _EdgeColor;
		        half _EdgeGlossiness;
               
            CBUFFER_END

            int _Surface = 1;

            half3 OverlayBlendDetail(half source, half3 destination)
            {
                half3 switch0 = round(destination); // if destination >= 0.5 then 1, else 0 assuming 0-1 input
                half3 blendGreater = mad(mad(2.0, destination, -2.0), 1.0 - source, 1.0); // (2.0 * destination - 2.0) * ( 1.0 - source) + 1.0
                half3 blendLesser = (2.0 * source) * destination;
                return mad(switch0, blendGreater, mad(-switch0, blendLesser, blendLesser)); // switch0 * blendGreater + (1 - switch0) * blendLesser 
                //return half3(destination.r > 0.5 ? blendGreater.r : blendLesser.r,
                //             destination.g > 0.5 ? blendGreater.g : blendLesser.g,
                //             destination.b > 0.5 ? blendGreater.b : blendLesser.b
                //            );
            }


            VertOut vert(VertIn v)
            {
                VertOut o = (VertOut)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.wPos = TransformObjectToWorld(v.vertex.xyz);
                o.vertex = TransformWorldToHClip(o.wPos);
                o.uv0XY_bitZ_fog.xy = v.uv0.xy;

                #if defined(LIGHTMAP_ON) || defined(DIRLIGHTMAP_COMBINED)
                    OUTPUT_LIGHTMAP_UV(v.uv1.xy, unity_LightmapST, o.uv1.xy);
                #endif

                #ifdef DYNAMICLIGHTMAP_ON
                    OUTPUT_LIGHTMAP_UV(v.uv2.xy, unity_DynamicLightmapST, o.uv1.zw);
                #endif

                // Exp2 fog
                half clipZ_0Far = UNITY_Z_0_FAR_FROM_CLIPSPACE(o.vertex.z);
                o.uv0XY_bitZ_fog.w = unity_FogParams.x * clipZ_0Far;

            // Begin Injection VERTEX_NORMALS from Injection_NormalMaps.hlsl ----------------------------------------------------------
            	VertexNormalInputs ntb = GetVertexNormalInputs(v.normal, v.tangent);
            	o.normXYZ_tanX = half4(ntb.normalWS, ntb.tangentWS.x);
            	o.tanYZ_bitXY = half4(ntb.tangentWS.yz, ntb.bitangentWS.xy);
            	o.uv0XY_bitZ_fog.z = ntb.bitangentWS.z;
            // End Injection VERTEX_NORMALS from Injection_NormalMaps.hlsl ----------------------------------------------------------

                o.SHVertLights = 0;
                // Calculate vertex lights and L2 probe lighting on quest 
                o.SHVertLights.xyz = VertexLighting(o.wPos, o.normXYZ_tanX.xyz);
            #if !defined(LIGHTMAP_ON) && !defined(DYNAMICLIGHTMAP_ON) && defined(SHADER_API_MOBILE)
                o.SHVertLights.xyz += SampleSHVertex(o.normXYZ_tanX.xyz);
            #endif

            // Begin Injection VERTEX_END from Injection_SSR.hlsl ----------------------------------------------------------
            	#if defined(_SSR_ENABLED)
            		float4 lastWPos = mul(GetPrevObjectToWorldMatrix(), v.vertex);
            		o.lastVertex = mul(prevVP, lastWPos);
            	#endif
            // End Injection VERTEX_END from Injection_SSR.hlsl ----------------------------------------------------------
            // Begin Injection VERTEX_END from Injection_Impacts.hlsl ----------------------------------------------------------
                o.unskinnedObjPos = v.uv1.xyz;
            // End Injection VERTEX_END from Injection_Impacts.hlsl ----------------------------------------------------------
                return o;
            }

            half overlay(float a, float b)
		    {
		    	if(a<0.5) return 2*a*b;
		    	else return 1-2*(1-a)*(1-b);
		    }

		    // inverse lerp function
		    float alerp(float a, float b, float t) {
		    	return (t - a) / (b - a);
		    }

            half4 frag(VertOut i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

            /*---------------------------------------------------------------------------------------------------------------------------*/
            /*---Read Input Data---------------------------------------------------------------------------------------------------------*/
            /*---------------------------------------------------------------------------------------------------------------------------*/
            float2 uv_main = mad(float2(i.uv0XY_bitZ_fog.xy), _MainTex_ST.xy, _MainTex_ST.zw);
            float2 uv_detail = mad(float2(i.uv0XY_bitZ_fog.xy), _DetailMap_ST.xy, _DetailMap_ST.zw);
                
            // Begin Injection FRAG_POST_INPUTS from Injection_Impacts.hlsl ----------------------------------------------------------
                half2 goreData = GetClosestImpactUV(i.unskinnedObjPos, EllipsoidPosArray, _NumberOfHits);
                
                half mask = tex2D (_DetailMap, IN.uv_DetailMap).r;
			    mask = overlay(overlay(goreData.r, mask), mask);
			    _Hardness = 1 - _Hardness;
			    float Alpha = saturate(alerp(0.5 - _Hardness / 2, 0.5 + _Hardness / 2, mask));
			    // get edges for better transition
			    half edge = saturate(alerp(0.5-(_Hardness / 2) - _EdgeSize, 0.5- _EdgeSize, 1-mask));
			    clip(mask-0.1);

                fixed4 c = SAMPLE_TEXTURE2D (_MainTex, sampler_MainTex, uv_main) * _Color;
			    float3 albedo = c.rgb * lerp(1, _EdgeColor, edge);


                half  geoSmooth = 1;
                half4 normalMap = half4(0, 0, 1, 0);

            // Begin Injection NORMAL_MAP from Injection_NormalMaps.hlsl ----------------------------------------------------------


                fixed3 nrm = UnpackNormal(SAMPLE_TEXTURE2D (_NormalMap, sampler_MainTex, uv_main));
			    nrm = lerp(fixed3(0,0,1), nrm, _NrmStrength);

			    // squish normals at edge to appear inset
			    nrm.xy = lerp(nrm.xy, nrm.xy * -3, edge);
            // End Injection NORMAL_MAP from Injection_NormalMaps.hlsl ----------------------------------------------------------

                float metallic = SAMPLE_TEXTURE2D (_Metallic, sampler_MainTex, uv_main).r * _Metal;
			    float smoothness =  SAMPLE_TEXTURE2D (_Metallic, sampler_MainTex, uv_main).a * lerp(_Glossiness, _EdgeGlossiness, edge);

            /*---------------------------------------------------------------------------------------------------------------------------*/
            /*---Transform Normals To Worldspace-----------------------------------------------------------------------------------------*/
            /*---------------------------------------------------------------------------------------------------------------------------*/

            // Begin Injection NORMAL_TRANSFORM from Injection_NormalMaps.hlsl ----------------------------------------------------------
            	half3 normalWS = i.normXYZ_tanX.xyz;
            	half3x3 TStoWS = half3x3(
            		i.normXYZ_tanX.w, i.tanYZ_bitXY.z, normalWS.x,
            		i.tanYZ_bitXY.x, i.tanYZ_bitXY.w, normalWS.y,
            		i.tanYZ_bitXY.y, i.uv0XY_bitZ_fog.z, normalWS.z
            		);
            	normalWS = mul(TStoWS, nrm);
            	normalWS = normalize(normalWS);
            // End Injection NORMAL_TRANSFORM from Injection_NormalMaps.hlsl ----------------------------------------------------------


            /*---------------------------------------------------------------------------------------------------------------------------*/
            /*---Lighting Calculations---------------------------------------------------------------------------------------------------*/
            /*---------------------------------------------------------------------------------------------------------------------------*/


                #if defined(LIGHTMAP_ON)
                    SLZFragData fragData = SLZGetFragData(i.vertex, i.wPos, normalWS, i.uv1.xy, i.uv1.zw, i.SHVertLights.xyz);
                #else
                    SLZFragData fragData = SLZGetFragData(i.vertex, i.wPos, normalWS, float2(0, 0), float2(0, 0), i.SHVertLights.xyz);
                #endif

                half4 emission = half4(0,0,0,0);

                SLZSurfData surfData = SLZGetSurfDataMetallicGloss(albedo.rgb, saturate(metallic), saturate(smoothness), 1, float3(0, 0, 0), Alpha);
                half4 color = half4(1, 1, 1, 1);


            // Begin Injection LIGHTING_CALC from Injection_SSR.hlsl ----------------------------------------------------------
            	#if defined(_SSR_ENABLED)
            		half4 noiseRGBA = GetScreenNoiseRGBA(fragData.screenUV);

            		SSRExtraData ssrExtra;
            		ssrExtra.meshNormal = i.normXYZ_tanX.xyz;
            		ssrExtra.lastClipPos = i.lastVertex;
            		ssrExtra.temporalWeight = _SSRTemporalMul;
            		ssrExtra.depthDerivativeSum = 0;
            		ssrExtra.noise = noiseRGBA;
            		ssrExtra.fogFactor = i.uv0XY_bitZ_fog.w;

            		color = SLZPBRFragmentSSR(fragData, surfData, ssrExtra, _Surface);
            		color.rgb = max(0, color.rgb);
            	#else
            		color = SLZPBRFragment(fragData, surfData, _Surface);
            	#endif
            // End Injection LIGHTING_CALC from Injection_SSR.hlsl ----------------------------------------------------------


            // Begin Injection VOLUMETRIC_FOG from Injection_SSR.hlsl ----------------------------------------------------------
            	#if !defined(_SSR_ENABLED)
            		color = MixFogSurf(color, -fragData.viewDir, i.uv0XY_bitZ_fog.w, _Surface);

            		color = VolumetricsSurf(color, fragData.position, _Surface);
            	#endif
            // End Injection VOLUMETRIC_FOG from Injection_SSR.hlsl ----------------------------------------------------------
                return color;
            }
		    ENDHLSL
        }
	}
	FallBack "Hidden/InternalErrorShader"
}
