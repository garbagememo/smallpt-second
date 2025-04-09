unit uDetector;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts;

const 
  eps=1e-4;
  INF=1e20;
  M_2PI=PI*2;
  M_1_PI=1/PI;

type
  
  DetectorClass=class;
  
  InterRecord=record
    t:real;
    id:integer;
    LocalID:integer;//GetLightVecで利用する局所オブジェクトIDを入れる・・・汎用的か？
    obj:DetectorClass;
    x:Vec3;
  end;
     
  SurfaceInfo=record
    l:Vec3;
    omega:real;
  end;
    
  AABBRecord=record
    Min,Max:Vec3;
    function hit(r:RayRecord;tmin,tmax:real):boolean;
    function new(m0,m1:Vec3):AABBRecord;
    function MargeBoundBox(box1:AABBRecord):AABBRecord;
  end;

  RectAxisType=(XY,YZ,XZ);(*平面がどっち向いているか*)

  DetectorClass=Class
    p,e,c:Vec3;// position. emission,color
    refl:RefType;
    Omega:real;//マルチスレッド時にはクラス内の値は使わないほうがよいのでこの形は修正すべき
    BoundBox:AABBRecord;
    constructor Create(p_,e_,c_:Vec3;refl_:RefType);virtual;
    function intersect(const r:RayRecord):InterRecord;virtual;abstract;
    function GetNormVec(IR:InterRecord):Vec3;virtual;abstract;
    function GetLightVec(IR:InterRecord):SurfaceInfo;virtual;abstract;
  end;
  SphereClass=class(DetectorClass)
    rad:real;       //radius
    constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);virtual;
    function intersect(const r:RayRecord):InterRecord;override;
    function GetNormVec(IR:InterRecord):Vec3;override;
    function GetLightVec(IR:InterRecord):SurfaceInfo;override;
  end;
  RectClass=class(DetectorClass)
    H1,H2,V1,V2,w,h,area:Real;
    RA:RectAxisType;
    nl,hv,wv:Vec3;
    constructor Create(RA_:RectAxisType;H1_,H2_,V1_,V2_:real;p_,e_,c_:Vec3;refl_:RefType);
    function intersect(const r:RayRecord):InterRecord;override;
    function GetNormVec(IR:InterRecord):Vec3;override;
    function GetLightVec(IR:InterRecord):SurfaceInfo;override;
  end;
 RectAngleClass=class(DetectorClass)
    RAary:array[0..5] of RectClass;
    RACenter:Vec3;
    TotalArea,XAreaP,YAreaP,ZAreaP:real;
    RAPary:array[0..5]of real;
    constructor Create(p1,p2,e_,c_:Vec3;refl_:RefType);
    function intersect(const r:RayRecord):InterRecord;override;
    function GetNormVec(IR:InterRecord):Vec3;override;
    function GetLightVec(IR:InterRecord):SurfaceInfo;override;
  end;
 
 
function intersect(const r:RayRecord;var IR:InterRecord):boolean;

function radiance_ne_rev(r:RayRecord;depth:integer;E:integer):Vec3;

var
   sph:TList;//object list


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
   rad:=rad_; inherited create(p_,e_,c_,refl_);
   BoundBox.new(p - b.new(rad, rad, rad),
                p + b.new(rad, rad, rad));
end;

constructor DetectorClass.Create(p_,e_,c_:Vec3;refl_:RefType);
begin
  p:=p_;e:=e_;c:=c_;refl:=refl_;
end;

function SphereClass.intersect(const r:RayRecord):InterRecord;
var
  op:Vec3;
  t,b,det:real;
begin
  result.localID:=-1;
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

function SphereClass.GetNormVec(IR:InterRecord):Vec3;
begin
  result:=(IR.x-p).norm;
end;

function SphereClass.GetLightVec(IR:InterRecord):SurfaceInfo;
var
  uvw:Vec3Matrix;
  tan_a,cos_a_max,eps1,eps2,cos_a,sin_a,phi:real;
  nl:Vec3;
