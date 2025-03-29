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
    function intersect(const r:RayRecord):real;virtual;abstract;
    function GetNormVec(x:Vec3):Vec3;virtual;abstract;
    function GetLightVec(x:Vec3;org:DetectorClass):SurfaceInfo;virtual;abstract;
  end;
  SphereClass=class(DetectorClass)
    rad:real;       //radius
    constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);virtual;
    function intersect(const r:RayRecord):real;override;
    function GetNormVec(x:Vec3):Vec3;override;
    function GetLightVec(x:Vec3;org:DetectorClass):SurfaceInfo;override;
  end;
  RectClass=class(DetectorClass)
    H1,H2,V1,V2,w,h,area:Real;
    RA:RectAxisType;
    nl,hv,wv:Vec3;
    constructor Create(RA_:RectAxisType;H1_,H2_,V1_,V2_:real;p_,e_,c_:Vec3;refl_:RefType);
    function intersect(const r:RayRecord):real;override;
    function GetNormVec(x:Vec3):Vec3;override;
    function GetLightVec(x:Vec3;org:DetectorClass):SurfaceInfo;override;
  end;
  
function intersect(const r:RayRecord;var t:real; var id:integer):boolean;
function radiance(const r:RayRecord;depth:integer):Vec3;
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

function SphereClass.GetNormVec(x:Vec3):Vec3;
begin
  result:=(x-p).norm;
end;

function SphereClass.GetLightVec(x:Vec3;org:DetectorClass):SurfaceInfo;
var
  uvw:Vec3Matrix;
  tan_a,cos_a_max,eps1,eps2,cos_a,sin_a,phi:real;
  nl:Vec3;
begin
  tan_a:=(rad*rad)/(x-p).sqr;
  if tan_a>=1 then begin
    nl:=org.GetNormVec(x);//メインですでに実行しているので削除したいが、そうすると見通しが悪くなるので・・・
    result.l:=uvw.GetUniformVec(nl);//こちらもメインで既に実行している・・・
    result.Omega:=1;
    exit;//result:=uvw.getNormVec;
  end
  else begin
    uvw.GetUniformVec((p-x).norm);
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
  RA:=RA_;H1:=H1_;H2:=H2_;V1:=V1_;V2:=V2_;h:=H2-H1;w:=V2-V1;
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

function RectClass.GetNormVec(x:Vec3):Vec3;
begin
  result:=nl;
end;

function RectClass.GetLightVec(x:Vec3;org:DetectorClass):SurfaceInfo;
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
  result.l:=(r-x).norm;
  dist:=(x-r).sqr;
  result.Omega:=Area/(2*pi*dist);
end;

function intersect(const r:RayRecord;var t:real; var id:integer):boolean;
var 
  n,d:real;
  i:integer;
begin
  t:=INF;
  for i:=0 to sph.count-1 do begin
    d:=SphereClass(sph[i]).intersect(r);
    if d<t then begin
      t:=d;
      id:=i;
    end;
  end;
  result:=(t<inf);
end;


function radiance(const r:RayRecord;depth:integer):Vec3;
var
  id:integer;
  obj:SphereClass;
  x,n,nl,f:Vec3;
  uvw:Vec3Matrix;
  p,t:real;
  into:boolean;
  ray2,RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:Vec3;
begin
  id:=0;depth:=depth+1;
  if intersect(r,t,id)=false then begin
    result:=ZeroVec;exit;
  end;
  obj:=SphereClass(sph[id]);
  x:=r.o+r.d*t; n:=(x-obj.p).norm; f:=obj.c;
  if n.dot(r.d)<0 then nl:=n else nl:=n*-1;
  if (f.x>f.y)and(f.x>f.z) then
    p:=f.x
  else if f.y>f.z then 
    p:=f.y
  else
    p:=f.z;
   if (depth>5) then begin
    if random<p then 
      f:=f/p 
    else begin
      result:=obj.e;
      exit;
    end;
  end;
  case obj.refl of
    DIFF:begin
      result:=obj.e+f.Mult(radiance(ray2.new(x,uvw.GetUniformVec(nl) ),depth) );
      //GetUniformVecは引数vecを中心に半円状に一様分布するVecを算出する
    end;(*DIFF*)
    SPEC:begin
      result:=obj.e+f.mult(radiance(ray2.new(x,r.d-n*2*(n*r.d) ),depth));
    end;(*SPEC*)
    REFR:begin
      RefRay.new(x,r.d-n*2*(n*r.d) );
      into:= (n*nl>0);
      nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl; 
      cos2t:=1-nnt*nnt*(1-ddn*ddn);
      if cos2t<0 then begin   // Total internal reflection
        result:=obj.e + f.mult(radiance(RefRay,depth));
        exit;
      end;
      if into then q:=1 else q:=-1;
      tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
      if into then Q:=-ddn else Q:=tdir*n;
      a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
      Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
      if depth>2 then begin
        if random<p then // 反射
          result:=obj.e+f.mult(radiance(RefRay,depth)*RP)
        else //屈折
          result:=obj.e+f.mult(radiance(ray2.new(x,tdir),depth)*TP);
      end
      else begin// 屈折と反射の両方を追跡
        result:=obj.e+f.mult(radiance(RefRay,depth)*Re+radiance(ray2.new(x,tdir),depth)*Tr);
      end;
    end;(*REFR*)
  end;(*CASE*)
