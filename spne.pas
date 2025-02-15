program smallpt;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

uses SysUtils,Classes,uVect,uDetector,uBMP,Math,getopts;

type 

  CamRecord=record
    o,d:Vec3;
    PlaneDist:real;
    w,h:integer;
    cx,cy:Vec3;
    function new(o_,d_:Vec3;w_,h_:integer):CamRecord;
    function GetRay(x,y,sx,sy:integer):RayRecord;
  end;
   

function CamRecord.new(o_,d_:Vec3;w_,h_:integer):CamRecord;
begin
  o:=o_;d:=d_;w:=w_;h:=h_;
  cx.new(w * 0.5135 / h, 0, 0);
  cy:= (cx/ d).norm* 0.5135;
  result:=self;
end;

function CamRecord.GetRay(x,y,sx,sy:integer):RayRecord;
var
   r1,r2,dx,dy,temp:real;
   dirct:Vec3;
begin
   r1 := 2 * random;
   if (r1 < 1) then dx := sqrt(r1) - 1 else dx := 1 - sqrt(2 - r1);
   r2 := 2 * random;
   if (r2 < 1) then dy := sqrt(r2) - 1 else dy := 1 - sqrt(2 - r2);
   dirct:= cy* (((sy + 0.5 + dy) / 2 + (h - y - 1)) / h - 0.5)
      +cx* (((sx + 0.5 + dx) / 2 + x) / w - 0.5)
      +d;
   dirct:=dirct.norm;
   result.o:= dirct* 140+o;
   result.d := dirct;
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

function radiance_ne(r:RayRecord;depth:integer;E:integer):Vec3;
var
  id,i,tid:integer;
  obj,s:SphereClass;
  x,n,f,nl,d:Vec3;
  p,r1,r2,r2s,t,m1,ss,cc:real;
  into:boolean;
  Ray2,RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:Vec3;
  EL,sw,su,sv,l,tw,tu,tv:Vec3;
  cos_a_max,eps1,eps2,eps2s,cos_a,sin_a,phi,omega:real;
  cl,cf:Vec3;
  uvw:Vec3Matrix;
begin
//writeln(' DebugY=',DebugY,' DebugX=',DebugX);
  depth:=0;
  id:=0;cl:=ZeroVec;cf:=cf.new(1,1,1);E:=1;
  while (TRUE) do begin
    Inc(depth);
    if intersect(r,t,id)=false then begin
      result:=cl;
      exit;
    end;
    obj:=SphereClass(sph[id]);
    x:=r.o+r.d*t; n:=(x-obj.p).norm; f:=obj.c;
    if n*r.d<0 then nl:=n else nl:=n*-1;
    if (f.x>f.y)and(f.x>f.z) then
      p:=f.x
    else if f.y>f.z then
      p:=f.y
    else
      p:=f.z;
    tw:=obj.e*E;
    cl:=cl+cf.mult(tw);

    if (Depth > 5) or (p = 0) then
       if (random < p) then begin
         f:= f / p;
       end
       else begin
         Result := cl;
         exit;
       end;

    cf:=f.mult(cf);
    case obj.refl of
      DIFF:begin
        d:=uvw.GetUniformVec(nl);
        // Loop over any lights
        EL:=ZeroVec;
        tid:=id;
        for i:=0 to sph.count-1 do begin
          s:=SphereClass(sph[i]);
          if (i=tid) then begin
            continue;
          end;
          if (s.e.x<=0) and  (s.e.y<=0) and (s.e.z<=0)  then continue; // skip non-lights
          sw:=s.p-x;
          tr:=sw*sw;  tr:=s.rad*s.rad/tr;
          if abs(sw.x)>0.1 then 
            su:=(su.new(0,1,0)/sw).norm 
          else 
            su:=(su.new(1,0,0)/sw).norm;
          sv:=sw/su;
          if tr>1 then begin
            (*半球の内外=cos_aがマイナスとsin_aが＋、－で場合分け*)
            (*半球内部なら乱反射した寄与全てを取ればよい・・はず*)
            eps1:=M_2PI*random;eps2:=random;eps2s:=sqrt(eps2);
            sincos(eps1,ss,cc);
            l:=(uvw.u*(cc*eps2s)+uvw.v*(ss*eps2s)+uvw.w*sqrt(1-eps2) ).norm;
            if intersect(Ray2.new(x,l),t,id) then begin
              if id=i then begin
                tr:=l*nl;
                EL:=EL+f.mult(s.e*tr);
              end;
            end;
          end
          else begin //半球外部の場合;
            cos_a_max := sqrt(1-tr );
            eps1 := random; eps2:=random;
            cos_a := 1-eps1+eps1*cos_a_max;
            sin_a := sqrt(1-cos_a*cos_a);
            if (1-2*random)<0 then sin_a:=-sin_a; 
            phi := M_2PI*eps2;
             l:=(sw*(cos(phi)*sin_a)+sv*(sin(phi)*sin_a)+sw*cos_a).norm;
            if (intersect(Ray2.new(x,l), t, id) ) then begin 
              if id=i then begin  // shadow ray
                omega := 2*PI*(1-cos_a_max);
                tr:=l*nl;
                if tr<0 then tr:=0;
                tw:=s.e*tr*omega;tw:=f.mult(tw)*M_1_PI;
                EL := EL + tw;  // 1/pi for brdf
              end;
            end;
          end;
        end;(*for*)
        tw:=obj.e*e+EL;
        cl:= cl+cf.mult(tw );
        E:=0;
        r.new(x,d)
      end;(*DIFF*)
      SPEC:begin
        cl:=cl+cf.mult(obj.e*e);
        E:=1;tv:=n*2*(n*r.d) ;tv:=r.d-tv;
        r.new(x,tv);
      end;(*SPEC*)
      REFR:begin
        tv:=n*2*(n*r.d) ;tv:=r.d-tv;
        RefRay.new(x,tv);
        into:= (n*nl>0);
        nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl;
        cos2t:=1-nnt*nnt*(1-ddn*ddn);
        if cos2t<0 then begin   // Total internal reflection
          cl:=cl+cf.mult(obj.e*E);
          E:=1;
          r:=RefRay;
          continue;
        end;
        if into then q:=1 else q:=-1;
        tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
        if into then Q:=-ddn else Q:=tdir*n;
        a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
        Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
        if random<p then begin// 反射
          cf:=cf*RP;
          cl:=cl+cf.mult(obj.e*E);
          E:=1;
          r:=RefRay;
        end
        else begin//屈折
          cf:=cf*TP;
          cl:=cl+cf.Mult(obj.e*E);
          E:=1;
          r.new(x,tdir);
        end
      end;(*REFR*)
    end;(*CASE*)
  end;(*WHILE LOOP *)
