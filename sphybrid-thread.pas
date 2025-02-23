program sppthread;
{$mode objfpc}
{$modeswitch advancedrecords}

uses
  {$ifdef unix}
  cthreads,cmem,
  {$endif}
  SysUtils,Classes,Math,uVect,uBMP,getopts,uDetector,uHybrid,uScene;

const
   MaxThread=32;
var
  BMP:BMPrecord;

type
   CamRecord=record
      o,d:Vec3;
      PlaneDist:real;
      w,h,samps:integer;
      cx,cy:Vec3;
      function new(o_,d_:Vec3;w_,h_,samps_:integer):CamRecord;
      function GetRay(x,y,sx,sy:integer):RayRecord;
   end;

   //スタックサイズが不定を嫌ってdynamic arrayは使わない
   LineArray=array[0..255*255] of rgbColor;

   TMyThread = class(TThread)
      wide,hight,samps:integer;//render option
      y,yInc:integer;
      Line:LineArray;
      cam:CamRecord;
      HybridBVH:HybridBVHClass;
      function radiance(const r:RayRecord;depth:integer;E:integer):Vec3;
      procedure Execute; override;
      procedure AddAxis;
   end;

function CamRecord.new(o_,d_:Vec3;w_,h_,samps_:integer):CamRecord;
begin
  o:=o_;d:=d_;w:=w_;h:=h_;samps:=samps_;
  cx.new(w * 0.5135 / h, 0, 0);
  cy:= (cx/ d).norm* 0.5135;
  PlaneDist:=140;
  result:=self;
end;

function CamRecord.GetRay(x,y,sx,sy:integer):RayRecord;
var
   r1,r2,dx,dy,temp:real;
   dirct:Vec3;
begin
   r1 := 2 * random;
   if (r1 < 1) then
      dx := sqrt(r1) - 1
   else
      dx := 1 - sqrt(2 - r1);
   r2 := 2 * random;
   if (r2 < 1) then
      dy := sqrt(r2) - 1
   else
      dy := 1 - sqrt(2 - r2);
   dirct:= cy* (((sy + 0.5 + dy) / 2 + (h - y - 1)) / h - 0.5)
      +cx* (((sx + 0.5 + dx) / 2 + x) / w - 0.5)
      +d;
   dirct:=dirct.norm;
   result.o:= dirct* PlaneDist+o;
   result.d := dirct;
end;

function TMyThread.radiance(const r:RayRecord;depth:integer;E:integer):Vec3;
var
  i,tid,id:integer;
  obj,s:DetectorClass;
  x,n,f,nl,u,v,w,d:Vec3;
  p,r1,r2,r2s,t:real;
  into:boolean;
  ray2,RefRay:RayRecord;
  nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
  tDir:Vec3;
  ir:InterRecord;
  EL:Vec3;
  SufInfo:SurfaceInfo;
  uvw:Vec3Matrix;
begin
  ir.id:=0;depth:=depth+1;
  ir:=HybridBVH.intersect(r);
  if ir.isHit=false then begin
    result:=ZeroVec;exit;
  end;
  obj:=DetectorClass(sph[ir.id]);
  x:=r.o+r.d*ir.t; f:=obj.c;
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
      result:=obj.e*E+EL+f.Mult(self.radiance(ray2.new(x,d),depth,0) );
    end;(*DIFF*)
    SPEC:begin
      result:=obj.e+f.Mult((self.radiance(ray2.new(x,r.d-n*2*(n*r.d) ),depth,1)));
    end;(*SPEC*)
    REFR:begin
      RefRay.new(x,r.d-n*2*(n*r.d) );
      into:= (n*nl>0);
      nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl;
      cos2t:=1-nnt*nnt*(1-ddn*ddn);
      if cos2t<0 then begin   // Total internal reflection
        result:=obj.e + f.Mult(self.radiance(RefRay,depth,1));
        exit;
      end;
      if into then q:=1 else q:=-1;
      tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
      if into then Q:=-ddn else Q:=tdir*n;
      a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
      Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);
      if depth>2 then begin
        if random<p then // 反射
          result:=obj.e+f.Mult(self.radiance(RefRay,depth,1)*RP)
        else //屈折
          result:=obj.e+f.Mult(self.radiance(ray2.new(x,tdir),depth,1)*TP);
      end
      else begin// 屈折と反射の両方を追跡
        result:=obj.e+f.Mult(self.radiance(RefRay,depth,1)*Re + self.radiance(ray2.new(x,tdir),depth,1)*Tr);
      end;
    end;(*REFR*)
  end;(*CASE*)
end;


procedure TMyThread.Execute;
var
  x,sx,sy,s:integer;
  r,tColor:Vec3;
