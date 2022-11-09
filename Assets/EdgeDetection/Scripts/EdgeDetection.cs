using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EdgeDetection : MonoBehaviour
{
    #region enum

    #endregion

    #region const
    const float SIGMA_RATIO = 1.6f;
    #endregion

    #region public property
    public Material material;

    #endregion

    #region private property

    [SerializeField] Color lineColor = new Color(0, 0, 0, 1);
    [SerializeField] Color backgroundColor = new Color(1, 1, 1, 1);
    [SerializeField, Range(1, 10)] int iteration = 10;
    [SerializeField, Range(0.01f, 10)] float lineWidth = 1.0f; //sigma_c
    [SerializeField, Range(0.3f, 10)] float smoothness = 3.0f; //sigma_m
    [SerializeField, Range(0, 500)] float contrast = 350f; //phi
    [SerializeField, Range(0.95f, 1)] float datail = 0.99f; //rho
    [SerializeField] bool overrideLine = false;
    float[] gArr_c = new float[100];
    float[] gArr_s = new float[100];
    float[] gArr_m = new float[100];

    #endregion

    #region public method
    public float Gauss(int x, float sigma)
    {
        return Mathf.Exp((-x * x) / (2 * sigma * sigma)) / Mathf.Sqrt(Mathf.PI * 2 * sigma * sigma);
    }

    #endregion

    #region private method
    //https://www.wolframalpha.com/input/?i=exp%28-1*x*x%2F%282*%CF%83*%CF%83%29%29%2F%28sqrt%28PI*2%29*%CF%83%29+%3D+0.001&lang=ja
    private int CalcKernel(float sigma)
    {
        return Mathf.FloorToInt(1.41421f * sigma * Mathf.Sqrt(Mathf.Abs(Mathf.Log(0.00250663f * sigma))));
    }

    #endregion

    #region event

    void Start()
    {

    }

    void Update()
    {

    }

    private void OnRenderImage(RenderTexture src, RenderTexture dst)
    {
        System.Diagnostics.Stopwatch sw = new System.Diagnostics.Stopwatch();
        sw.Start();

        var flowField = RenderTexture.GetTemporary(src.width, src.height, 0);
        var tmp1 = RenderTexture.GetTemporary(src.width, src.height, 0);
        var tmp2 = RenderTexture.GetTemporary(src.width, src.height, 0);
        var tmp3 = RenderTexture.GetTemporary(src.width, src.height, 0);
        var gray = RenderTexture.GetTemporary(src.width, src.height, 0);
        var gradientMag = RenderTexture.GetTemporary(src.width, src.height, 0);

        material.SetFloat("_phi", contrast);
        material.SetFloat("_rho", datail);
        material.SetColor("_line", lineColor);
        material.SetColor("_back", backgroundColor);
        material.SetInt("_override", Convert.ToInt32(overrideLine));
        material.SetTexture("_original", src);

        Graphics.Blit(src, gray, material, 0);// グレースケール化
        Graphics.Blit(gray, tmp1, material, 1);// 輝度勾配を計算
        Graphics.Blit(tmp1, gradientMag, material, 2);// 輝度勾配の大きさを計算
        Graphics.Blit(tmp1, flowField, material, 3);// 輝度勾配を正規化

        material.SetTexture("_gradientMag", gradientMag);
        material.SetTexture("_grayscale", gray);

        // フローフィールドを更新
        for (int i = 0; i < iteration; i++)
        {
            Graphics.Blit(flowField, tmp1, material, 4);
            Graphics.Blit(tmp1, flowField);
        }
        Graphics.Blit(flowField, dst);

        var sigma_c = lineWidth;
        var sigma_s = SIGMA_RATIO * sigma_c;

        int kernelT = CalcKernel(sigma_s);

        // ガウス分布の値をシェーダー側で毎度計算すると重いので事前計算した配列を渡す
        for (int x = 0; x <= kernelT; x++)
        {
            gArr_c[x] = Gauss(x, sigma_c);
            gArr_s[x] = Gauss(x, sigma_s);
        }
        material.SetFloatArray("_gArr_c", gArr_c);
        material.SetFloatArray("_gArr_s", gArr_s);
        material.SetInt("_kernelT", kernelT);

        // 法線方向にガウシアン差分を計算
        Graphics.Blit(flowField, tmp1, material, 5);
        material.SetTexture("_doG", tmp1);

        var sigma_m = smoothness;
        int kernelS = CalcKernel(sigma_m);

        for (int x = 0; x < kernelS; x++)
        {
            gArr_m[x] = Gauss(x, sigma_m);
        }
        // gArr_m.ForEach(x => Debug.Log(x));
        material.SetFloatArray("_gArr_m", gArr_m);
        material.SetInt("_kernelS", kernelS);

        // 接線方向にピクセル値を積分
        Graphics.Blit(flowField, tmp2, material, 6);

        // ちょっとぼかして馴染ませる(x,y方向のブラーは分けたほうが高速)
        material.SetVector("_direction", new Vector4(1, 0, 0, 0));
        Graphics.Blit(tmp2, tmp3, material, 7);
        material.SetVector("_direction", new Vector4(0, 1, 0, 0));
        Graphics.Blit(tmp3, tmp2, material, 7);

        // 着色する
        Graphics.Blit(tmp2, dst, material, 8);

        RenderTexture.ReleaseTemporary(flowField);
        RenderTexture.ReleaseTemporary(tmp1);
        RenderTexture.ReleaseTemporary(tmp2);
        RenderTexture.ReleaseTemporary(tmp3);
        RenderTexture.ReleaseTemporary(gray);
        RenderTexture.ReleaseTemporary(gradientMag);

        sw.Stop();
        Debug.Log(sw.ElapsedMilliseconds + "ms");
    }

    #endregion
}