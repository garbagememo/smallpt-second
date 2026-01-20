unit uShape;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uTexture;

const 
  eps=1e-4;
  INF=1e20;
type
   ShapeClass=class;
   
   HitInfo=record
      isHit:boolean;
      t:real;
      id:integer;//本来オブジェクトにしたいが・・・
      FaceID:integer;//RectAngleのどの面かを示す
      obj:ShapeClass;
   end;
   InterInfo=record
      t:real;
      FaceID:integer;
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
      function GetNorm(x:Vec3;FaceID:integer):Vec3;virtual;abstract;
   end;
   
   SphereClass=class(ShapeClass)
      rad:real;       //radius
      constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);virtual;
      function intersect(const r:RayRecord):InterInfo;override;
      function GetNorm(x:Vec3;FaceID:integer):Vec3;override;
   end;

   RectAxisType=(XY,YZ,XZ);(*平面がどっち向いているか*)
   RectClass=class(ShapeClass)
      H1,H2,V1,V2,w,h:Real;
      RA:RectAxisType;
      nl,hv,wv:Vec3;
      constructor Create(RA_:RectAxisType;H1_,H2_,V1_,V2_:real;p_,e_,c_:Vec3;refl_:RefType);
      function intersect(const r:RayRecord):InterInfo;override;
      function GetNorm(x:Vec3;FaceID:integer):Vec3;override;
   end;


  RectAngleClass=class(ShapeClass)
    RAary:array[0..5] of RectClass;
    RACenter:Vec3;
    constructor Create(p1,p2,e_,c_:Vec3;refl_:RefType);
    function intersect(const r:RayRecord):InterInfo;override;
    function GetNorm(x:Vec3;FaceID:integer):Vec3;override;
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
   result.FaceID:=-1;
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

function SphereClass.GetNorm(x:Vec3;FaceID:integer):Vec3;
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


function RectClass.intersect(const r:RayRecord):InterInfo;
var
   t:real;
   pt:Vec3;
begin
   result.FaceID:=-1;
   (**光線と平行に近い場合の処理が必要だが・・・**)
   case RA of
      xy:begin
            result.t:=INF;
            if abs(r.d.z)<eps then exit;
            t:=(p.z-r.o.z)/r.d.z;
            if t<eps then exit;//result is INF
            pt:=r.o+r.d*t;
            if (pt.x<H2) and (pt.x>H1) and (pt.y<V2)and (pt.y>V1) then result.t:=t;
         end;(*xy*)
      xz:begin
            result.t:=INF;
            if abs(r.d.y)<eps then exit;
            t:=(p.y-r.o.y)/r.d.y;
            if t<eps then exit;//result is INF
            pt:=r.o+r.d*t;
            if (pt.x<H2) and (pt.x>H1) and (pt.z<V2)and (pt.z>V1) then result.t:=t;
         end;(*xz*)
      yz:begin
            result.t:=INF;
            if abs(r.d.x)<eps then exit;
            t:=(p.x-r.o.x)/r.d.x;
            if t<eps then exit;//result is INF
            pt:=r.o+r.d*t;
            if (pt.y<H2) and (pt.y>H1) and (pt.z<V2)and (pt.z>V1) then result.t:=t;
         end;(*yz*)
   end;(*case*)
end;

function RectClass.GetNorm(x:Vec3;FaceID:integer):Vec3;
begin
  result:=nl;
end;

constructor RectAngleClass.Create(p1,p2,e_,c_:Vec3;refl_:RefType);
begin
  inherited create(p2,e_,c_,refl_);
  (*xy*)
  RAary[0]:=RectClass.Create(XY,p1.x,p2.x,p1.y,p2.y,p1,e_,c_,refl_);
  RAary[1]:=RectClass.Create(XY,p1.x,p2.x,p1.y,p2.y,p2,e_,c_,refl_);
  (*xz*)
  RAary[2]:=RectClass.Create(XZ,p1.x,p2.x,p1.z,p2.z,p1,e_,c_,refl_);
  RAary[3]:=RectClass.Create(XZ,p1.x,p2.x,p1.z,p2.z,p2,e_,c_,refl_);
  (*YZ*)
  RAary[4]:=RectClass.Create(YZ,p1.y,p2.y,p1.z,p2.z,p1,e_,c_,refl_);
  RAary[5]:=RectClass.Create(YZ,p1.y,p2.y,p1.z,p2.z,p2,e_,c_,refl_);  
  (*NEE*)
  RACenter:=(p1+p2)/2;
end;
function RectAngleClass.intersect(const r:RayRecord):InterInfo;
var
   i:integer;
   Info:InterInfo;
begin
   result.t:=INF;
   result.FaceID:=-1;
   for i:=0 to 5 do begin
      Info:=RAary[i].intersect(r);
      if Info.t < result.t then begin
         result.t:=info.t;
         Result.FaceID:=i;
      end;
   end;
end;

function RectAngleClass.GetNorm(x:Vec3;FaceID:integer):Vec3;
begin
  result:=RAary[FaceID].GetNorm(x,FaceID);
end;


begin
end.
