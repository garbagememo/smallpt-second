unit uVect;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface

uses
    sysutils,uBMP,math;
type
    RefType=(DIFF,SPEC,REFR);// material types, used in radiance()
{
	DIFFUSE,    // 完全拡散面。いわゆるLambertian面。
	SPECULAR,   // 理想的な鏡面。
	REFRACTION, // 理想的なガラス的物質。
}
    Vec3=record
        x,y,z:real;
        function new(x_,y_,z_:real):Vec3;
        function Norm:Vec3;inline;
        function len:real;inline;
        function Dot(const V2 :Vec3):real;inline;//内積
        function Cross(const V2 :Vec3):Vec3;inline;//外積
        function Mult(const V2:Vec3):Vec3;inline;
        function Neg:Vec3;
    end;
    RayRecord=record
       o, d:Vec3;
       function new(o_,d_:Vec3):RayRecord;
      end;

  InterRecord=record
     isHit:boolean;
     t:real;
     id:integer;
  end;

   function ClampVector(v:Vec3):Vec3;
   function ColToRGB(v:Vec3):rgbColor;
const
   BackGroundColor:Vec3 = (x:0;y:0;z:0);
   ZeroVec:Vec3 = (x:0;y:0;z:0);
   

function VecAdd3(V1,V2,V3:Vec3):Vec3;
procedure VecWriteln(V:Vec3);

operator * (const v1:Vec3;const r:real)v:Vec3;inline;
operator / (const v1:Vec3;const r:real)v:Vec3;inline;
operator * (const v1,v2:Vec3)r:real;inline;//内積
operator / (const v1,v2:Vec3)v:Vec3;inline;//外積

operator + (const v1,v2:Vec3)v:Vec3;inline;
operator - (const v1,v2:Vec3)v:Vec3;inline;
operator + (const v1:Vec3;const r:real)v:Vec3;inline;
operator - (const v1:Vec3;const r:real)v:Vec3;inline;

implementation

function Vec3.new(x_,y_,z_:real):Vec3;inline;
begin
   x:=x_;y:=y_;z:=z_;
   result:=self;
end;

function Vec3.Norm:Vec3;inline;
var
   l:real;
begin
   result:=self/len;
end;

function Vec3.len:real;inline;
begin
   result:=sqrt(x*x+y*y+z*z);
end;

function Vec3.Dot(const V2 :Vec3):real;inline;//内積
begin
    result:=x*v2.x+y*v2.y+z*v2.z;
end;

function Vec3.Cross(const V2 :Vec3):Vec3;inline;//外積
begin
    result.x:=y * v2.z - v2.y * z;
    result.y:=z * v2.x - v2.z * x;
    result.z:=x * v2.y - v2.x * y;
end;

function Vec3.Mult(const V2:Vec3):Vec3;inline;
begin
    result.x:=x*V2.x;
    result.y:=y*V2.y;
    result.z:=z*V2.z;
end;

function Vec3.Neg:Vec3;
begin
    result.x:=-x;
    result.y:=-y;
    result.z:=-z;
end;

function RayRecord.new(o_,d_:Vec3):RayRecord;
begin
   o:=o_;
   d:=d_;
   result:=self;
end;

function VecAdd3(V1,V2,V3:Vec3):Vec3;
begin
    result.x:=V1.x+V2.x+V3.x;
    result.y:=V1.y+V2.y+V3.y;
    result.z:=V1.z+V2.z+V3.z;
    
end;

procedure VecWriteln(V:Vec3);
begin
    writeln(v.x,':',v.y,':',v.z);
end;


operator * (const v1:Vec3;const r:real)v:Vec3;inline;
begin
   v.x:=v1.x*r;
   v.y:=v1.y*r;
   v.z:=v1.z*r;
end;

operator / (const v1:Vec3;const r:real)v:Vec3;inline;
begin
   v.x:=v1.x/r;
   v.y:=v1.y/r;
   v.z:=v1.z/r;
end;

operator * (const v1,v2:Vec3)r:real;inline;//内積
begin
   r:=v1.x*v2.x+v1.y*v2.y+v1.z*v2.z;
end;

operator / (const v1,v2:Vec3)v:Vec3;inline; //外積
begin
    v.x:=V1.y * v2.z - v2.y * V1.z;
    v.y:=V1.z * v2.x - v2.z * V1.x;
    v.z:=V1.x * v2.y - v2.x * V1.y;
end;

operator + (const v1,v2:Vec3)v:Vec3;inline;
begin
   v.x:=v1.x+v2.x;
   v.y:=v1.y+v2.y;
   v.z:=v1.z+v2.z;
end;

operator - (const v1,v2:Vec3)v:Vec3;inline;
begin
    v.x:=v1.x-v2.x;
    v.y:=v1.y-v2.y;
    v.z:=v1.z-v2.z;
end;

operator + (const v1:Vec3;const r:real)v:Vec3;inline;
begin
   v.x:=v1.x+r;
   v.y:=v1.y+r;
   v.z:=v1.z+r;
end;
operator - (const v1:Vec3;const r:real)v:Vec3;inline;
begin
    v.x:=v1.x-r;
    v.y:=v1.y-r;
    v.z:=v1.z-r;
end;


function Clamp(x:real):real;inline;
begin
   if x<0 then exit(0);
   if x>1 then exit(1);
   exit(x);
end;

function ClampVector(v:Vec3):Vec3;
begin
  result.x:=clamp(v.x);
  result.y:=clamp(v.y);
  result.z:=clamp(v.z);
end;
function ColToByte(x:real):byte;inline;
begin
    result:=trunc(power(x,1/2.2)*255+0.5);
end;
function ColToRGB(v:Vec3):rgbColor;
begin
    result.r:=ColToByte(v.x);
    result.g:=ColToByte(v.y);
    result.b:=ColToByte(v.z);
end;

begin
end.
   
