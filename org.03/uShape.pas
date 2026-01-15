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
      BoundBox:AABBRecord;
      constructor Create(p_,e_,c_:Vec3;refl_:RefType);virtual;
      function intersect(const r:RayRecord):real;virtual;abstract;
      function GetNorm(x:Vec3):Vec3;virtual;abstract;
   end;
   
   SphereClass=class(ShapeClass)
      rad:real;       //radius
      constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);virtual;
      function intersect(const r:RayRecord):real;override;
      function GetNorm(x:Vec3):Vec3;override;
   end;

   RectAxisType=(XY,YZ,XZ);(*平面がどっち向いているか*)
   RectClass=class(ShapeClass)
      H1,H2,V1,V2,w,h:Real;
      RA:RectAxisType;
      nl,hv,wv:Vec3;
      constructor Create(RA_:RectAxisType;H1_,H2_,V1_,V2_:real;p_,e_,c_:Vec3;refl_:RefType);
      function intersect(const r:RayRecord):real;override;
      function GetNorm(x:Vec3):Vec3;override;
   end;

   ShapeListClass=Class
      shapes:TList;
      constructor create;
      procedure add(s : ShapeClass);
      function intersect(const r: RayRecord):SurfaceInfo;
   end;
   
function radiance(const r:RayRecord;depth:integer):Vec3;

var
   sph:ShapeListClass;



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

constructor RectClass.Create(RA_:RectAxisType;H1_,H2_,V1_,V2_:real;p_,e_,c_:Vec3;refl_:RefType);
var
   bMin,bMax:Vec3;
begin
   RA:=RA_;H1:=Min(H1_,H2_);H2:=Max(H2_,H1_);V1:=Min(V1_,V2_);V2:=Max(V2_,V1_);h:=H2-H1;w:=V2-V1;
   case RA of
      XY:begin
            p_.x:=H1; p_.y:=V1; hv.new(H2-H1,0,0);wv.new(0,V2-V1,0);
            BoundBox.new(bMin.new(min(H1,H2),min(V1,V2),p_.z-eps),
                         bMax.new(Max(H1,H2),Max(V1,V2),p_.z+eps) );
         end;
      XZ:begin
            p_.x:=H1; p_.z:=V1; hv.new(H2-H1,0,0);wv.new(0,0,V2-V1);
            BoundBox.new(bMin.new(min(H1,H2),p_.y-eps,min(V1,V2)),
                         bMax.new(Max(H1,H2),p_.y+eps,Max(V1,V2)) );
         end;
      YZ:begin
            p_.y:=H1; p_.z:=V1; hv.new(0,H2-H1,0);wv.new(0,0,v2-v1);
            BoundBox.new(bMin.new(p_.x-eps,min(H1,H2),min(V1,V2)),
                         bMax.new(p_.x+eps,Max(H1,H2),Max(V1,V2)) );
         end;
   end;
   nl:=(hv/wv).norm*-1;
   //  writeln('Area=',Area:5:0,' w:h=',w:4:0,':',h:4:0);
   inherited create(p_,e_,c_,refl_);
   //  writeln('nl=');VecWriteln(nl);
end;


function RectClass.intersect(const r:RayRecord):real;
var
   t:real;
   pt:Vec3;
begin
   (**光線と平行に近い場合の処理が必要だが・・・**)
   case RA of
      xy:begin
            result:=INF;
            if abs(r.d.z)<eps then exit;
            t:=(p.z-r.o.z)/r.d.z;
            if t<eps then exit;//result is INF
            pt:=r.o+r.d*t;
            if (pt.x<H2) and (pt.x>H1) and (pt.y<V2)and (pt.y>V1) then result:=t;
         end;(*xy*)
      xz:begin
            result:=INF;
            if abs(r.d.y)<eps then exit;
            t:=(p.y-r.o.y)/r.d.y;
            if t<eps then exit;//result is INF
            pt:=r.o+r.d*t;
            if (pt.x<H2) and (pt.x>H1) and (pt.z<V2)and (pt.z>V1) then result:=t;
         end;(*xz*)
      yz:begin
            result:=INF;
            if abs(r.d.x)<eps then exit;
            t:=(p.x-r.o.x)/r.d.x;
            if t<eps then exit;//result is INF
            pt:=r.o+r.d*t;
            if (pt.y<H2) and (pt.y>H1) and (pt.z<V2)and (pt.z>V1) then result:=t;
         end;(*yz*)
   end;(*case*)
end;

function RectClass.GetNorm(x:Vec3):Vec3;
begin
  result:=nl;
end;

constructor ShapeListClass.create;
begin
   Shapes:=TList.Create;
end;
procedure ShapeListClass.add(s: ShapeClass);
begin
   Shapes.add(s);
end;

function ShapeListClass.intersect(const r:RayRecord):SurfaceInfo;
var 
  x,n,nl:Vec3;
  t,d:real;
  i,id:integer;

begin
  result.isHit:=false;
  result.t:=INF;
  t:=INF;
  id:=Shapes.count-1;
  for i:=0 to Shapes.count-1 do begin
    d:=ShapeClass(Shapes[i]).intersect(r);
    if d<t then begin
      t:=d;
      id:=i;
    end;
  end;
  result.isHit:=(t<inf);
  if result.isHit then begin
     result.t:=t;
     result.x:=r.o+r.d*t;
     result.obj:=ShapeClass(Shapes[id]);
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
   sInfo:=sph.intersect(r);
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
