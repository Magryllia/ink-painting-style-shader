Shader "PostEffect/EdgeDetection"
{
  Properties
  {
    [HideInInspector]_MainTex ("Texture", 2D) = "white" { }
  }
  SubShader
  {
    // No culling or depth
    Cull Off ZWrite Off ZTest Always

    CGINCLUDE
    #include "Func.cginc"
    sampler2D _MainTex;
    sampler2D _original;
    sampler2D _gradientMag;
    sampler2D _grayscale;
    sampler2D _doG;
    half _threthold;
    half _phi;
    half _rho;
    half _gArr_c[100];
    half _gArr_s[100];
    half _gArr_m[100];
    half gArr_b[2];
    int _kernelT = 3;
    int _kernelS = 5;
    fixed4 _direction;
    float4 _MainTex_TexelSize;
    int _override;
    fixed4 _line;
    fixed4 _back;

    struct appdata
    {
      float4 vert: POSITION;
      float2 uv: TEXCOORD0;
    };

    struct v2f
    {
      float4 vert: POSITION;
      float2 uv: TEXCOORD0;
    };

    v2f vert(appdata IN)
    {
      v2f o;
      o.vert = UnityObjectToClipPos(IN.vert);
      o.uv = IN.uv;
      return o;
    }

    #pragma vertex vert
    #pragma fragment frag
    
    ENDCG
    
    //0 画像をグレースケール化
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        half3 col = tex2D(_MainTex, IN.uv);
        half gray = Grayscale(col);
        return half4(gray, gray, gray, 0);
      }
      ENDCG
      
    }

    //1 輝度勾配を計算
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        float2 dx = _MainTex_TexelSize.xy;
        half3 gradient = Gradient(dx, _MainTex, IN.uv);
        return half4(Encode3(Rotate(gradient)), 0);
      }
      ENDCG
      
    }

    //2 輝度勾配の大きさを計算
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        half3 mag = Decode3(tex2D(_MainTex, IN.uv).xyz);
        mag = length(mag);
        return half4(mag, 0);
      }
      ENDCG
      
    }

    //3 輝度勾配を正規化
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        return half4(Encode3(normalize(Decode3(tex2D(_MainTex, IN.uv).xyz))), 0);
      }
      ENDCG
      
    }

    //4 フローフィールドを更新
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        half2 dx = _MainTex_TexelSize.xy;
        return half4(RefineETF(_MainTex, _gradientMag, IN.uv, dx), 0);
      }
      ENDCG
      
    }

    //5
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        float2 dx = _MainTex_TexelSize.xy;
        half3 val = NormalDoG(_MainTex, _grayscale, IN.uv, dx, _gArr_c, _gArr_s, _kernelT, _rho);
        return half4(val, 0);
      }
      ENDCG
      
    }

    //6 接線方向にピクセル値を積分
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        float2 dx = _MainTex_TexelSize.xy;
        half3 val = TangentGaussian(_doG, _MainTex, IN.uv, dx, _gArr_m, _kernelS, _phi);
        return half4(val, 0);
      }
      ENDCG
      
    }

    //7 ちょっとぼかす
    Pass
    {
      CGPROGRAM
      
      half4 frag(v2f IN): COLOR
      {
        float2 dx = _MainTex_TexelSize.xy;
        gArr_b[0] = 0.5;
        gArr_b[1] = 0.25;
        half3 val = GaussianBlur(_MainTex, IN.uv, dx, _direction.xy, gArr_b);
        return half4(val, 0);
      }
      ENDCG
      
    }
    
    //8 着色する
    Pass
    {
      CGPROGRAM
      
      float4 frag(v2f IN): COLOR
      {
        half val = tex2D(_MainTex, IN.uv);
        half4 col = lerp(_line, _back, val);
        float4 colOverride = lerp(_line, tex2D(_original, IN.uv), step(_threthold, val));
        return lerp(col, colOverride, _override);
      }
      ENDCG
      
    }
  }
}