begin
  tan_a:=(rad*rad)/(IR.x-p).sqr;
  if tan_a>=1 then begin
    nl:=IR.Obj.GetNormVec(IR);//メインですでに実行しているので削除したいが、そうすると見通しが悪くなるので・・・
    result.l:=uvw.GetUniformVec(nl);//こちらもメインで既に実行している・・・
    result.Omega:=1;
    exit;//result:=uvw.getNormVec;
  end
  else begin
    uvw.GetUniformVec((p-IR.x).norm);
    cos_a_max := sqrt(1 - tan_a);
    eps1 := random; eps2:=random;
    cos_a := 1-eps1+eps1*cos_a_max;
    sin_a := sqrt(1-cos_a*cos_a);
    if (1-2*random)<0 then sin_a:=-sin_a; 
    phi := M_2PI*eps2;
    result.l:=(uvw.u*(cos(phi)*sin_a)+uvw.v*(sin(phi)*sin_a)+uvw.w*cos_a).norm;
    result.Omega:=2*PI*(1-cos_a_max)*M_1_PI;
  end;
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
  area:=w*h;
//  writeln('Area=',Area:5:0,' w:h=',w:4:0,':',h:4:0);
  inherited create(p_,e_,c_,refl_);
//  writeln('nl=');VecWriteln(nl);
end;


function RectClass.intersect(const r:RayRecord):InterRecord;
var
  t:real;
  pt:Vec3;
begin
  result.LocalID:=-1;
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

function RectClass.GetNormVec(IR:InterRecord):Vec3;
begin
  result:=nl;
end;

function RectClass.GetLightVec(IR:InterRecord):SurfaceInfo;
var
  r:Vec3;
  dist,eps1,eps2:real;
begin
  //平面上の点を求めて、視線からのVecを求める
  //Omegaは半球状の視野角を求めるので・・・・Area/r^2 /2pi
  eps1:=random;eps2:=random;
  case RA of
    XY:begin r.x:=p.x+h*eps1;r.y:=p.y+w*eps2; r.z:=p.z end;
    XZ:begin r.x:=p.x+h*eps1;r.z:=p.z+w*eps2; r.y:=p.y end;
    YZ:begin r.y:=p.y+h*eps1;r.z:=p.z+w*eps2; r.x:=p.x end;
  end;
  result.l:=(r-IR.x).norm;
  dist:=(IR.x-r).sqr;
  result.Omega:=Area/(2*pi*dist);
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
  TotalArea:=(RAary[0].Area+RAary[2].Area+RAary[4].Area)*2;
  RAPary[0]:=RAary[0].Area/TotalArea;
  RAPary[1]:=RAary[1].Area/TotalArea+RAPary[0];
  RAPary[2]:=RAary[2].Area/TotalArea+RAPary[1];
  RAPary[3]:=RAary[3].Area/TotalArea+RAPary[2];
  RAPary[4]:=RAary[4].Area/TotalArea+RAPary[3];
  RAPary[5]:=RAary[5].Area/TotalArea+RAPary[4];

end;

function RectAngleClass.GetLightVec(IR:InterRecord):SurfaceInfo;
var
  eps,r:real;
  i:integer;
begin
  r:=random;
  for i:=0 to 5 do begin
    if r<RAPary[i] then begin
      result:=RAary[i].GetLightVec(IR);
      exit;
    end;
  end;      
  result:=RAary[5].GetLightVec(IR);
end;

function RectAngleClass.intersect(const r:RayRecord):InterRecord;
var
  i:integer;
  d,t:real;
  ir:InterRecord;
begin
  result.t:=INF;
  result.localID:=-1;
  for i:=0 to 5 do begin
    IR:=RAary[i].intersect(r);
    if result.t>IR.t then begin
      result.t:=IR.t;
      result.localID:=i;
    end;
  end;
end;

function RectAngleClass.GetNormVec(IR:InterRecord):Vec3;
begin
  result:=RAary[IR.LocalID].GetNormVec(IR);
end;