begin
  while y<hight do begin
    if y mod 10 =0 then writeln('y=',y);
    for x := 0 to wide - 1 do begin
      tColor:=ZeroVec;
      for sy := 0 to 1 do begin
        for sx := 0 to 1 do begin
          r:=ZeroVec;
          for s := 0 to cam.samps - 1 do begin
            r:= r+radiance(cam.GetRay(x,y,sx,sy), 0,1)/ cam.samps;
          end;(*samps*)
          tColor:=tColor+ ClampVector(r)* 0.25;
        end;(*sx*)
      end;(*sy*)
      Line[x]:=ColToRGB(tColor);
    end;(* for x *)
    Synchronize(@AddAxis);
  end;(*for y*)
end;

procedure TMyThread.AddAxis;
var
  j:integer;
  yAxis:integer;
begin
  yAxis:=hight-y-1;
  for j:=0 to wide-1 do BMP.SetPixel(j,yAxis,line[j]);
  y:=y+yInc;
end;

var
  i: integer;
  w,h,samps: integer;
  modelnum,threadnum:integer;
  camPosition,camDirection : Vec3;
  cam:CamRecord;
  ArgInt:integer;
  FN,ArgFN:string;
  c:char;
  StarTime:TDateTime;
var
  ary:IntegerArray;
  HybridBVH:HybridBVHClass;
  ThreadAry:array[0..MaxThread-1] of TMyThread;
begin
   ThreadNum:=8;
   modelnum:=0;
   FN:='temp.bmp';
   w:=640 ;h:=480;  samps := 16;
   c:=#0;
   repeat
     c:=getopt('m:o:s:t:w:');
     case c of
       'm' : begin
          ArgInt:=StrToInt(OptArg);
          modelnum:=ArgInt;
          writeln ('model number=',ModelNum);
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
       't' : begin
         ArgInt:=StrToInt(OptArg);
         ThreadNum:=ArgInt;
         if ThreadNum>=MaxThread then Threadnum:=MaxThread;
         writeln('Thread Number =',ThreadNum);
       end;
      'w' : begin
         ArgInt:=StrToInt(OptArg);
         w:=ArgInt;h:=w *3 div 4;
         writeln('w=',w,' ,h=',h);
      end;
      '?',':' : begin
         writeln(' -m [0..5] scene number');
         writeln(' -o [finename] output filename');
         writeln(' -s [samps] sampling count');
         writeln(' -t [thread num]');
         writeln(' -w [width] screen width pixel');
         halt;
      end;
    end; { case }
  until c=endofoptions;

  writeln('samps=',samps);
  writeln('size=',w,'x',h);
  writeln('model=',modelnum);
  writeln('threads=',threadnum);
  writeln('output=',FN);
  BMP.new(w,h);
  Randomize;
  cam.new(camPosition.new(50, 52, 295.6),camDirection.new(0, -0.042612, -1).norm,w,h,samps );
  case modelnum of
     7:testScene;
     6:RectLightScene;
     5:RandomScene;
     4:WadaScene;
     3:ForestScene;
     2:SkyScene;
     1:InitNEScene;
     else begin
        InitScene;
     end;
  end;(*case*)

  HybridBVH:=HybridBVHClass.Create(cam.o);

  writeln ('The time is : ',TimeToStr(Time));
  StarTime:=Time;
  BMP.new(cam.w,cam.h);
  for i:=0 to ThreadNum-1 do begin
     ThreadAry[i]:=TMyThread.Create(true);
     ThreadAry[i].FreeOnTerminate:=false;
     //falseにしないとスレッドが休止時の後始末ができない。
     ThreadAry[i].y:=i;
     ThreadAry[i].wide:=cam.w;
     ThreadAry[i].hight:=cam.h;
     ThreadAry[i].cam:=cam;
     ThreadAry[i].samps:=samps;
     ThreadAry[i].HybridBVH:=HybridBVH;
     ThreadAry[i].yInc:=ThreadNum;
  end;
  writeln('Setup!');

  for i:=0 to ThreadNum-1 do begin
    ThreadAry[i].Start;
  end;
  //このルーチンが別途で無いとマルチスレッドにならない
  for i:=0 to ThreadNum-1 do begin
    ThreadAry[i].WaitFor;
  end;
  writeln('The time is : ',TimeToStr(Time));
  writeln('Calcurate time is=',TimeToStr(Time-StarTime));
  if UpperCase(ExtractFileExt(FN))='.BMP' then
    BMP.WriteBMPFile(FN)
  else if UpperCase(ExtractFileExt(FN))='.PNG' then
    BMP.WritePNG(FN)
  else
    BMP.WritePPM(FN);
end.

