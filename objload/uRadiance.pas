unit uRadiance;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uShape,uBVH,uObjShape;

type
   ShapeListClass=Class
      shapes:TList;
      constructor create;
      procedure add(s : ShapeClass);
      function intersect(const r: RayRecord):HitInfo;virtual;
      function GetObj(id:integer):ShapeClass;virtual;
   end;
   
   BVHSceneClass = class(ShapeListClass)
      bvh:BVHNodeClass;
      function intersect(const r:RayRecord):HitInfo;override;
      procedure MakeBVHNode;
      procedure LoadObj(FN:string);
   end;

   SceneRecord = record
      scList:TList;//List of SceneListClass
      procedure new;
      function Radiance(const r:RayRecord;depth:integer):Vec3;
   end;

   var
      sc:SceneRecord;

implementation
constructor ShapeListClass.create;
begin
   Shapes:=TList.Create;
end;
procedure ShapeListClass.add(s: ShapeClass);
begin
   Shapes.add(s);
end;

function ShapeListClass.intersect(const r:RayRecord):HitInfo;
var 
  t,d:real;
  i,id:integer;
  Info:InterInfo;
begin
   result.isHit:=false;
   result.t:=INF;
   t:=INF;
   id:=Shapes.count-1;
   for i:=0 to Shapes.count-1 do begin
      Info:=ShapeClass(Shapes[i]).intersect(r);
      d:=Info.t;
      if d < t then begin
         t:=d;
         id:=i;
      end;
   end;
   result.isHit:=(t<inf);
   if result.isHit then begin
      result.t:=t;
      result.id:=id;
   end;
end;

function ShapeListClass.GetObj(id:integer):ShapeClass;
begin
   result:=ShapeClass(shapes[id]);
end;

function BVHSceneClass.intersect(const r:RayRecord):HitInfo;
begin
   result.obj:=nil;
   result:=bvh.intersect(r,shapes);
   if result.isHit then result.obj:=GetObj(result.id);
end;

procedure BVHSceneClass.MakeBVHNode;
var
   ary:array of integer;
   i:integer;
begin
   SetLength(ary,shapes.count);
   writeln('bvh sph.count=',shapes.count);
   for i:=0 to shapes.count-1 do ary[i]:=i;
   bvh:=BVHNodeClass.Create(ary,shapes);
end;

procedure BVHSceneClass.LoadObj(FN: string);
begin
   LoadObjFile(FN,Shapes);
   MakeBVHNode
end;

procedure SceneRecord.new;
begin
   scList:=TList.create;
end;

function SceneRecord.Radiance(const r:RayRecord;depth:integer):Vec3;
var
   f,d,x,n,nl:Vec3;
   p:real;
   hit,hit2:HitInfo;
   tInfo:TraceInfo;
   i:integer;
begin
   depth:=depth+1;
   hit.isHit:=false;hit.t:=INF;
   i:=0;
   while i<sc.scList.count do begin
      hit2:=ShapeListClass(sc.scList[i]).intersect(r);
      if hit2.isHit then begin
         if hit.t>hit2.t then begin
            hit:=hit2;
            hit.obj:=ShapeListClass(sc.scList[i]).GetObj(hit.id);
         end;
      end;
      i:=i+1;
   end;
   if hit.isHit=false then begin
      result:=ZeroVec;exit;
   end;
   x:=r.o+r.d*hit.t;
   n:=hit.obj.GetNorm(x);
   if n.dot(r.d)<0 then nl:=n else nl:=n*-1;
   f := hit.obj.tx.getColor(x);
   p:=Max(f.x,Max(f.y,f.z));
   if (depth>5) then begin
      if random<p then 
         f:=f/p 
      else
         Exit(hit.obj.tx.GetEmit(x));
   end;
   tInfo := hit.obj.m.GetRay(r,x,n,nl);
   result:=hit.obj.tx.GetEmit(x)+f.Mult(Radiance(tInfo.r,depth))*tInfo.cpc;
end;
begin
end.
