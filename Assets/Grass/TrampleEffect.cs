using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class TrampleEffect : MonoBehaviour
{
    public Material material;
    public float radius;

    void Update()
    {
        material?.SetVector("_GrassTrample", new Vector4(transform.position.x, transform.position.y , transform.position.z, radius));
    }
}
