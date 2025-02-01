unit uDetector;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts;

const 
  eps=1e-4;
  INF=1e20;
type
   AABBRecord=record
      Min,Max:Vec3;
      function hit(r:RayRecord;tmin,tmax:real):boolean;
      function new(m0,m1:Vec3):AABBRecord;
      function MargeBoundBox(box1:AABBRecord):AABBRecord;
   end;
   
  SphereClass=class
    rad:real;       //radius
    p,e,c:Vec3;// position. emission,color
    refl:RefType;
    BoundBox:AABBRecord;
    constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);
    function intersect(const r:RayRecord):real;
  end;

function intersect(const r:RayRecord;var t:real; var id:integer):boolean;
function radiance(const r:RayRecord;depth:integer):Vec3;

var
   sph:TList;

procedure InitScene;
procedure InitNEScene;
procedure SkyScene;
procedure ForestScene;
procedure WadaScene;
procedure RandomScene;
  


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
  x,n,f,nl,u,v,w,d:Vec3;
  p,r1,r2,r2s,t:real;
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
      r1:=2*PI*random;r2:=random;r2s:=sqrt(r2);
      w:=nl;
      if abs(w.x)>0.1 then
        u:=(u.new(0,1,0)/w).norm 
      else begin
        u:=(u.new(1,0,0)/w ).norm;
      end;
      v:=w/u;
      d := (u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrt(1-r2)).norm;
      result:=obj.e+f.Mult(radiance(ray2.new(x,d),depth) );
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

procedure InitScene;
var
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),  ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
  sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6), ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
  sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),      ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
  sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170),  ZeroVec,c.new(0,0,0),      DIFF) );//Front
  sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),     ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
  sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
  sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999, SPEC) );//Mirror
  sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999, REFR) );//Glass
  sph.add( SphereClass.Create(600, p.new(50,681.6-0.27,81.6),e.new(12,12,12),    ZeroVec,DIFF) );//Ligth
end;

procedure InitNEScene;
var
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),  ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
  sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6), ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
  sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),      ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
  sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170+eps),ZeroVec,ZeroVec            ,DIFF) );//Front
  sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),     ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
  sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
  sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999,   SPEC) );//Mirror
  sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999,   REFR) );//Glass
  sph.add( SphereClass.Create( 1.5,p.new(50,81.6-16.5,81.6), e.new(4,4,4)*100,   ZeroVec,  DIFF) );//Ligth

end;

procedure RandomScene;
var
   Cen,Cen1,Cen2,Cen3:Vec3;
   a,b:integer;
   RandomMatterial:real;
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  Cen.new(50,40.8,-860);

  Cen1.new(75,25, 85);
  Cen2.new(45,25, 30);
  Cen3.new(15,25,-25);
  

  sph.add(SphereClass.Create(10000,  Cen+p.new(0,0,-200)  , e.new(0.6, 0.5, 0.7)*0.8, c.new(0.7,0.9,1.0),  DIFF)); // sky
  sph.add(SphereClass.Create(100000, p.new(50, -100000, 0), ZeroVec,                  c.new(0.4,0.4,0.4),  DIFF)); // grnd


  sph.add(SphereClass.Create(25,  Cen1 ,ZeroVec,c.new(0.9,0.9,0.9), SPEC));// Glas
  sph.add(SphereClass.Create(25,  Cen2 ,ZeroVec,c.new(0.95,0.95,0.95),  REFR)); // Glass
  sph.add(SphereClass.Create(25,  Cen3 ,ZeroVec,c.new(1,0.6,0.6)*0.696, DIFF));    // 乱反射
  for a:=-11 to 11 do begin
     for b:=-11 to 11 do begin
        RandomMatterial:=random;
        Cen.new( (a+random)*25,5,(b+random)*25);
        if ( (Cen - Cen1) ).len>25*1.0 then begin
           if RandomMatterial<0.8 then begin
              sph.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),DIFF));
           end
           else if RandomMatterial <0.95 then begin
              sph.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),SPEC));
           end
           else begin
              sph.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),REFR));
           end;
        end;
     end;
  end;
end;

procedure SkyScene;
var
   Cen,p,e,c:Vec3;
