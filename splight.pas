program splight;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

uses SysUtils,Classes,uVect,uBMP,Math,getopts;

const 
  eps=1e-4;
  INF=1e20;
  M_2PI=2*PI;
  M_1_PI=1/pi;
type 
  SphereClass=class
    rad:real;       //radius
    p,e,c:Vec3;// position. emission,color
    refl:RefType;
    constructor Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);
    function intersect(const r:RayRecord):real;
  end;

  CamRecord=record
    o,d:Vec3;
    PlaneDist:real;
    w,h:integer;
    cx,cy:Vec3;
    function new(o_,d_:Vec3;w_,h_:integer):CamRecord;
  end;
   

function CamRecord.new(o_,d_:Vec3;w_,h_:integer):CamRecord;
begin
  o:=o_;d:=d_;w:=w_;h:=h_;
  cx.new(w * 0.5135 / h, 0, 0);
  cy:= (cx/ d).norm* 0.5135;

  result:=self;

end;

constructor SphereClass.Create(rad_:real;p_,e_,c_:Vec3;refl_:RefType);
begin
  rad:=rad_;p:=p_;e:=e_;c:=c_;refl:=refl_;
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

var
  sph:TList;
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
  sph.add( SphereClass.Create(5,p.new(50,81.6-16.5,81.6), e.new(4,4,4)*10,   ZeroVec,  DIFF) );//Ligth
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


function radiance_light(const r:RayRecord;depth:integer):Vec3;
var
  id,i,tid:integer;
  obj,s:SphereClass;
  x,n,f,nl,u,v,w,d,sw,sv,su,EL,l:Vec3;
  p,r1,r2,r2s,t,eps1,eps2,eps2s,ss,cc,cos_a,sin_a,cos_a_max,phi,omega:real;
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
      tid:=id;
      EL:=ZeroVec;
      for i:=0 to sph.count-1 do begin
        s:=SphereClass(sph[i]);
        if (i=tid) then begin
            continue;
        end;
        if (s.e.x<=0) and  (s.e.y<=0) and (s.e.z<=0)  then continue; // skip non-lights
        sw:=s.p-x;
        tr:=sw*sw;  tr:=s.rad*s.rad/tr;
        if abs(sw.x)/sqrt(tr)>0.1 then 
            su:=(su.new(0,1,0)/sw).norm 
        else 
            su:=(su.new(1,0,0)/sw).norm;
        sv:=sw/su;
        if tr>1 then begin
            (*半球の内外=cos_aがマイナスとsin_aが＋、－で場合分け*)
            (*半球内部なら乱反射した寄与全てを取ればよい・・はず*)
            eps1:=M_2PI*random;eps2:=random;eps2s:=sqrt(eps2);
            sincos(eps1,ss,cc);
            l:=(u*(cc*eps2s)+v*(ss*eps2s)+w*sqrt(1-eps2)).norm;
            tr:=l*nl;if tr<0 then tr:=0;
            EL:=EL+f.mult(radiance_light(ray2.new(x,l),depth)*tr);
        end
        else begin //半球外部の場合;
            cos_a_max := sqrt(1-tr );
            eps1 := random; eps2:=random;
            cos_a := 1-eps1+eps1*cos_a_max;
            sin_a := sqrt(1-cos_a*cos_a);
            if (1-2*random)<0 then sin_a:=-sin_a; 
            phi := M_2PI*eps2;
            l:=(sw*(cos(phi)*sin_a)+sv*(sin(phi)*sin_a)+sw*cos_a).norm;
            omega := 2*PI*(1-cos_a_max);
            tr:=l*nl;
            if tr<0 then tr:=0;
                EL:=EL+f.mult(radiance_light(ray2.new(x,l),depth)*tr*omega)*M_1_PI;// 1/pi for brdf
          end;
        end;(*for*)
      result:=obj.e+EL;
    end;(*DIFF*)
    SPEC:begin
      result:=obj.e+f.mult(radiance_light(ray2.new(x,r.d-n*2*(n*r.d) ),depth));
    end;(*SPEC*)
    REFR:begin
      RefRay.new(x,r.d-n*2*(n*r.d) );
      into:= (n*nl>0);
      nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl; 
      cos2t:=1-nnt*nnt*(1-ddn*ddn);
      if cos2t<0 then begin   // Total internal reflection
        result:=obj.e + f.mult(radiance_light(RefRay,depth));
        exit;
      end;
      if into then q:=1 else q:=-1;
      tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
      if into then Q:=-ddn else Q:=tdir*n;
      a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
      Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
      if depth>2 then begin
        if random<p then // 反射
          result:=obj.e+f.mult(radiance_light(RefRay,depth)*RP)
        else //屈折
          result:=obj.e+f.mult(radiance_light(ray2.new(x,tdir),depth)*TP);
      end
      else begin// 屈折と反射の両方を追跡
        result:=obj.e+f.mult(radiance_light(RefRay,depth)*Re+radiance_light(ray2.new(x,tdir),depth)*Tr);
      end;
    end;(*REFR*)
  end;(*CASE*)
