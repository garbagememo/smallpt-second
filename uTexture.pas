unit uTexture;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts;

type

   TextureClass=class
      e,c:Vec3;
      constructor create(e_,c_:Vec3);virtual;
      function GetEmit(x:Vec3):Vec3;virtual;
      function GetColor(x:Vec3):Vec3;virtual;
   end;

implementation

constructor TextureClass.create(e_,c_:Vec3);
begin
   e:=e_;c:=c_;
end;

function TextureClass.GetEmit(x:Vec3):Vec3;
begin
   result:=e;
end;

function TextureClass.GetColor(x:Vec3):Vec3;
begin
   result:=c;
end;


end.
