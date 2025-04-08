program smallpt;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

uses SysUtils,Classes,uVect,uDetector,uScene,uBMP,Math,getopts;

const 
  eps=1e-4;
  INF=1e20;
  M_2PI=PI*2;
  M_1_PI=1/PI;
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


function radiance_light(r:RayRecord;depth:integer):Vec3;
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
writeln('Depth=',depth);
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
        tr:=SufInfo.l*nl;
        if tr<0 then tr:=0;
        EL:=EL+f.Mult(radiance_light(ray2.new(x,SufInfo.l),depth) )*tr*SufInfo.Omega;
        //光源が複数ある場合、分岐が爆発する。なんとかしないと・・・
      end;(*for*)
      result:=obj.e+EL*0.5+f.mult(radiance(Ray2.new(x,d),depth))*0.5;
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
  w,h,samps,height,modelid: integer;
  temp       : Vec3;
  tColor,r,camPosition,camDirection : Vec3;
  cam:CamRecord;
  BMP:BMPRecord;
  vColor:rgbColor;
  ArgInt:integer;
  FN,ArgFN:string;
  c:char;
  StartDateTime:TDateTime;
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
        if modelid>7 then modelid:=0;
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
    6:RectLightScene;
    7:testScene;
    8:RectCornelScene;
    else InitScene;
  end;      
  
  writeln('w x h=',w,' x ',h);
  writeln('sampling=',samps);
  writeln('Model =',ModelID);
  writeln('Output FileName=',FN);
  cam.new( camPosition.new(50, 52, 295.6),
           camDirection.new(0, -0.042612, -1).norm,
           w,h);
  //debug
//  cam.o.x:=cam.o.x+50;
  writeln ('The time is : ',TimeToStr(Time));
  StartDateTime:=Time;
  for y := 0 to h-1 do begin
    if y mod 10 =0 then writeln('y=',y);
    for x := 0 to w - 1 do begin
      r:=ZeroVec;
      tColor:=ZeroVec;
      for sy := 0 to 1 do begin
        for sx := 0 to 1 do begin
          for s := 0 to samps - 1 do begin
            temp:=radiance_light(cam.GetRay(x,y,sx,sy), 0);
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
  writeln('The time is : ',TimeToStr(Time));
  writeln('elapsed time : ',TimeToStr(Time-StartDateTime) );

  if UpperCase(ExtractFileExt(FN))='.BMP' then
    BMP.WriteBMPFile(FN)
  else if UpperCase(ExtractFileExt(FN))='.PNG' then
    BMP.WritePNG(FN)
  else
    BMP.WritePPM(FN);
end.