begin
  sph:=TList.Create;
  Cen.new(50,40.8,-860);

  sph.add(SphereClass.Create(1600,      p.new(1,0,2)*3000,   e.new(1,0.9,0.8)*1.2e1*1.56*2,  ZeroVec, DIFF)); // sun
  sph.add(SphereClass.Create(1560,      p.new(1,0,2)*3500,   e.new(1,0.5,0.05)*4.8e1*1.56*2, ZeroVec,  DIFF) ); // horizon sun2
  sph.add(SphereClass.Create(10000, Cen+p.new(0,0,-200),     e.new(0.00063842, 0.02001478, 0.28923243)*6e-2*8, c.new(0.7,0.7,1)*0.25,  DIFF)); // sky

  sph.add(SphereClass.Create(100000,    p.new(50, -100000, 0),ZeroVec,c.new(0.3,0.3,0.3),DIFF)); // grnd
  sph.add(SphereClass.Create(110000,    p.new(50, -110048.5, 0),e.new(0.9,0.5,0.05)*4,ZeroVec,DIFF));// horizon brightener
  sph.add(SphereClass.Create(4e4,       p.new(50, -4e4-30, -3000),ZeroVec,c.new(0.2,0.2,0.2),DIFF));// mountains

  sph.add(SphereClass.Create(26.5,p.new(22,26.5,42),ZeroVec,c.new(1,1,1)*0.596, SPEC)); // white Mirr
  sph.add(SphereClass.Create(13,p.new(75,13,82),ZeroVec,c.new(0.96,0.96,0.96)*0.96, REFR));// Glas
  sph.add(SphereClass.Create(22,p.new(87,22,24),ZeroVec,c.new(0.6,0.6,0.6)*0.696, REFR));    // Glas2
end;

procedure ForestScene;
var
   tc,scc,p,e,c:Vec3;
begin
  sph:=TList.Create;

  tc:=tc.new(0.0588, 0.361, 0.0941);
  scc:=scc.new(1,1,1)*0.7;
  sph.add(SphereClass.Create(1e5, p.new(50, 1e5+130, 0),  e.new(1,1,1)*1.3,ZeroVec,DIFF)); //lite
  sph.add(SphereClass.Create(1e2, p.new(50, -1e2+2, 47),  ZeroVec,c.new(1,1,1)*0.7,DIFF)); //grnd

  sph.add(SphereClass.Create(1e4, p.new(50, -30, 300)+e.new(-sin(50*PI/180), 0, cos(50*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr L
  sph.add(SphereClass.Create(1e4, p.new(50, -30, 300)+e.new(sin(50*PI/180),  0, cos(50*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr R
  sph.add(SphereClass.Create(1e4, p.new(50, -30, -50)+e.new(-sin(30*PI/180), 0,-cos(30*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr FL
  sph.add(SphereClass.Create(1e4, p.new(50, -30, -50)+e.new(sin(30*PI/180),  0,-cos(30*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr


  sph.add(SphereClass.Create(4, p.new(50,6*0.6,47),                         ZeroVec, c.new(0.13,0.066,0.033), DIFF));//"tree"
  sph.add(SphereClass.Create(16,p.new(50,6*2+16*0.6,47),                    ZeroVec, tc,  DIFF));//"tree"
  sph.add(SphereClass.Create(11,p.new(50,6*2+16*0.6*2+11*0.6,47),           ZeroVec, tc,  DIFF));//"tree"
  sph.add(SphereClass.Create(7, p.new(50,6*2+16*0.6*2+11*0.6*2+7*0.6,47),   ZeroVec, tc,  DIFF));//"tree"

  sph.add(SphereClass.Create(15.5,p.new(50,1.8+6*2+16*0.6,47),              ZeroVec, scc,  DIFF));//"tree"
  sph.add(SphereClass.Create(10.5,p.new(50,1.8+6*2+16*0.6*2+11*0.6,47),     ZeroVec, scc,  DIFF));//"tree"
  sph.add(SphereClass.Create(6.5, p.new(50,1.8+6*2+16*0.6*2+11*0.6*2+7*0.6,47), ZeroVec, scc,  DIFF));//"tree"

end;

procedure wadaScene;
var
   R,T,D,Z:real;
   p,c,e:Vec3;
begin
  sph:=TList.Create;

  R:=60;
  //double R=120;
  T:=30*PI/180.;
  D:=R/cos(T);
  Z:=60;

  sph.add(SphereClass.Create(1e5, p.new(50, 100, 0),      e.new(1,1,1)*3e0, ZeroVec           , DIFF)); // sky
  sph.add(SphereClass.Create(1e5, p.new(50, -1e5-D-R, 0), ZeroVec,          c.new(0.1,0.1,0.1),DIFF));           //grnd

  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new( cos(T),sin(T),0)*D, ZeroVec, c.new(1,0.3,0.3)*0.999, SPEC)); //red
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(-cos(T),sin(T),0)*D, ZeroVec, c.new(0.3,1,0.3)*0.999, SPEC)); //grn
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(0,-1,0)*D,           ZeroVec, c.new(0.3,0.3,1)*0.999, SPEC)); //blue
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(0,0,-1)*D,           ZeroVec, c.new(0.53,0.53,0.53)*0.999, SPEC)); //back
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(0,0,1)*D,            ZeroVec, c.new(1,1,1)*0.999, REFR)); //front
end;


begin
end.
