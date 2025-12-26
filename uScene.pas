unit uScene;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uShape;

procedure InitScene;
procedure InitNEScene;
procedure SkyScene;
procedure ForestScene;
procedure WadaScene;
procedure RandomScene;
procedure SpiralScene;
  


implementation
procedure InitScene;
var
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),  ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
  sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6), ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
  sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),      ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
  sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170),  ZeroVec,c.new(0,0,0),      DIFF) );//Front
  sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),     ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
  sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
  sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999, SPEC) );//Mirror
  sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999, REFR) );//Glass
  sph.add( SphereClass.Create(600, p.new(50,681.6-0.27,81.6),e.new(12,12,12),    ZeroVec,DIFF) );//Ligth
end;

procedure InitNEScene;
var
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),  ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
  sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6), ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
  sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),      ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
  sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170+eps),ZeroVec,ZeroVec            ,DIFF) );//Front
  sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),     ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
  sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
  sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999,   SPEC) );//Mirror
  sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999,   REFR) );//Glass
  sph.add( SphereClass.Create( 1.5,p.new(50,81.6-16.5,81.6), e.new(4,4,4)*100,   ZeroVec,  DIFF) );//Ligth

end;

procedure RandomScene;
var
   Cen,Cen1,Cen2,Cen3:Vec3;
   a,b:integer;
   RandomMatterial:real;
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  Cen.new(50,40.8,-860);

  Cen1.new(75,25, 85);
  Cen2.new(45,25, 30);
  Cen3.new(15,25,-25);
  

  sph.add(SphereClass.Create(10000,  Cen+p.new(0,0,-200)  , e.new(0.6, 0.5, 0.7)*0.8, c.new(0.7,0.9,1.0),  DIFF)); // sky
  sph.add(SphereClass.Create(100000, p.new(50, -100000, 0), ZeroVec,                  c.new(0.4,0.4,0.4),  DIFF)); // grnd


  sph.add(SphereClass.Create(25,  Cen1 ,ZeroVec,c.new(0.9,0.9,0.9), SPEC));// Glas
  sph.add(SphereClass.Create(25,  Cen2 ,ZeroVec,c.new(0.95,0.95,0.95),  REFR)); // Glass
  sph.add(SphereClass.Create(25,  Cen3 ,ZeroVec,c.new(1,0.6,0.6)*0.696, DIFF));    // 乱反射
  for a:=-11 to 11 do begin
     for b:=-11 to 11 do begin
        RandomMatterial:=random;
        Cen.new( (a+random)*25,5,(b+random)*25);
        if ( (Cen - Cen1) ).len>25*1.0 then begin
           if RandomMatterial<0.8 then begin
              sph.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),DIFF));
           end
           else if RandomMatterial <0.95 then begin
              sph.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),SPEC));
           end
           else begin
              sph.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),REFR));
           end;
        end;
     end;
  end;
end;

procedure SkyScene;
var
   Cen,p,e,c:Vec3;
begin
  sph:=TList.Create;
  Cen.new(50,40.8,-860);

  sph.add(SphereClass.Create(1600,      p.new(1,0,2)*3000,   e.new(1,0.9,0.8)*1.2e1*1.56*2,  ZeroVec, DIFF)); // sun
  sph.add(SphereClass.Create(1560,      p.new(1,0,2)*3500,   e.new(1,0.5,0.05)*4.8e1*1.56*2, ZeroVec,  DIFF) ); // horizon sun2
  sph.add(SphereClass.Create(10000, Cen+p.new(0,0,-200),     e.new(0.00063842, 0.02001478, 0.28923243)*6e-2*8, c.new(0.7,0.7,1)*0.25,  DIFF)); // sky

  sph.add(SphereClass.Create(100000,    p.new(50, -100000, 0),ZeroVec,c.new(0.3,0.3,0.3),DIFF)); // grnd
  sph.add(SphereClass.Create(110000,    p.new(50, -110048.5, 0),e.new(0.9,0.5,0.05)*4,ZeroVec,DIFF));// horizon brightener
  sph.add(SphereClass.Create(4e4,       p.new(50, -4e4-30, -3000),ZeroVec,c.new(0.2,0.2,0.2),DIFF));// mountains

  sph.add(SphereClass.Create(26.5,p.new(22,26.5,42),ZeroVec,c.new(1,1,1)*0.596, SPEC)); // white Mirr
  sph.add(SphereClass.Create(13,p.new(75,13,82),ZeroVec,c.new(0.96,0.96,0.96)*0.96, REFR));// Glas
  sph.add(SphereClass.Create(22,p.new(87,22,24),ZeroVec,c.new(0.6,0.6,0.6)*0.696, REFR));    // Glas2
end;

procedure ForestScene;
var
   tc,scc,p,e,c:Vec3;