end;


function radiance_ne_rev(r:RayRecord;depth:integer;E:integer):Vec3;
var
  id,i,tid:integer;
  obj,s:DetectorClass;
  x,n,f,nl,d:Vec3;
  p,t:real;
  into:boolean;
  Ray2,RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:Vec3;
  EL:Vec3;
  SufInfo:SurfaceInfo;
  uvw:Vec3Matrix;
begin
  id:=0;depth:=depth+1;
  if intersect(r,t,id)=false then begin
    result:=ZeroVec;exit;
  end;
  obj:=DetectorClass(sph[id]);
  x:=r.o+r.d*t;  f:=obj.c;
  n:=obj.GetNormVec(x);
  if n.dot(r.d)<0 then nl:=n else nl:=n*-1;
  if (f.x>f.y)and(f.x>f.z) then
    p:=f.x
  else if f.y>f.z then 
    p:=f.y
  else
    p:=f.z;
  if (depth>5) then begin
    if random<p then 
      f:=f/p 
    else begin
      result:=obj.e;
      exit;
    end;
  end;
  case obj.refl of
    DIFF:begin
      d:=uvw.GetUniformVec(nl);
        // Loop over any lights
      EL:=ZeroVec;
      tid:=id;
      for i:=0 to sph.count-1 do begin
        s:=DetectorClass(sph[i]);
        if (i=tid) then begin
          continue;
        end;
        if (s.e.x<=0) and  (s.e.y<=0) and (s.e.z<=0)  then continue; // skip non-lights
        SufInfo:=s.GetLightVec(x,obj);
        if intersect(Ray2.new(x,SufInfo.l),t,id) then begin
          if id=i then begin
            tr:=SufInfo.l*nl;
            if tr<0 then tr:=0;
            EL:=EL+f.mult(s.e)*tr*SufInfo.Omega;
          end;
        end;
      end;(*for*)
      result:=obj.e*E+EL+f.Mult(radiance_ne_rev(ray2.new(x,d),depth,0) );
    end;(*DIFF*)
    SPEC:begin
      result:=obj.e+f.mult(radiance_ne_rev(ray2.new(x,r.d-n*2*(n*r.d) ),depth,1));
    end;(*SPEC*)
    REFR:begin
      RefRay.new(x,r.d-n*2*(n*r.d) );
      into:= (n*nl>0);
      nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl; 
      cos2t:=1-nnt*nnt*(1-ddn*ddn);
      if cos2t<0 then begin   // Total internal reflection
        result:=obj.e + f.mult(radiance_ne_rev(RefRay,depth,1));
        exit;
      end;
      if into then q:=1 else q:=-1;
      tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
      if into then Q:=-ddn else Q:=tdir*n;
      a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
      Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
      if depth>2 then begin
        if random<p then // 反射
          result:=obj.e+f.mult(radiance_ne_rev(RefRay,depth,1)*RP)
        else //屈折
          result:=obj.e+f.mult(radiance_ne_rev(ray2.new(x,tdir),depth,1)*TP);
      end
      else begin// 屈折と反射の両方を追跡
        result:=obj.e+f.mult(radiance_ne_rev(RefRay,depth,1)*Re+radiance_ne_rev(ray2.new(x,tdir),depth,1)*Tr);
      end;
    end;(*REFR*)
  end;(*CASE*)
end;

begin
end.
