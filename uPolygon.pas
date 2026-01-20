unit uPolygon;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uTexture,uShape;

type 
  PolygonClass=class(ShapeClass)
     V0,V1,V2:Vec3;
     constructor create(v0_,v1_,v2_,e_,c_:Vec3;refl_:reftype);virtual;
     function intersect(const r:RayRecord):InterInfo;override;
     function GetNorm(x:Vec3;FaceID:integer):Vec3;override;
   end;

implementation
  
constructor PolygonClass.create(v0_,v1_,v2_,e_,c_:Vec3;refl_:reftype);
begin
   v0:=v0_;v1:=v1_;v2:=v2_;
   e:=e_;c:=e_;
   tx:=TextureClass.Create(e_,c_);
   if refl_=DIFF then m:=DiffuseClass.Create;
   if refl_=SPEC then m:=MirrorClass.Create;
   if refl_=REFR then m:=RefractClass.Create;
end;

function PolygonClass.intersect(const r:RayRecord):InterInfo;
var
   edge1, edge2, h, s, q: vec3;
   a, f, u, v: real;
begin
   result.FaceID:=-1;
   result.t := INF;

   // 1. 三角形の2つの辺を計算
   edge1 := V1-V0;
   edge2 := V2-V0;

   // 2. 行列式(a)を計算し、レイが三角形と平行かどうかを判定
   h := r.d / edge2;
   a := edge1 * h;

   // レイが三角形と平行 (aが0に近い)
   if abs(a)<EPS then Exit;

   f := 1.0 / a;
   s := R.d-V0;
   u := f * (s*h);

   // 3. バリセントリック座標(u)が範囲外
   if (u < 0.0) or (u > 1.0) then Exit;

   q := s.Mult(edge1);
   v := f * (R.d * q);

   // 4. バリセントリック座標(v)が範囲外、またはu+vが1を超える
   if (v < 0.0) or (u + v > 1.0) then Exit;

   // 5. 交差距離(t)を計算
   result.t := f * (edge2 * q);

   // レイの方向に対して交点が前にあるか
   if result.t<EPS then result.t:=INF;
end;

function PolygonClass.GetNorm(x:Vec3;FaceID:integer):Vec3;
var
   edge1, edge2, normal: Vec3;
begin
   edge1 := v1-v0;
   edge2 := v2-v0;
   normal := edge1 / edge2;
   Result := normal.Norm;
end;

end.