begin
  sph:=TList.Create;

  tc:=tc.new(0.0588, 0.361, 0.0941);
  scc:=scc.new(1,1,1)*0.7;
  sph.add(SphereClass.Create(1e5, p.new(50, 1e5+130, 0),  e.new(1,1,1)*1.3,ZeroVec,DIFF)); //lite
  sph.add(SphereClass.Create(1e2, p.new(50, -1e2+2, 47),  ZeroVec,c.new(1,1,1)*0.7,DIFF)); //grnd

  sph.add(SphereClass.Create(1e4, p.new(50, -30, 300)+e.new(-sin(50*PI/180), 0, cos(50*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr L
  sph.add(SphereClass.Create(1e4, p.new(50, -30, 300)+e.new(sin(50*PI/180),  0, cos(50*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr R
  sph.add(SphereClass.Create(1e4, p.new(50, -30, -50)+e.new(-sin(30*PI/180), 0,-cos(30*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr FL
  sph.add(SphereClass.Create(1e4, p.new(50, -30, -50)+e.new(sin(30*PI/180),  0,-cos(30*PI/180))*1e4, ZeroVec, c.new(1,1,1)*0.99,SPEC));// mirr


  sph.add(SphereClass.Create(4, p.new(50,6*0.6,47),                         ZeroVec, c.new(0.13,0.066,0.033), DIFF));//"tree"
  sph.add(SphereClass.Create(16,p.new(50,6*2+16*0.6,47),                    ZeroVec, tc,  DIFF));//"tree"
  sph.add(SphereClass.Create(11,p.new(50,6*2+16*0.6*2+11*0.6,47),           ZeroVec, tc,  DIFF));//"tree"
  sph.add(SphereClass.Create(7, p.new(50,6*2+16*0.6*2+11*0.6*2+7*0.6,47),   ZeroVec, tc,  DIFF));//"tree"

  sph.add(SphereClass.Create(15.5,p.new(50,1.8+6*2+16*0.6,47),              ZeroVec, scc,  DIFF));//"tree"
  sph.add(SphereClass.Create(10.5,p.new(50,1.8+6*2+16*0.6*2+11*0.6,47),     ZeroVec, scc,  DIFF));//"tree"
  sph.add(SphereClass.Create(6.5, p.new(50,1.8+6*2+16*0.6*2+11*0.6*2+7*0.6,47), ZeroVec, scc,  DIFF));//"tree"

end;

procedure wadaScene;
var
   R,T,D,Z:real;
   p,c,e:Vec3;
begin
  sph:=TList.Create;

  R:=60;
  //double R=120;
  T:=30*PI/180.;
  D:=R/cos(T);
  Z:=60;

  sph.add(SphereClass.Create(1e5, p.new(50, 100, 0),      e.new(1,1,1)*3e0, ZeroVec           , DIFF)); // sky
  sph.add(SphereClass.Create(1e5, p.new(50, -1e5-D-R, 0), ZeroVec,          c.new(0.1,0.1,0.1),DIFF));           //grnd

  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new( cos(T),sin(T),0)*D, ZeroVec, c.new(1,0.3,0.3)*0.999, SPEC)); //red
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(-cos(T),sin(T),0)*D, ZeroVec, c.new(0.3,1,0.3)*0.999, SPEC)); //grn
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(0,-1,0)*D,           ZeroVec, c.new(0.3,0.3,1)*0.999, SPEC)); //blue
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(0,0,-1)*D,           ZeroVec, c.new(0.53,0.53,0.53)*0.999, SPEC)); //back
  sph.add(SphereClass.Create(R, p.new(50,40.8,62)+e.new(0,0,1)*D,            ZeroVec, c.new(1,1,1)*0.999, REFR)); //front
end;

procedure SpiralScene;
var
   Cen,Cen1,Cen2,Cen3:Vec3;
   n:integer;
   r,theta:real;
   a,b:real;
   RandomMatterial:real;
   p,c,e:Vec3;
begin
  sph:=TList.Create;
  Cen.new(50,40.8,-860);

  a:=15;b:=0.15;theta:=pi/6;
  Cen2.new(0,0,0);

  sph.add(SphereClass.Create(10000,Cen+p.new(0,0,-200), e.new(0.6, 0.5, 0.7)*0.8, c.new(0.7,0.9,1.0),  DIFF)); // sky
  sph.add(SphereClass.Create(100000, p.new(50, -100000, 0), ZeroVec, c.new(0.4,0.4,0.4),  DIFF)); // grnd

  for n:=0 to 18 do begin
     theta:=pi/6*(3+n);
     r:=a*Exp(b*theta);
     cen1:=cen2+cen1.new(r*cos(theta),5,r*sin(-theta) );//zは手前が＋なのでマイナスしないといけない
     sph.add(SphereClass.Create(5,Cen1,ZeroVec,c.new(random,Random,random),DIFF));
  end;
end;


begin
end.
