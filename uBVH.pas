unit uBVH;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses uVect,uDetector,Math,Classes;
const
  Nil_Leaf=16384;
type
  IntegerArray=array of integer;

  BVHNodeClass=Class
    root:AABBRecord;
    left,right:BVHNodeClass;
    leaf:integer;
    constructor Create(ary:IntegerArray;sph:TList);
    function intersect(r:RayRecord):InterRecord;
  end;

procedure AABBSort(var a: array of integer);
   
implementation


function GetAABBVal(suf:integer;axis:integer):real;
begin
  case axis of
    1:result:=DetectorClass(sph[suf]).BoundBox.min.x;
    2:result:=DetectorClass(sph[suf]).BoundBox.min.y;
    else begin
      result:=DetectorClass(sph[suf]).BoundBox.min.z;
    end;
  end ;(*case*)
end;

procedure AABBSort(var a: array of integer);//バブルソート
var
   i, j, h,axis: integer;
   ar:real;
begin
   ar:=random;
   if ar<0.33 then axis:=1 else if ar<0.67 then axis:=2 else axis:=3;
   for i := 0 to High(a) do begin
       for j := 1 to High(a) - i  do begin
           if GetAABBVal(a[j],axis) < GetAABBVal(a[j-1],axis) then begin
             h:=a[j-1];a[j-1]:=a[j];a[j]:=h;
         end;
       end;
  end;
end;

constructor BVHnodeClass.Create(ary:IntegerArray;sph:TList);
var
   upAry,DownAry:IntegerArray;
   i,len:integer;
begin
   AABBSort(ary);
   Leaf:=Nil_Leaf;
   root:=Detectorclass(sph[ary[0]]).BoundBox;
    
  case High(Ary) of
    0:Leaf:=ary[0];//要素1
    1:begin
       Root:=Root.MargeBoundBox(DetectorClass(sph[ary[1] ]).BoundBox);
       setLength(UpAry,1);
       SetLength(downAry,1);
       upAry[0]:=Ary[0];
       DownAry[0]:=Ary[1];
       Left:=BVHNodeClass.Create(upAry,sph);
       right:=BVHNodeClass.Create(DownAry,sph);
    end;
    else begin
      for i:=1 to high(ary)  do begin
        Root:=Root.MargeBoundBox(SphereClass(sph[ary[i] ]).BoundBox);
      end;
      len:=length(Ary) div 2;
      upAry:=Copy(Ary,0,len);
      DownAry:=Copy(Ary,len,length(Ary)-len);
       
      Left:=BVHNodeClass.Create(UpAry,sph);
      right:=BVHNodeClass.Create(DownAry,sph);
    end;
  end;
end;


function BVHnodeClass.intersect(r:RayRecord):InterRecord;
var
   RIR,LIR:InterRecord;
   t:real;
begin
  result.isHit:=false;
  result.t:=INF;
  result.id:=0;
  if leaf<>Nil_Leaf then begin
    result.t:=DetectorClass(sph[leaf]).intersect(r);
    if result.t<INF then begin
      result.id:=Leaf;
      result.isHit:=true;
    end;
    exit;
  end;

  if root.Hit(r,EPS,INF) then begin
     RIR:=Right.intersect(r);
     LIR:=Left.intersect(r);
     if (LIR.isHit or RIR.isHit) then begin
        if RIR.isHit then result:=RIR;
        if LIR.isHit then begin
           if RIR.isHit=false then
              result:=LIR
           else if RIR.t>LIR.t then
              result:=LIR;
        end;
     end;
  end
  else begin
    result.isHit:=false;
    result.t:=INF;
  end;
end;

begin
end.
