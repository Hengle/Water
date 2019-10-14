﻿// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Babybus/Water/Unilt sufacewater"
{
	Properties
	{
		
		_MainTex ("纹理贴图", 2D) = "white" {}
		[Normal]_NormalTex("法线贴图", 2D) = "bump" {}
			
		_WaterColor("水颜色",Color) = (0,.25,.4,1)//水颜色
		_WaveColor("浪颜色",Color) = (0,.25,.4,1)//浪颜色
		_WaveOffset("WaveOffset(xy&zw)",vector)=(.1,.2,-.2,-.1)//波纹流动方向
		
		_NormalScale ("NormalScale", float) = 0.3
		_Speed("Speed", float) = 0.3	

	
	}
	SubShader
	{
		Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
		LOD 100
	
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha 

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};

			struct v2f
			{
				half4 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				half4 uv2 : TEXCOORD2;			
				float4 vertex : SV_POSITION;

			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			sampler2D _NormalTex;
			float4 _NormalTex_ST;
			
			sampler2D _RampTex;
			fixed4 _WaterColor,_WaveColor;

			half4 _WaveOffset;	
			fixed _Speed;
			fixed _NormalScale;

			//script 控制
			uniform float4x4    ot_Proj;
            uniform float4x4    ot_InvView;
            uniform float3      ot_ViewCorner0;
            uniform float3      ot_ViewCorner1;
            uniform float3      ot_ViewCorner2;
            uniform float3      ot_ViewCorner3;
			
			uniform float ot_OceanPosition;
			uniform float4 ot_WaveScales;
			uniform float4 ot_WaveLengths;
			uniform float4 ot_WaveExponents;
			uniform float4 ot_WaveOffsets;
			uniform float4 ot_WaveDirection01;
			uniform float4 ot_WaveDirection23;
			uniform float4 ot_WaveConstants;
			uniform float4 ot_WaveDerivativeConstants;
			
			inline void waveHeight(float3 pos, out float height, out float3 normal)
			{
				float4 locations = float4(dot(ot_WaveDirection01.xy, pos.xz), dot(ot_WaveDirection01.zw, pos.xz), dot(ot_WaveDirection23.xy, pos.xz), dot(ot_WaveDirection23.zw, pos.xz));
				float4 axesX = float4(ot_WaveDirection01.x, ot_WaveDirection01.z, ot_WaveDirection23.x, ot_WaveDirection23.z);
				float4 axesY = float4(ot_WaveDirection01.y, ot_WaveDirection01.w, ot_WaveDirection23.y, ot_WaveDirection23.w);
				
				float4 sine = sin((locations + ot_WaveOffsets) * ot_WaveConstants) * 0.5 + 0.5;
				// sine = 0.0; // To disable waves
				float4 cosine = cos((locations + ot_WaveOffsets) * ot_WaveConstants);

				float sum = dot(ot_WaveScales, pow(sine, ot_WaveExponents));
				float tangentSum = dot(axesX * ot_WaveDerivativeConstants, pow(sine, ot_WaveExponents - 0.99) * cosine);
				float bitangentSum = dot(axesY * ot_WaveDerivativeConstants, pow(sine, ot_WaveExponents - 0.99) * cosine);

				float3 tangent = float3(1.0, tangentSum, 0.0);
				float3 bitangent = float3(0.0, bitangentSum, 1.0);

				height = ot_OceanPosition + sum;
				normal = normalize(cross(bitangent, tangent));
			}
			//结束
			
			v2f vert (appdata v)
			{
				v2f o;
				//控制顶点star
				float4 projCorner0 = mul(ot_Proj, float4(ot_ViewCorner0, 1.0));
                float4 projCorner1 = mul(ot_Proj, float4(ot_ViewCorner1, 1.0));
                float4 projCorner2 = mul(ot_Proj, float4(ot_ViewCorner2, 1.0));
                float4 projCorner3 = mul(ot_Proj, float4(ot_ViewCorner3, 1.0));

                float k0 = 1.0 / projCorner0.w;
                float k1 = 1.0 / projCorner1.w;
                float k2 = 1.0 / projCorner2.w;
                float k3 = 1.0 / projCorner3.w;

                float3 Qk0 = ot_ViewCorner0 * k0;
                float3 Qk1 = ot_ViewCorner1 * k1;
                float3 Qk2 = ot_ViewCorner2 * k2;
                float3 Qk3 = ot_ViewCorner3 * k3;

                float3 left = lerp(Qk0, Qk3, v.vertex.y);
                float3 right = lerp(Qk1, Qk2, v.vertex.y);
                float leftK = lerp(k0, k3, v.vertex.y);
                float rightK = lerp(k1, k2, v.vertex.y);
                float3 viewVertex = lerp(left, right, v.vertex.x) / lerp(leftK, rightK, v.vertex.x);
                float3 worldVertex = mul(ot_InvView, float4(viewVertex, 1.0)).xyz;

                // Use world vertex
                float height;
                float3 worldNormal;
                waveHeight(worldVertex, height, worldNormal);

                worldVertex.y = height;

                float4 projVertex = mul(UNITY_MATRIX_VP, float4(worldVertex, 1.0));

                o.vertex = projVertex;
				//控制顶点end
				
				
				
				//o.vertex = UnityObjectToClipPos(v.vertex);			
				o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.uv, _MainTex)+ _WaveOffset.zw * _Time.x;
				o.uv2.zw = TRANSFORM_TEX(v.uv, _NormalTex);
			
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//采样法线贴图
				fixed4 normalCol = (tex2D(_NormalTex, i.uv2.zw + fixed2(_Time.x*_Speed, 0)) + tex2D(_NormalTex, fixed2(_Time.x*_Speed + i.uv2.w, i.uv2.z))) / 2;			
				half3 worldNormal = UnpackNormal(normalCol);
				worldNormal = lerp(half3(0, 0, 1), worldNormal, _NormalScale);
		
				// sample the texture
				fixed4 col = tex2D(_MainTex, i.uv.xy+worldNormal+ _WaveOffset.xy * _Time.x)*0.01+tex2D(_MainTex, i.uv.zw*0.7+worldNormal)*0.025;
				col.rgb = lerp(_WaterColor.rgb,_WaveColor.rgb*3,col.r);
				col.a = _WaterColor.a;
				// apply fog
				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}