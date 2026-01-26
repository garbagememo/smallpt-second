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
   e:=e_;c:=c_;
   tx:=TextureClass.Create(e_,c_);
   if refl_=DIFF then m:=DiffuseClass.Create;
   if refl_=SPEC then m:=MirrorClass.Create;
   if refl_=REFR then m:=RefractClass.Create;
end;

function PolygonClass.intersect(const r:RayRecord):InterInfo;
var
   edge1, edge2, h, s, q: vec3;
   a, f, t,u, v: real;
begin
   result.t := INF;
   result.FaceID:=-1;
   edge1 := V1 - V0;
   edge2 := V2 - V0;
   
   h := r.d.cross(edge2);
   a := edge1*h;

   // aが0に近い場合、光線はポリゴンと平行
   if (a > -EPS) and (a < EPS) then Exit;

   f := 1.0 / a;
   s := r.o - V0;
   u := f * (s*h);

   // 重心座標uが範囲外なら交差しない
   if (u < 0.0) or (u > 1.0) then Exit;

   q := s.Cross(edge1);
   v := f * (r.d*q);

   // 重心座標vおよびu+vのチェック
   if (v < 0.0) or (u + v > 1.0) then Exit;

   // レイのパラメータtを計算
   t := f * (edge2*q);

   if t > EPS then
      result.t:=t; // 交点あり
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