end;


var
  x,y,sx,sy,s: integer;
  w,h,samps,height,modelid: integer;
  temp       : Vec3;
  tColor,r,camPosition,camDirection : Vec3;
  cam:CamRecord;
  BMP:BMPRecord;
  vColor:rgbColor;
  ArgInt:integer;
  FN,ArgFN:string;
  c:char;

begin
  FN:='temp.bmp';
  w:=1024 ;h:=768;  samps := 16;
  c:=#0;modelid:=0;
  repeat
    c:=getopt('m:o:s:w:');

    case c of
      'm' : begin
        ArgInt:=StrToInt(OptArg);
        modelid:=ArgInt;
        if modelid>5 then modelid:=0;
        writeln('model id =',ModelID);
      end;
      'o' : begin
         ArgFN:=OptArg;
         if ArgFN<>'' then FN:=ArgFN;
         writeln ('Output FileName =',FN);
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
      '?',':' : begin
         writeln(' -m [Model ID] id (0..5)');
         writeln(' -o [finename] output filename');
         writeln(' -s [samps] sampling count');
         writeln(' -w [width] screen width pixel');
      end;
    end; { case }
  until c=endofoptions;
  height:=h;
  BMP.new(w,h);

  Randomize;

  case modelID of
    0:InitScene;
    1:InitNEScene;
    2:SkyScene;
    3:ForestScene;
    4:WadaScene;
    5:RandomScene;
  end;      
  

  cam.new( camPosition.new(50, 52, 295.6),
           camDirection.new(0, -0.042612, -1).norm,
           w,h);
  writeln ('The time is : ',TimeToStr(Time));

  for y := 0 to h-1 do begin
    if y mod 10 =0 then writeln('y=',y);
    for x := 0 to w - 1 do begin
      r:=ZeroVec;
      tColor:=ZeroVec;
      for sy := 0 to 1 do begin
        for sx := 0 to 1 do begin
          for s := 0 to samps - 1 do begin
            temp:=radiance_ne(cam.GetRay(x,y,sx,sy), 0,1);
            temp:= temp/ samps;
            r:= r+temp;
          end;(*samps*)
          temp:= ClampVector(r)* 0.25;
          tColor:=tColor+ temp;
          r:=ZeroVec;
        end;(*sx*)
      end;(*sy*)
      vColor:=ColToRGB(tColor);
      BMP.SetPixel(x,height-y-1,vColor);
    end;(* for x *)
  end;(*for y*)
  writeln ('The time is : ',TimeToStr(Time));
  BMP.WriteBMPFile(FN);
end.
