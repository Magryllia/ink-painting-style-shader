#ifndef ___Func
  #define ___Func
  
  
  // 画像の輝度を返す
  half Grayscale(half3 col)
  {
    return dot(col.rgb, fixed3(0.299, 0.587, 0.114));
  }
  
  //-1~1 → 0~1
  half3 Encode3(half3 val)
  {
    return half3(val.xy * 0.5 + 0.5, 0);
  }
  half3 Encode(half val)
  {
    return val * 0.5 + 0.5;
  }
  
  //0~1 → -1~1
  half3 Decode3(half3 val)
  {
    return half3((val.xy - 0.5) / 0.5, 0);
  }
  half Decode(half val)
  {
    return(val - 0.5) / 0.5;
  }
  
  //輝度勾配を計算する
  half3 Gradient(float2 dx, sampler2D tex, float2 uv)
  {
    //|-------------------|
    //|c11|c12|c13|c14|c15|
    //|c21|c22|c23|c24|c25|
    //|c31|c32|c33|c34|c35|
    //|c41|c42|c43|c44|c45|
    //|c51|c52|c53|c54|c55|
    //|-------------------|
    
    half c11 = tex2D(tex, uv + float2(-dx.x * 2, dx.y * 2)).x;
    half c12 = tex2D(tex, uv + float2(-dx.x, dx.y * 2)).x;
    half c13 = tex2D(tex, uv + float2(0, dx.y * 2)).x;
    half c14 = tex2D(tex, uv + float2(dx.x, dx.y * 2)).x;
    half c15 = tex2D(tex, uv + dx * 2).x;
    half c21 = tex2D(tex, uv + float2(-dx.x * 2, dx.y)).x;
    half c22 = tex2D(tex, uv + float2(-dx.x, dx.y)).x;
    half c23 = tex2D(tex, uv + float2(0, dx.y)).x;
    half c24 = tex2D(tex, uv + dx).x;
    half c25 = tex2D(tex, uv + float2(dx.x * 2, dx.y)).x;
    half c31 = tex2D(tex, uv + float2(-dx.x * 2, 0)).x;
    half c32 = tex2D(tex, uv + float2(-dx.x, 0)).x;
    half c33 = tex2D(tex, uv).x;
    half c34 = tex2D(tex, uv + float2(dx.x, 0)).x;
    half c35 = tex2D(tex, uv + float2(dx.x * 2, 0)).x;
    half c41 = tex2D(tex, uv + float2(-dx.x * 2, -dx.y)).x;
    half c42 = tex2D(tex, uv - dx).x;
    half c43 = tex2D(tex, uv + float2(0, -dx.y)).x;
    half c44 = tex2D(tex, uv + float2(dx.x, -dx.y)).x;
    half c45 = tex2D(tex, uv + float2(dx.x * 2, -dx.y)).x;
    half c51 = tex2D(tex, uv - dx * 2).x;
    half c52 = tex2D(tex, uv + float2(-dx.x, -dx.y * 2)).x;
    half c53 = tex2D(tex, uv + float2(0, -dx.y * 2)).x;
    half c54 = tex2D(tex, uv + float2(dx.x, -dx.y * 2)).x;
    half c55 = tex2D(tex, uv + float2(dx.x * 2, -dx.y * 2)).x;
    
    //sobel filter KERNEL_ETF:
    //https://stackoverflow.com/questions/9567882/sobel-filter-KERNEL_ETF-of-large-size/41065243#41065243
    half gradientX = (-5 * c11 - 4 * c12 + 4 * c14 + 5 * c15
    - 8 * c21 - 10 * c22 + 10 * c24 + 8 * c25
    - 10 * c31 - 20 * c32 + 20 * c34 + 10 * c35
    - 8 * c41 - 10 * c42 + 10 * c44 + 8 * c45
    - 5 * c51 - 4 * c52 + 4 * c54 + 5 * c55) / 240;
    
    half gradientY = (-5 * c11 - 8 * c12 - 10 * c13 - 8 * c14 - 5 * c15
    - 4 * c21 - 10 * c22 - 20 * c23 - 10 * c24 - 4 * c25
    + 4 * c41 + 10 * c42 + 20 * c43 + 10 * c44 + 4 * c45
    + 5 * c51 + 8 * c52 + 10 * c53 + 8 * c54 + 5 * c55) / 240;
    
    return half3(gradientX, gradientY, 0);
  }
  
  //90度回転させる
  half3 Rotate(half3 flowField)
  {
    half3 v = flowField;
    flowField.x = -v.y;
    flowField.y = v.x;
    return flowField;
  }
  
  //勾配の大きさを計算する
  half Magnitude(sampler2D flowField, float2 uv)
  {
    half4 gradient = half4(Decode3(tex2D(flowField, uv).xyz), 0);
    return length(gradient) / sqrt(2);
  }
  
  half CalcPhi(half3 t_cur_x, half3 t_cur_y)
  {
    half alpha = step(0, dot(t_cur_x, t_cur_y));
    return lerp(-1, 1, alpha);
  }
  
  half CalcWs(int i, int j, int KERNEL_ETF)
  {
    // 座標が半径以内であれば1
    half alpha = step(KERNEL_ETF, length(int2(i, j)));
    return lerp(1, 0, alpha);
  }
  
  half CalcWm(half gradMag_x, half gradMag_y)
  {
    return(1 + tanh(gradMag_x - gradMag_y)) / 2;
  }
  
  half CalcWd(half3 t_cur_x, half3 t_cur_y)
  {
    return abs(dot(t_cur_x, t_cur_y));
  }
  // フローフィールドを更新
  half3 RefineETF(sampler2D flowField, sampler2D gradientMag, float2 uv, float2 dx)
  {
    // フローフィールドの注目しているピクセルの値
    half3 t_cur_x = Decode3(tex2D(flowField, uv).xyz);
    half3 t_new = 0;
    half gradMag_x = tex2D(gradientMag, uv);
    const int KERNEL_ETF = 5;// ボックスフィルタのサイズ(+-5px)
    
    [unroll]
    for (int i = -KERNEL_ETF; i <= KERNEL_ETF; i ++)
    {
      [unroll]
      for (int j = -KERNEL_ETF; j <= KERNEL_ETF; j ++)
      {
        // 中心からボックスフィルタの範囲内でオフセットした位置のuv
        float2 uv_y = uv + float2(dx.x * i, dx.y * j);
        // ボックスフィルタ内でオフセットしたフローフィールドのサンプル値
        half3 t_cur_y = Decode3(tex2D(flowField, uv_y).xyz);
        half phi = CalcPhi(t_cur_x, t_cur_y);
        half w_s = CalcWs(i, j, KERNEL_ETF);
        half gradMag_y = tex2D(gradientMag, uv_y);
        half w_m = CalcWm(gradMag_x, gradMag_y);
        half w_d = CalcWd(t_cur_x, t_cur_y);
        t_new += phi * t_cur_y * w_s * w_m * w_d;
      }
    }
    return Encode3(normalize(t_new));
  }
  // 法線方向のガウシアン差分を計算
  half NormalDoG(sampler2D flowField, sampler2D gray, float2 uv, float2 dx, half gArr_c[100], half gArr_s[100], int kernelT, half rho)
  {
    half sum_c = 0;
    half sum_s = 0;
    half weightSum_c = 0;
    half weightSum_s = 0;
    
    half2 gradient = Rotate(Decode3(tex2D(flowField, uv).xyz)).xy;
    
    [unroll(100)]
    for (int t = -kernelT; t <= kernelT; t ++)
    {
      half x = gradient.x * t * dx.x;
      half y = gradient.y * t * dx.y;
      
      half value = tex2D(gray, float2(uv.x + x, uv.y + y));
      
      half weight_c = gArr_c[abs(t)];
      half weight_s = gArr_s[abs(t)];
      
      sum_c += value * weight_c;
      sum_s += value * weight_s;
      weightSum_c += weight_c;
      weightSum_s += weight_s;
    }
    
    half val = sum_c - rho * sum_s;
    return Encode(val);
  }
  
  void Integral(sampler2D doG, sampler2D flowField, inout float2 pos, float2 dx, int s, int sgn, half gArr_m[100], inout half sum)
  {
    half2 direction = sgn * Decode3(tex2D(flowField, pos)).xy;
    
    half value = Decode(tex2D(doG, pos).x);
    half weight = gArr_m[s];
    
    sum += value * weight;
    pos += direction * dx;
  }
  
  half TangentGaussian(sampler2D doG, sampler2D flowField, float2 uv, float2 dx, half gArr_m[100], int kernelS, half phi)
  {
    half sum = 0;
    
    float2 pos = uv.xy;
    [unroll(50)]
    for (int s = 0; s <= kernelS; s ++)
    {
      Integral(doG, flowField, pos, dx, s, 1, gArr_m, sum);
    }
    
    pos = uv.xy;
    [unroll(50)]
    for (int s = 0; s <= kernelS; s ++)
    {
      Integral(doG, flowField, pos, dx, s, -1, gArr_m, sum);
    }
    return 1 + tanh(phi * sum);
  }
  
  half GaussianBlur(sampler2D tex, float2 uv, float2 dx, fixed2 direction, half gArr_b[2])
  {
    half sum = 0;
    half weightSum = 0;
    
    [unroll]
    for (int i = -1; i <= 1; i ++)
    {
      sum += tex2D(tex, uv + i * direction * dx).x * gArr_b[abs(i)];
      weightSum += gArr_b[abs(i)];
    }
    return sum;
  }
  
  
  
#endif // ___Func