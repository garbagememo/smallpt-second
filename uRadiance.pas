unit uRadiance;
{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uShape,uBVH,uPolygon;

type
   ShapeListClass=Class
      shapes:TList;
      constructor create;
      procedure add(s : ShapeClass);
      function intersect(const r: RayRecord):HitInfo;virtual;
      function GetObj(id:integer):ShapeClass;virtual;
   end;
   
   BVHSceneClass = class(ShapeListClass)
      bvh:BVHNodeClass;
      function intersect(const r:RayRecord):HitInfo;override;
      procedure MakeBVHNode;
   end;
   

   SceneRecord = record
      scList:TList;//List of SceneListClass
      procedure new;
      procedure InitScene;
      procedure InitNEScene;
      procedure SkyScene;
      procedure ForestScene;
      procedure WadaScene;
      procedure RandomScene;
      procedure SpiralScene;
      procedure IslandScene;
      procedure RectLightScene;
      procedure BVHRandomScene;
      procedure EvenlySpiralScene;
      procedure RectAngleScene;
      function Radiance(const r:RayRecord;depth:integer):Vec3;
   end;

   var
      sc:SceneRecord;
implementation
constructor ShapeListClass.create;
begin
   Shapes:=TList.Create;
end;
procedure ShapeListClass.add(s: ShapeClass);
begin
   Shapes.add(s);
end;

function ShapeListClass.intersect(const r:RayRecord):HitInfo;
var 
  t,d:real;
  i,id,FaceID:integer;
  Info:InterInfo;
begin
   result.isHit:=false;
   result.t:=INF;
   t:=INF;
   id:=Shapes.count-1;
   for i:=0 to Shapes.count-1 do begin
      Info:=ShapeClass(Shapes[i]).intersect(r);
      d:=Info.t;
      if d < t then begin
         t:=d;
         id:=i;
         FaceID:=Info.FaceID;
      end;
   end;
   result.isHit:=(t<inf);
   if result.isHit then begin
      result.t:=t;
      result.id:=id;
      result.FaceID:=FaceID;
   end;
end;

function ShapeListClass.GetObj(id:integer):ShapeClass;
begin
   result:=ShapeClass(shapes[id]);
end;

function BVHSceneClass.intersect(const r:RayRecord):HitInfo;
begin
   result.obj:=nil;
   result:=bvh.intersect(r,shapes);
   if result.isHit then result.obj:=GetObj(result.id);
end;

procedure BVHSceneClass.MakeBVHNode;
var
   ary:array of integer;
   i:integer;
begin
   SetLength(ary,shapes.count);
   writeln('bvh sph.count=',shapes.count);
   for i:=0 to shapes.count-1 do ary[i]:=i;
   bvh:=BVHNodeClass.Create(ary,shapes);
end;

procedure SceneRecord.new;
begin
   scList:=TList.create;
end;

function SceneRecord.Radiance(const r:RayRecord;depth:integer):Vec3;
var
   f,d,x,n,nl:Vec3;
   p:real;
   hit,hit2:HitInfo;
   tInfo:TraceInfo;
   i:integer;
begin
   depth:=depth+1;
   hit.isHit:=false;hit.t:=INF;
   i:=0;
   while i<sc.scList.count do begin
      hit2:=ShapeListClass(sc.scList[i]).intersect(r);
      if hit2.isHit then begin
         if hit.t>hit2.t then begin
            hit:=hit2;
            hit.obj:=ShapeListClass(sc.scList[i]).GetObj(hit.id);
         end;
      end;
      i:=i+1;
   end;
   if hit.isHit=false then begin
      result:=ZeroVec;exit;
   end;
   x:=r.o+r.d*hit.t;
   n:=hit.obj.GetNorm(x,hit.FaceID);
   if n.dot(r.d)<0 then nl:=n else nl:=n*-1;
   f := hit.obj.tx.getColor(x);
   p:=Max(f.x,Max(f.y,f.z));
   if (depth>5) then begin
      if random<p then 
         f:=f/p 
      else
         Exit(hit.obj.tx.GetEmit(x));
   end;
   tInfo := hit.obj.m.GetRay(r,x,n,nl);
   result:=hit.obj.tx.GetEmit(x)+f.Mult(Radiance(tInfo.r,depth))*tInfo.cpc;
end;


procedure SceneRecord.InitScene;
var
   p,c,e:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
   sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),  ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
   sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6), ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
   sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),      ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
   sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170),  ZeroVec,c.new(0,0,0),      DIFF) );//Front
   sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),     ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
   sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
   sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999, SPEC) );//Mirror
   sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999, REFR) );//Glass
   sph.add( SphereClass.Create(600, p.new(50,681.6-0.27,81.6),e.new(12,12,12),    ZeroVec,DIFF) );//Ligth
   scList.add(sph);
