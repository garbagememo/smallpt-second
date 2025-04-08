program smallpt;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

uses SysUtils,Classes,uVect,uDetector,uScene,uBMP,Math,getopts;

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
    else begin
      initScene;
      ModelID:=0;
    end;
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
            temp:=radiance_ne_rev(cam.GetRay(x,y,sx,sy), 0,1);
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
