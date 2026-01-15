unit uMaterial;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts;

type
   TraceInfo=record
      cpc:real;//反射・屈折pdf
      r:RayRecord;
   end;
   
   MaterialClass=class
      function GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;virtual;abstract;
   end;
   DiffuseClass=Class(MaterialClass)
      function GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;override;
   end;
   MirrorClass=Class(MaterialClass)
      function GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;override;
   end;
   RefractClass=Class(MaterialClass)
      function GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;override;
   end;
      
implementation

function DiffuseClass.GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;
var
   r1,r2,r2s:real;
   u,v,w,d:Vec3;
   ray2:RayRecord;
begin
   r1:=2*PI*random;r2:=random;r2s:=sqrt(r2);
   w:=nl;
   if abs(w.x)>0.1 then
      u:=(u.new(0,1,0)/w).norm 
   else begin
      u:=(u.new(1,0,0)/w ).norm;
   end;
   v:=w/u;
   d := (u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrt(1-r2)).norm;
   result.r:=ray2.new(x,d);
   result.cpc:=1.0;
end;

function MirrorClass.GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;
var
   ray2:RayRecord;
begin
   result.r:=ray2.new(x,r.d-n*2*(n*r.d) );
   result.cpc:=1.0;
end;

function RefractClass.GetRay(r:RayRecord;x,n,nl:Vec3):TraceInfo;
var
   ray2,RefRay:RayRecord;
   into:boolean;
   nc,nt,nnt,ddn,cos2t,q,a,b,c,R0,Re,RP,Tr,TP:real;
   tDir:Vec3;
   p:real;
begin
   RefRay.new(x,r.d-n*2*(n*r.d) );
   into:= (n*nl>0);
   nc:=1;nt:=1.5; if into then nnt:=nc/nt else nnt:=nt/nc; ddn:=r.d*nl; 
   cos2t:=1-nnt*nnt*(1-ddn*ddn);
   if cos2t<0 then begin   // Total internal reflection
      result.r:=RefRay;
      result.cpc:=1.0;
      exit;
   end;
   if into then q:=1 else q:=-1;
   tdir := (r.d*nnt - n*(q*(ddn*nnt+sqrt(cos2t)))).norm;
   if into then Q:=-ddn else Q:=tdir*n;
   a:=nt-nc; b:=nt+nc; R0:=a*a/(b*b); c := 1-Q;
   Re:=R0+(1-R0)*c*c*c*c*c;Tr:=1-Re;P:=0.25+0.5*Re;RP:=Re/P;TP:=Tr/(1-P);

   if random<p then begin// 反射
      result.r:=RefRay;
      result.cpc:=RP;
   end
   else begin //屈折
      result.r:=ray2.new(x,tdir);
      result.cpc:=TP;
   end;
end;
end.