end;

procedure SceneRecord.InitNEScene;
var
   p,c,e:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
   sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),  ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
   sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6), ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
   sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),      ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
   sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170+eps),ZeroVec,ZeroVec            ,DIFF) );//Front
   sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),     ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
   sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
   sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999,   SPEC) );//Mirror
   sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999,   REFR) );//Glass
   sph.add( SphereClass.Create( 1.5,p.new(50,81.6-16.5,81.6), e.new(4,4,4)*100,   ZeroVec,  DIFF) );//Ligth
   scList.add(sph);
end;

procedure SceneRecord.RandomScene;
var
   Cen,Cen1,Cen2,Cen3:Vec3;
   a,b:integer;
   RandomMatterial:real;
   p,c,e:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
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
   scList.add(sph);
end;

procedure SceneRecord.SkyScene;
var
   Cen,p,e,c:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
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
   scList.add(sph);
end;

procedure SceneRecord.ForestScene;
var
   tc,scc,p,e,c:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;

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
   scList.add(sph);

end;

procedure SceneRecord.wadaScene;
var
   R,T,D,Z:real;
   p,c,e:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;

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
   scList.add(sph);
end;

procedure SceneRecord.IslandScene;
var
   p,c,e:Vec3;
   Cen:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
   Cen.new(50,-20,-860);
   Sph.add(SphereClass.Create(160, Cen+p.new(0, 600, -500),e.new(1,1,1)*2e2, ZeroVec,  DIFF)); // sun
   Sph.add(SphereClass.Create(800, Cen+p.new(0,-880,-9120),e.new(1,1,1)*2e1, ZeroVec,  DIFF)); // horizon
   Sph.add(SphereClass.Create(10000,Cen+p.new(0,0,-200), e.new(0.0627, 0.188, 0.569)*1e0, c.new(1,1,1)*0.4,  DIFF)); // sky
   Sph.add(SphereClass.Create(800, Cen+p.new(0,-720,-200),ZeroVec,  c.new(0.110, 0.898, 1.00)*0.996,  REFR)); // water
   Sph.add(SphereClass.Create(790, Cen+p.new(0,-720,-200),ZeroVec,  c.new(0.4,0.3,0.04)*0.6, DIFF)); // earth
   Sph.add(SphereClass.Create(325, Cen+p.new(0,-255,-50), ZeroVec,  c.new(0.4,0.3,0.04)*0.8, DIFF)); // island
   sph.add(SphereClass.Create(275, Cen+p.new(0,-205,-33), ZeroVec,  c.new(0.02,0.3,0.02)*0.75,DIFF)); // grass
   scList.add(sph);
end;