function intersect(const r:RayRecord;var IR:InterRecord):boolean;
var
  OIR:InterRecord;
  n:real;
  i:integer;
begin
  IR.t:=INF;
  for i:=0 to sph.count-1 do begin
    OIR:=DetectorClass(sph[i]).intersect(r);
    if OIR.t<IR.t then begin
      IR.t:=OIR.t;
      IR.id:=i;
      IR.LocalID:=OIR.LocalID;
    end;
  end;
  result:=(IR.t<inf);
end;

function radiance_ne_rev(r:RayRecord;depth:integer;E:integer):Vec3;
var
  i,tid:integer;
  s:DetectorClass;
  n,f,nl,d:Vec3;
  p:real;
  into:boolean;
  Ray2,RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:Vec3;
  EL:Vec3;
  SufInfo:SurfaceInfo;
  uvw:Vec3Matrix;
  IR:InterRecord;
begin
  IR.id:=0;depth:=depth+1;
  if intersect(r,IR)=false then begin
    result:=ZeroVec;exit;
  end;
  IR.obj:=DetectorClass(sph[IR.id]);
  IR.x:=r.o+r.d*IR.t;  f:=IR.obj.c;
  n:=IR.obj.GetNormVec(IR);
  if n.dot(r.d)<0 then nl:=n else nl:=n*-1;
  if (f.x>f.y)and(f.x>f.z) then
    p:=f.x
  else if f.y>f.z then 
    p:=f.y
  else
    p:=f.z;
  
  if depth>5 then begin
    if random<p then 
      f:=f/p 
    else begin
      result:=IR.obj.e;
      exit;
    end;
  end;
  
  case IR.obj.refl of
    DIFF:begin
      d:=uvw.GetUniformVec(nl);
        // Loop over any lights
      EL:=ZeroVec;
      tid:=IR.id;
      for i:=0 to sph.count-1 do begin
        s:=DetectorClass(sph[i]);
        if (i=tid) then begin
          continue;
        end;
        if (s.e.x<=0) and  (s.e.y<=0) and (s.e.z<=0)  then continue; // skip non-lights
        SufInfo:=s.GetLightVec(IR);
        if intersect(Ray2.new(IR.x,SufInfo.l),IR) then begin
          if IR.id=i then begin
            tr:=SufInfo.l*nl;
            if tr<0 then tr:=0;
            EL:=EL+f.mult(s.e)*tr*SufInfo.Omega;
          end;
        end;
      end;(*for*)
      result:=IR.obj.e*E+EL+f.Mult(radiance_ne_rev(ray2.new(IR.x,d),depth,0) );
    end;(*DIFF*)
    SPEC:begin
      result:=IR.obj.e+f.mult(radiance_ne_rev(ray2.new(IR.x,r.d-n*2*(n*r.d) ),depth,1));
    end;(*SPEC*)
    REFR:begin
      RefRay.new(IR.x,r.d-n*2*(n*r.d) );
      into:= (n*nl>0);
      nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl; 
      cos2t:=1-nnt*nnt*(1-ddn*ddn);
      if cos2t<0 then begin   // Total internal reflection
        result:=IR.obj.e + f.mult(radiance_ne_rev(RefRay,depth,1));
        exit;
      end;
      if into then q:=1 else q:=-1;
      tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
      if into then Q:=-ddn else Q:=tdir*n;
      a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
      Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
      if depth>2 then begin
        if random<p then // 反射
          result:=IR.obj.e+f.mult(radiance_ne_rev(RefRay,depth,1)*RP)
        else //屈折
          result:=IR.obj.e+f.mult(radiance_ne_rev(ray2.new(IR.x,tdir),depth,1)*TP);
      end
      else begin// 屈折と反射の両方を追跡
        result:=IR.obj.e
          +f.mult(radiance_ne_rev(RefRay,depth,1)*Re
                  +radiance_ne_rev(ray2.new(IR.x,tdir),depth,1)*Tr);
      end;
    end;(*REFR*)
  end;(*CASE*)
end;

begin
end.
