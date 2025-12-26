program sppthread;    
{$mode objfpc}
{$modeswitch advancedrecords}

uses
  {$ifdef unix}
  cthreads,cmem,
  {$endif}
  SysUtils,Classes,Math,uVect,uBMP,getopts,uShape,uScene;

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
      procedure CamWrite;
   end;
   
   //スタックサイズが不定を嫌ってdynamic arrayは使わない
   LineArray=array[0..255*255] of rgbColor;

   TMyThread = class(TThread)
      wide,hight,samps:integer;//render option
      y,yInc:integer;
      Line:LineArray;
      cam:CamRecord;
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

procedure CamRecord.CamWrite;
var
   r:RayRecord;
begin
   write(' o=');VecWriteln(o);
   write(' d=');VecWriteln(d);
   write(' cx=');VecWriteln(cx);
   write(' cy=');VecWriteln(cy);
   writeln('===0,0==');
   r:=GetRay(0,0,0,0);
   write(' r.o=');VecWriteln(r.o);
   write(' r.d=');VecWriteln(r.d);
   writeln('===320,240==');
   r:=GetRay(320,240,0,0);
   write(' r.o=');VecWriteln(r.o);
   write(' r.d=');VecWriteln(r.d);
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
               r:= r+radiance(cam.GetRay(x,y,sx,sy), 0)/ cam.samps;
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
     6:begin
          SpiralScene;
          cam.new(camPosition.new(0,300,400),
                  camDirection.new(0,-300,-400).norm,
                  w,h,samps);
          cam.PlaneDist:=70;
       end;
     5:begin
          RandomScene;
          cam.new(camPosition.new(55,40,295.6),
                  camDirection.new(0,-0.12,-1).norm,
                  w,h,samps);
          cam.PlaneDist:=70;
       end;
     4:WadaScene;
     3:ForestScene;
     2:SkyScene;
     1:InitNEScene;
     else begin
        InitScene;
     end;
  end;(*case*)

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
  