procedure SceneRecord.RectLightScene;
var
   p,c,e:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
   sph.add( RectClass.Create(YZ, 0, 81.6, 0, 170, p.new( 1,0,0),    ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
   sph.add( RectClass.Create(YZ, 0, 81.6, 0, 170, p.new(99,0,0),    ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
   sph.add( RectClass.Create(XY, 1,   99, 0,81.6, p.new( 1,0,0),    ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
   sph.add( RectClass.Create(XY, 1,   99, 0,81.6, p.new( 1,0,170),  ZeroVec,c.new(0,0,0),      DIFF) );//Front
   sph.add( RectClass.Create(XZ, 1,   99, 0,170,  p.new( 1,0,0),    ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
   sph.add( RectClass.Create(XZ, 1,   99, 0,170,  p.new( 1,81.6,0), ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
   sph.add( SphereClass.Create(16.5,p.new(27,16.5,47),        ZeroVec,c.new(1,1,1)*0.999, SPEC) );//Mirror
   sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),        ZeroVec,c.new(1,1,1)*0.999, REFR) );//Glass
   sph.add( RectClass.Create(XZ,40,60,70,90,p.new(50,70,80),  e.new(4,4,4)*3,   ZeroVec,  DIFF)  );//Ligth
   scList.add(sph);
end;


procedure SceneRecord.SpiralScene;
var
   Cen,Cen1,Cen2,LB,RT:Vec3;
   n:integer;
   r,theta:real;
   RandomMatterial:real;
   p,c,e:Vec3;
   sph:ShapeListClass;
   bvh:BVHSceneClass;
   //等間隔計算用
   a,b,x,y:real;
   L: real;
   numPoints, i: Integer;
   s_start, s_current: real;
   constPart: real;
   radius:real;
   ArcLength:real;
begin
   sph:=ShapeListClass.create;
   sph.add(PolygonClass.Create(cen.new(0,0,0),cen1.new(30,30,-30),cen2.new(-30,30,-30),e.new(1,0.5,0.2),ZeroVec,SPEC));//light
   Cen.new(50,40.8,-860);

   Cen2.new(0,0,0);

   sph.add(SphereClass.Create(10000,Cen+p.new(0,0,-200), e.new(0.6, 0.5, 0.7)*0.1, c.new(0.7,0.9,1.0),  DIFF)); // sky
   sph.add(SphereClass.Create(100000, p.new(50, -100000, 0), ZeroVec, c.new(0.4,0.4,0.4),  DIFF)); // grnd


   radius:=4;//玉の半径
   ArcLength:=radius*3;//弧長
   // --- パラメータ設定 ---
   a := 15.0;     // 係数
   b := 0.15;     // 螺旋の広がり具合
   L := ArcLength;     // 点と点の間の弧長（距離）
   
   // 弧長公式の一部を定数として計算しておく
   // constPart = (a * sqrt(1 + b^2)) / b
   constPart := (a * Sqrt(1 + Power(b, 2))) / b;

   // 開始地点の弧長を計算（例：theta = 0 のとき）
   // s = constPart * exp(b * theta)
   s_start := constPart * Exp(b * pi/2);

   i:=0;theta:=0;
   bvh:=BVHSceneClass.Create;
   while theta<3.5*pi do begin
      // 現在の弧長
      s_current := s_start + (i * L);

      // 1. 弧長から角度 theta を逆算
      // theta = (1/b) * ln(s / constPart)
      theta := (1 / b) * Ln(s_current / constPart);
      if theta>3.5*pi then break;

      // 2. 極座標から動径 r を計算
      r := a * Exp(b * theta);

      // 3. 直交座標 (x, y) に変換
      x := r * Cos(theta);
      y := r * Sin(theta);
      cen1:=cen2+cen1.new(x,radius,-y);
      bvh.add(SphereClass.Create(radius,Cen1,ZeroVec,c.new(random,random,random),DIFF));
      inc(i);
   end;

   scList.add(sph);
   bvh.MakeBVHNode;
   scList.add(bvh);

end;

procedure SceneRecord.EvenlySpiralScene;
var
   Cen,Cen1,Cen2,Cen3:Vec3;
   n:integer;
   r,theta:real;
   RandomMatterial:real;
   p,c,e:Vec3;
   sph:ShapeListClass;
   bvh:BVHSceneClass;
   //等間隔計算用
   a,b,x,y:real;
   L: real;
   i: Integer;
   s_start, s_current: real;
   constPart: real;
   radius:real;
   ArcLength:real;
begin
   sph:=ShapeListClass.create;
   Cen.new(50,40.8,-860);

   Cen2.new(0,0,0);

   sph.add(SphereClass.Create(10000,Cen+p.new(0,0,-200), e.new(0.6, 0.5, 0.7)*0.8, c.new(0.7,0.9,1.0),  DIFF)); // sky
   sph.add(SphereClass.Create(100000, p.new(50, -100000, 0), ZeroVec, c.new(0.4,0.4,0.4),  DIFF)); // grnd


   radius:=4;//玉の半径
   ArcLength:=radius*3;//弧長
   // --- パラメータ設定 ---
   a := 15.0;     // 係数
   b := 0.15;     // 螺旋の広がり具合
   L := ArcLength;     // 点と点の間の弧長（距離）
   
   // 弧長公式の一部を定数として計算しておく
   // constPart = (a * sqrt(1 + b^2)) / b
   constPart := (a * Sqrt(1 + Power(b, 2))) / b;

   // 開始地点の弧長を計算（例：theta = 0 のとき）
   // s = constPart * exp(b * theta)
   s_start := constPart * Exp(b * pi/2);

   i:=0;theta:=0;
   bvh:=BVHSceneClass.Create;
   while theta<3.5*pi do begin
      // 現在の弧長
      s_current := s_start + (i * L);

      // 1. 弧長から角度 theta を逆算
      // theta = (1/b) * ln(s / constPart)
      theta := (1 / b) * Ln(s_current / constPart);
      if theta>3.5*pi then break;

      // 2. 極座標から動径 r を計算
      r := a * Exp(b * theta);

      // 3. 直交座標 (x, y) に変換
      x := r * Cos(theta);
      y := r * Sin(theta);
      cen1:=cen2+cen1.new(x,radius,-y);
      bvh.add(SphereClass.Create(radius,Cen1,ZeroVec,c.new(random,random,random),DIFF));
      inc(i);
   end;

   scList.add(sph);
   bvh.MakeBVHNode;
   scList.add(bvh);
end;


procedure SceneRecord.BVHRandomScene;
var
   Cen,Cen1,Cen2,Cen3:Vec3;
   a,b:integer;
   RandomMatterial:real;
   p,c,e:Vec3;
   sph:ShapeListClass;
   bvh:BVHSceneClass;
begin
   sph:=ShapeListClass.create;
   Cen.new(50,40.8,-860);

   Cen1.new(75,25, 85);
   Cen2.new(45,25, 30);
   Cen3.new(15,25,-25);
   

   sph.add(SphereClass.Create(10000,  Cen+p.new(0,0,-200)  , e.new(0.6, 0.5, 0.7)*0.8, c.new(0.7,0.9,1.0),  DIFF)); // sky
   sph.add(SphereClass.Create(100000, p.new(50, -100000, 0), ZeroVec,                  c.new(0.4,0.4,0.4),  DIFF)); // grnd


   sph.add(SphereClass.Create(25,  Cen1 ,ZeroVec,c.new(0.9,0.9,0.9), SPEC));// Glas
   sph.add(SphereClass.Create(25,  Cen2 ,ZeroVec,c.new(0.95,0.95,0.95),  REFR)); // Glass
   sph.add(SphereClass.Create(25,  Cen3 ,ZeroVec,c.new(1,0.6,0.6)*0.696, DIFF));    // 乱反射

   bvh:=BVHSceneClass.Create;
   for a:=-11 to 11 do begin
      for b:=-11 to 11 do begin
         RandomMatterial:=random;
         Cen.new( (a+random)*25,5,(b+random)*25);
         if ( (Cen - Cen1) ).len>25*1.0 then begin
            if RandomMatterial<0.8 then begin
               bvh.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),DIFF));
            end
            else if RandomMatterial <0.95 then begin
               bvh.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),SPEC));
            end
            else begin
               bvh.add(SphereClass.Create(5,Cen,ZeroVec,c.new(random,Random,random),REFR));
            end;
         end;
      end;
   end;
   bvh.MakeBVHNode;
   scList.add(sph);
   scList.add(bvh);
end;

procedure SceneRecord.RectAngleScene;
var
   p,c,e:Vec3;
   LB,RT:Vec3;
   sph:ShapeListClass;
begin
   sph:=ShapeListClass.create;
   sph.add( SphereClass.Create(1e5, p.new( 1e5+1,40.8,81.6),    ZeroVec,c.new(0.75,0.25,0.25),DIFF) );//Left
   sph.add( SphereClass.Create(1e5, p.new(-1e5+99,40.8,81.6),   ZeroVec,c.new(0.25,0.25,0.75),DIFF) );//Right
   sph.add( SphereClass.Create(1e5, p.new(50,40.8, 1e5),        ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Back
   sph.add( SphereClass.Create(1e5, p.new(50,40.8,-1e5+170+eps),ZeroVec,c.new(0,0,0)       ,DIFF) );//Front
   sph.add( SphereClass.Create(1e5, p.new(50, 1e5, 81.6),       ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Bottomm
   sph.add( SphereClass.Create(1e5, p.new(50,-1e5+81.6,81.6),   ZeroVec,c.new(0.75,0.75,0.75),DIFF) );//Top
   sph.add( SphereClass.Create(16.5,p.new(73,16.5,88),          ZeroVec,c.new(0.9,0.7,0.8),   REFR) );//Glass
   sph.add( RectAngleClass.Create(LB.new(10,0,30),RT.new(40,35,60),ZeroVec,c.new(0.4,0.8,0.6),SPEC) );//Rect Mirror
   sph.add( RectAngleClass.Create(LB.new(38,68,58),RT.new(62,72,82), e.new(4,4,4)*3,   ZeroVec,  DIFF) );//Ligth
   scList.add(sph);
end;

begin
end.
