package org.joml;
public class Matrix4f implements Matrix4fc {
    public Matrix4f() {}
    public Matrix4f(Matrix4fc other) {}
    public Matrix4f(float m00,float m01,float m02,float m03,
                    float m10,float m11,float m12,float m13,
                    float m20,float m21,float m22,float m23,
                    float m30,float m31,float m32,float m33) {}
    public Matrix4f mul(Matrix4fc right) { return this; }
    public float determinant() { return 1.0f; }
    public Matrix4f invert() { return this; }
    public float m00(){return 0;} public float m01(){return 0;} public float m02(){return 0;} public float m03(){return 0;}
    public float m10(){return 0;} public float m11(){return 0;} public float m12(){return 0;} public float m13(){return 0;}
    public float m20(){return 0;} public float m21(){return 0;} public float m22(){return 0;} public float m23(){return 0;}
    public float m30(){return 0;} public float m31(){return 0;} public float m32(){return 0;} public float m33(){return 0;}
}
