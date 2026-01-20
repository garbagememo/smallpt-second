unit uBVH;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses uVect,uShape,Math,Classes;
const
  Nil_Leaf=16384;
type
  IntegerArray=array of integer;

  BVHNodeClass=Class
    root:AABBRecord;
    left,right:BVHNodeClass;
    leaf:integer;
    constructor Create(ary:IntegerArray;sph:TList);
    function intersect(r:RayRecord;sph:TList):HitInfo;
  end;

procedure AABBSort(var a: array of integer;sph:TList);
   
implementation


function GetAABBVal(suf:integer;axis:integer;sph:TList):real;
begin
  case axis of
    1:result:=ShapeClass(sph[suf]).BoundBox.min.x;
    2:result:=ShapeClass(sph[suf]).BoundBox.min.y;
    else begin
      result:=ShapeClass(sph[suf]).BoundBox.min.z;
    end;
  end ;(*case*)
end;

procedure AABBSort(var a: array of integer;sph:TList);//バブルソート
var
   i, j, h,axis: integer;
   ar:real;
begin
   ar:=random;
   if ar<0.33 then axis:=1 else if ar<0.67 then axis:=2 else axis:=3;
   for i := 0 to High(a) do begin
       for j := 1 to High(a) - i  do begin
           if GetAABBVal(a[j],axis,sph) < GetAABBVal(a[j-1],axis,sph) then begin
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
   AABBSort(ary,sph);
   Leaf:=Nil_Leaf;
   root:=ShapeClass(sph[ary[0]]).BoundBox;
    
  case High(Ary) of
    0:Leaf:=ary[0];//要素1
    1:begin
       Root:=Root.MargeBoundBox(ShapeClass(sph[ary[1] ]).BoundBox);
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


function BVHnodeClass.intersect(r:RayRecord;sph:TList):HitInfo;
var
   RIR,LIR:HitInfo;
   Info:InterInfo;
begin
   result.isHit:=false;
   result.t:=INF;
   result.id:=0;
   if leaf<>Nil_Leaf then begin
      Info:=ShapeClass(sph[leaf]).intersect(r);
      result.t:=Info.t;
      if result.t<INF then begin
         result.id:=Leaf;
         result.isHit:=true;
         result.FaceID:=Info.FaceID;
      end;
      exit;
   end;

   if root.Hit(r,EPS,INF) then begin
      RIR:=Right.intersect(r,sph);
      LIR:=Left.intersect(r,sph);
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