end;




var
  x,y,sx,sy,s: integer;
  w,h,samps: integer;
  cam:CamRecord;
  tColor,r,camPosition,camDirection : Vec3;

  BMP:BMPRecord;
  ArgInt:integer;
  FN,ArgFN:string;
  c:char;

   r1,r2,dx,dy:real;
   dirct:Vec3;
   ray2:RayRecord;
begin
  FN:='temp.bmp';
  w:=1024 ;h:=768;  samps := 16;
  c:=#0;
  repeat
    c:=getopt('ho:s:w:');

    case c of
      'o' : begin
         ArgFN:=OptArg;
         if ArgFN<>'' then FN:=ArgFN;
       end;
      's' : begin
        ArgInt:=StrToInt(OptArg);
        samps:=ArgInt;
        writeln('samples =',ArgInt);
      end;
      'w' : begin
         ArgInt:=StrToInt(OptArg);
         w:=ArgInt;h:=w *3 div 4;
         writeln('w=',w,' ,h=',h);
      end;
      '?','h' : begin
         writeln(' -o [finename] output filename');
         writeln(' -s [samps] sampling count');
         writeln(' -w [width] screen width pixel');
         halt;
      end;
    end; { case }
  until c=endofoptions;

  writeln('sample=',samps);
  writeln('output file=',FN);
  BMP.new(w,h);
  InitNEScene;
  Randomize;

  cam.new( camPosition.new(50, 52, 295.6),
           camDirection.new(0, -0.042612, -1).norm,
           w,h);
  writeln ('The time is : ',TimeToStr(Time));

  for y := 0 to h-1 do begin
    if y mod 10 =0 then writeln('y=',y);
    for x := 0 to w - 1 do begin
      tColor:=ZeroVec;
      for sy := 0 to 1 do begin
        for sx := 0 to 1 do begin
          r:=ZeroVec;
          for s := 0 to samps - 1 do begin
            r1 := 2 * random;
            if (r1 < 1) then dx := sqrt(r1) - 1 else dx := 1 - sqrt(2 - r1);
            r2 := 2 * random;
            if (r2 < 1) then dy := sqrt(r2) - 1 else dy := 1 - sqrt(2 - r2);
            dirct:= cam.cy* (((sy + 0.5 + dy) / 2 + (h - y - 1)) / h - 0.5)
                   +cam.cx* (((sx + 0.5 + dx) / 2 + x) / w - 0.5)
                   +cam.d;
            dirct:=dirct.norm;
            ray2.o:= dirct* 140+cam.o;
            ray2.d := dirct;

            r:=r+radiance_light(ray2, 0)/samps/2+radiance(ray2,0)/samps/2;
          end;(*samps*)
          tColor:=tColor+ ClampVector(r)* 0.25;
         end;(*sx*)
      end;(*sy*)
      BMP.SetPixel(x,h-y-1,ColToRGB(tColor));
    end;(* for x *)
  end;(*for y*)
  writeln ('The time is : ',TimeToStr(Time));
  if UpperCase(ExtractFileExt(FN))='.BMP' then
    BMP.WriteBMPFile(FN)
  else if UpperCase(ExtractFileExt(FN))='.PNG' then
    BMP.WritePNG(FN)
  else
    BMP.WritePPM(FN);
end.
