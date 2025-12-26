unit uShape;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial;

const 
  eps=1e-4;
  INF=1e20;
type
   ShapeClass=class;
   
   SurfaceInfo=record
      isHit:boolean;
      t:real;
      x,n,nl:Vec3;
      obj:ShapeClass;
   end;
      
   AABBRecord=record
      Min,Max:Vec3;
      function hit(r:RayRecord;tmin,tmax:real):boolean;
      function new(m0,m1:Vec3):AABBRecord;
      function MargeBoundBox(box1:AABBRecord):AABBRecord;
   end;

   ShapeClass=class
      p,c,e:Vec3;// position emit color
      m:MaterialClass;
      function intersect(const r:RayRecord):real;virtual;abstract;
      function GetNorm(x:Vec3):Vec3;virtual;abstract;
   end;
   
   SphereClass=class(ShapeClass)
      rad:real;       //radius
      refl:RefType;
      BoundBox:AABBRecord;
      constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);
      function intersect(const r:RayRecord):real;override;
      function GetNorm(x:Vec3):Vec3;override;
   end;

function intersect(const r:RayRecord):SurfaceInfo;
function radiance(const r:RayRecord;depth:integer):Vec3;

var
   sph:TList;



implementation
function AABBRecord.MargeBoundBox(box1:AABBRecord):AABBRecord;
var
   small,big:Vec3;
begin
  small.new(math.min(self.min.x, box1.min.x),
            math.min(self.min.y, box1.min.y),
            math.min(self.min.z, box1.min.z));

  big.new(math.max(self.max.x, box1.max.x),
          math.max(self.max.y, box1.max.y),
          math.max(self.max.z, box1.max.z) );

  result.new(small,big);
end;


function AABBRecord.new(m0,m1:Vec3):AABBRecord;
begin
   min:=m0;max:=m1;
   result:=self;
end;

function AABBRecord.hit(r:RayRecord;tmin,tmax:real):boolean;
var
  invD,t0,t1,tswap:real;
begin
   //tminがマイナスの場合を除外するため、tmin=EPS,tmax=INFとしている。引数意味なくない？
   invD := 1.0 / r.d.x;
   t0 := (Min.x - r.o.x) * invD;
    t1 := (max.x - r.o.x) * invD;
    if (invD < 0.0) then begin tswap:=t1;t1:=t0;t0:=tswap end;

    if t0>tmin then tmin:=t0;
    if t1<tmax then tmax:=t1;
    if (tmax <= tmin) then exit(false);

    invD := 1.0 / r.d.y;
    t0 := (Min.y - r.o.y) * invD;
    t1 := (max.y - r.o.y) * invD;
    if (invD < 0.0) then begin tswap:=t1;t1:=t0;t0:=tswap end;

    if t0>tmin then tmin:=t0;
    if t1<tmax then tmax:=t1;
    if (tmax <= tmin) then exit(false);

    invD := 1.0 / r.d.z;
    t0 := (Min.z - r.o.z) * invD;
    t1 := (max.z - r.o.z) * invD;
    if (invD < 0.0) then begin tswap:=t1;t1:=t0;t0:=tswap end;

    if t0>tmin then tmin:=t0;
    if t1<tmax then tmax:=t1;
    if (tmax <= tmin) then exit(false);

    result:=true;
end;



constructor SphereClass.Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);
var
   b:Vec3;
begin
   rad:=rad_;p:=p_;e:=e_;c:=c_;refl:=refl_;
   BoundBox.new(p - b.new(rad, rad, rad),
                p + b.new(rad, rad, rad));
   if refl=DIFF then m:=DiffuseClass.Create;
   if refl=SPEC then m:=MirrorClass.Create;
   if refl=REFR then m:=RefractClass.Create;
end;
function SphereClass.intersect(const r:RayRecord):real;
var
  op:Vec3;
  t,b,det:real;
begin
  op:=p-r.o;
  t:=eps;b:=op*r.d;det:=b*b-op*op+rad*rad;
  if det<0 then 
    result:=INF
  else begin
    det:=sqrt(det);
    t:=b-det;
    if t>eps then 
      result:=t
    else begin
      t:=b+det;
      if t>eps then 
        result:=t
      else
        result:=INF;
    end;
  end;
end;

function SphereClass.GetNorm(x:Vec3):Vec3;
begin
  result:=(x-p).norm;
end;

function intersect(const r:RayRecord):SurfaceInfo;
var 
  x,n,nl:Vec3;
  t,d:real;
  i,id:integer;

begin
  result.isHit:=false;
  result.t:=INF;
  t:=INF;
  id:=sph.count-1;
  for i:=0 to sph.count-1 do begin
    d:=ShapeClass(sph[i]).intersect(r);
    if d<t then begin
      t:=d;
      id:=i;
    end;
  end;
  result.isHit:=(t<inf);
  if result.isHit then begin
     result.t:=t;
     result.x:=r.o+r.d*t;
     result.obj:=ShapeClass(sph[id]);
     result.n:=result.obj.GetNorm(result.x);
     if result.n.dot(r.d)<0 then result.nl:=result.n else result.nl:=result.n*-1;
  end;
end;

function radiance(const r:RayRecord;depth:integer):Vec3;
var
  f,d:Vec3;
  p:real;
  sInfo:SurfaceInfo;
  tInfo:TraceInfo;
begin
  depth:=depth+1;
  sInfo:=intersect(r);
  if sInfo.isHit=false then begin
    result:=ZeroVec;exit;
  end;
  f:=sInfo.obj.c;
  p:=Max(f.x,Max(f.y,f.z));
  if (depth>5) then begin
    if random<p then 
      f:=f/p 
    else
      Exit(sInfo.obj.e);
  end;
  tInfo:=sInfo.obj.m.GetRay(r,sInfo.x,sInfo.n,sInfo.nl);
  result:=sInfo.obj.e+f.Mult(radiance(tInfo.r,depth))*tInfo.cpc;
end;

begin
end.
