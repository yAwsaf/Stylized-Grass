Shader "Unlit/StylizedGrass"
{
    Properties
    {
        //Color
        _DownColor("DownColor",Color) = (1,1,1,1)
        _UpColor("UpColor",Color) = (1,1,1,1)

        //Tessellation
        _TessellationUniform("Tessellation Uniform", Range(1, 64)) = 1

        //GrassBlade
        _BladeWidth("BladeWidth",Float) = 0.5
        _BladeHeight("BladeHeight",Float) = 1
        _RandomBladeWidth("RandomBladeWidth",Range(0,1)) = 0.2
        _RandomBladeHeight("RandomBladeHeight",Range(0,1)) = 0.2

        //Wind
        _WindTex("WindTex", 2D) = "bumb" {}
        _WindStrength("WindStrength",Float) = 1

         //Light
        _RimPower("Rim power", float) = 1
        [HDR]_TranslucentColor("Translucent color", Color) = (1,1,1,1)
        //Grass trample
        _GrassTrample("Grass trample (XYZ -> Position, W -> Radius)", Vector) = (0,0,0,0)
        _GrassTrampleOffsetAmount("Grass trample offset amount", Range(0, 1)) = 0.2
    }
    SubShader
    {
        CGINCLUDE
        #include "UnityCG.cginc"
        #include "Shaders/CustomTessellation.cginc"
        #include "Autolight.cginc"
    struct geometryOutput
    {
        float4 pos : SV_POSITION;	
        float3 normal : NORMAL;
        float2 uv : TEXCOORD0;
        float4 color : TEXCOORD1;
        float3 viewDir : TEXCOORD2;
        unityShadowCoord4 _ShadowCoord : TEXCOORD3;

    };

        sampler2D _MainTex, _WindTex;
        float4 _MainTex_ST, _WindTex_ST;

        float4 _DownColor, _UpColor;

        float _BladeWidth, _BladeHeight;

        float _RandomBladeHeight;
        float _RandomBladeWidth;

        float _WindStrength;

        float _RimPower;
        float4 _TranslucentColor;

        float4 _GrassTrample;
        float _GrassTrampleOffsetAmount;

        float random(float2 st)
        {
            return frac(sin(dot(st.xy,
                float2(12.9898, 78.233))) *
                43758.5453123);
        }

        //RotationFunctions
        float3 rotationx(float3 vertex, float angle)
        {
            float3x3 rotationMatrix = float3x3
                (
                    1.0f, 0.0f, 0.0f,
                    0.0f, cos(angle), -sin(angle),
                    0.0f, sin(angle), cos(angle)
                    );
            return mul(rotationMatrix, vertex);
        }
        float3 rotationy(float3 vertex, float angle)
        {
            float3x3 rotationMatrix = float3x3
                (
                    cos(angle), 0.0f , sin(angle),
                    0.0f, 1.0f, 0.0f,
                    -sin(angle), 0.0f, cos(angle)
                    );
            return mul(rotationMatrix, vertex);
        }
        float3 rotationz(float3 vertex,float angle)
        {
            float3x3 rotationMatrix = float3x3
            (
                cos(angle),-sin(angle) , 0.0f ,
                sin(angle), cos(angle) , 0.0f ,
                    0.0f,       0.0f,     1.0f
            );
            return mul(rotationMatrix, vertex);
        }

        geometryOutput GetVertex(float4 pos, float2 uv , float4 color,float3 normal)
        {
            geometryOutput o;

            o.pos = UnityObjectToClipPos(pos);
            o.uv = uv;
            o.color = color;
            o.viewDir = WorldSpaceViewDir(pos);
            o._ShadowCoord = ComputeScreenPos(o.pos);
            o.normal = UnityObjectToWorldNormal(normal);
            #if UNITY_PASS_SHADOWCASTER
            o.pos = UnityApplyLinearShadowBias(o.pos);
            #endif
            return o;
        }

        [maxvertexcount(3)]
        void geom(triangle vertexOutput IN[3],inout TriangleStream<geometryOutput> triStream)
        {
            float4 vertex = IN[0].vertex;

            float3 normal = IN[0].normal;
            float4 tangent = IN[0].tangent;
            float3 binormal = cross(normal, tangent) * tangent.w;

            float3x3 tangentToLocal = float3x3(
                tangent.x, binormal.x, normal.x,
                tangent.y, binormal.y, normal.y,
                tangent.z, binormal.z, normal.z
                );
            float3 worldPos = mul(unity_ObjectToWorld, vertex).xyz;

            float width = (random(worldPos.xz) * 2 - 1) * _RandomBladeWidth + _BladeWidth;
            float height = (random(worldPos.zx) * 2 - 1) * _RandomBladeHeight + _BladeHeight;

            float yRotationRand = random(worldPos.xz) * UNITY_PI * 2;
            float xRotationRand = random(worldPos.zx) * UNITY_PI * 0.2f;

            //Wind
            float2 uv = worldPos.xz * _WindTex_ST.xy + _WindTex_ST.zw * _Time.y;
            float4 wind = tex2Dlod(_WindTex, float4(uv, 0, 0)) * _WindStrength;

            //Trample
            _GrassTrample, _GrassTrampleOffsetAmount;
            float trample = (1 - saturate(distance(_GrassTrample.xyz, worldPos) / _GrassTrample.w)) * _GrassTrampleOffsetAmount;

            float4 pointA = vertex + float4(rotationy(mul(tangentToLocal, float3(-width, 0, 0)), yRotationRand), 1.0f);
            float4 pointB = vertex + float4(rotationy(mul(tangentToLocal, float3(width, 0, 0)), yRotationRand), 1.0f);
            float4 pointC = vertex + float4(rotationy(rotationx(mul(tangentToLocal, float3(0, 0, height)), xRotationRand + trample), yRotationRand), 1.0f) + wind;

            float3 bladeNormal = normalize(cross(pointB.xyz - pointA.xyz, pointC.xyz - pointA.xyz));

            triStream.Append(GetVertex(pointA, float2(0, 0), float4(0, 0, 0, 0), bladeNormal));
            triStream.Append(GetVertex(pointB, float2(1, 0), float4(0, 0, 0, 0), bladeNormal));
            triStream.Append(GetVertex(pointC, float2(0.5, 1), float4(1, 0, 0, 0), bladeNormal));

            triStream.RestartStrip();
        }

        ENDCG
        
        Pass
        {
            Tags { "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
            LOD 100
            cull OFF
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag
            #pragma hull hull
            #pragma domain domain
            #pragma target 4.6
            #pragma multi_compile_fwdbase

            #include "Lighting.cginc"

            fixed4 frag(geometryOutput i) : SV_Target
            {
                //fixed4 col = tex2D(_MainTex, i.uv);
                float4 color = lerp(_DownColor, _UpColor, i.color.x);
                float light = saturate(dot(normalize(_WorldSpaceLightPos0), i.normal)) * 0.5 + 0.5;
                fixed4 translucency = _TranslucentColor * saturate(dot(normalize(-_WorldSpaceLightPos0), normalize(i.viewDir)));
                float shadow = SHADOW_ATTENUATION(i);
                half rim = pow(1.0 - saturate(dot(normalize(i.viewDir), i.normal)), _RimPower);
                color *= (light + translucency * rim * i.color.x) * _LightColor0 * shadow + float4(ShadeSH9(float4(i.normal, 1)), 1.0);
                return color;
            }

            ENDCG
        }
        Pass
        {
            Tags {
                "LightMode" = "ShadowCaster"
            }
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment fragShadow
            #pragma hull hull
            #pragma domain domain

            #pragma target 4.6
            #pragma multi_compile_shadowcaster

            float4 fragShadow(geometryOutput i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }

            ENDCG
        }
    }
   
}
