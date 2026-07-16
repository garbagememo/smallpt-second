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
   
   HitInfo=record
      isHit:boolean;
      t:real;
      id:integer;//本来オブジェクトにしたいが・・・
      obj:ShapeClass;
   end;

   InterInfo=record
      t:real;
      id:integer;
   end;
         
   AABBRecord=record
      Min,Max:Vec3;
      function hit(r:RayRecord;tmin,tmax:real):boolean;
      function new(m0,m1:Vec3):AABBRecord;
      function MargeBoundBox(box1:AABBRecord):AABBRecord;
   end;

   ShapeClass=class
      p,c,e:Vec3;// position emit color
      tx:TextureClass;
      m:MaterialClass;
      BoundBox:AABBRecord;
      constructor Create(p_,e_,c_:Vec3;refl_:RefType);virtual;
      function intersect(const r:RayRecord):InterInfo;virtual;abstract;
      function GetNorm(x:Vec3):Vec3;virtual;abstract;
   end;
   
   SphereClass=class(ShapeClass)
      rad:real;       //radius
      constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);virtual;
      function intersect(const r:RayRecord):InterInfo;override;
      function GetNorm(x:Vec3):Vec3;override;
   end;


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

constructor ShapeClass.Create(p_,e_,c_:Vec3;refl_:RefType);
begin
   p:=p_;e:=e_;c:=c_;
   tx:=TextureClass.Create(e_,c_);
   tx.e:=e;tx.c:=c;
   if refl_=DIFF then m:=DiffuseClass.Create;
   if refl_=SPEC then m:=MirrorClass.Create;
   if refl_=REFR then m:=RefractClass.Create;
end;


constructor SphereClass.Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);
var
   b:Vec3;
begin
   inherited create(p_,e_,c_,refl_);
   rad:=rad_;
   BoundBox.new(p - b.new(rad, rad, rad),
                p + b.new(rad, rad, rad));
end;
function SphereClass.intersect(const r:RayRecord):InterInfo;
var
  op:Vec3;
  t,b,det:real;
begin
   op:=p-r.o;
   t:=eps;b:=op*r.d;det:=b*b-op*op+rad*rad;
   if det<0 then 
      result.t:=INF
   else begin
      det:=sqrt(det);
      t:=b-det;
      if t>eps then 
         result.t:=t
      else begin
         t:=b+det;
         if t>eps then 
            result.t:=t
         else
            result.t:=INF;
      end;
   end;
end;

function SphereClass.GetNorm(x:Vec3):Vec3;
begin
  result:=(x-p).norm;
end;


begin
end.
