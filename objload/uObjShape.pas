unit uObjShape;

{$MODE objfpc}{$H+}
{$INLINE ON}
{$modeswitch advancedrecords}

interface
uses SysUtils,Classes,uVect,uBMP,Math,getopts,uMaterial,uShape;

type
  PolygonClass = class(ShapeClass)
     v0, v1, v2, n: Vec3;
     constructor Create(const v0_, v1_, v2_, n_, e_, c_: Vec3; refl_:RefType); reintroduce;
     function intersect(const r:RayRecord):InterInfo;override;
     function GetNorm(x:Vec3):Vec3;override;
     procedure dump;
  end;

procedure LoadObjFile(FN:string;Shapes:TList);

implementation

constructor PolygonClass.Create(const v0_, v1_, v2_, n_, e_, c_: Vec3; refl_: RefType);
var
   BoundMax,BoundMin:Vec3;
begin
   inherited create(zeroVec,e_,c_,refl_);
   v0 := v0_; v1 := v1_; v2 := v2_; 
   
   // 指定された法線がゼロベクトルの場合は自動計算するフォールバック処理
   if (n_.x = 0) and (n_.y = 0) and (n_.z = 0) then
      n := ((v1 - v0) / (v2 - v0)).Norm
   else
      n := n_.Norm;

   BoundBox.new(BoundMin.new(math.min(v0.x,math.min(v1.x,v2.x))-eps,
                             math.min(v0.y,math.min(v1.y,v2.y))-eps,
                             math.min(v0.z,math.min(v1.z,v2.z))-eps ),
                BoundMax.new(math.max(v0.x,math.max(v1.x,v2.x))+eps,
                             math.max(v0.y,math.max(v1.y,v2.y))+eps,
                             math.max(v0.z,math.max(v1.z,v2.z))+eps ));
   
end;

function PolygonClass.intersect(const r:RayRecord):InterInfo;
var
   edge1, edge2, tvec, pvec, qvec: Vec3;
   det, inv_det, t, u, v: real;
begin
   Result.t := INF;
   
   edge1 := v1 - v0; edge2 := v2 - v0;
   pvec := r.d / edge2;
   det := edge1.Dot(pvec);
   if Abs(det) < 1e-8 then Exit;
   inv_det := 1.0 / det;
   
   tvec := r.o - v0;
   u := tvec.Dot(pvec) * inv_det;
   if (u < 0.0) or (u > 1.0) then Exit;
   
   qvec := tvec / edge1;
   v := r.d.Dot(qvec) * inv_det;
   if (v < 0.0) or (u + v > 1.0) then Exit;
   
   t := edge2.Dot(qvec) * inv_det;
   if t > 1e-4 then  Result.t := t;
end;

function PolygonClass.GetNorm(x:Vec3):Vec3;
begin
   result:=n;
end;

procedure PolygonClass.dump;
  procedure WriteVec(v:Vec3);
  begin
     write('@',v.x:8:3,':',v.y:8:3,':',v.z:8:3);
  end;
begin
  write('V0,V1,V2,n');
  writeVec(v0);  writeVec(v1);  writeVec(v2);  writeVec(n);
  writeln;
end;


procedure LoadObjFile(FN:string;Shapes:TList);
  // fトークンから要素（v/vt/vn）を安全に分解抽出するヘルパー関数
  procedure ParseFaceToken(token: string; var vIdx, nIdx: Integer);
  var
    p1, p2: Integer;
    vStr, nStr: string;
  begin
    vIdx := 0; nIdx := 0;
    p1 := Pos('/', token);
    if p1 = 0 then begin
      vIdx := StrToInt(token);
      exit;
    end;
    vStr := Copy(token, 1, p1 - 1);
    if vStr <> '' then vIdx := StrToInt(vStr);
    
    Delete(token, 1, p1);
    p2 := Pos('/', token);
    if p2 = 0 then exit; // vnなし (v/vt のケース)
    
    // v//vn または v/vt/vn のケースにおける vn の抽出
    nStr := Copy(token, p2 + 1, MaxInt);
    if nStr <> '' then nIdx := StrToInt(nStr);
  end;

var
  f: TextFile;
  line, token, mtlFile: string;
  vertices: array of Vec3;
  normals: array of Vec3;
  vCount, nCount: Integer;
  x, y, z: Double;
  t1, t2, t3: string;
  p1, p2, p3, n1, n2, n3: Integer;
  dummy: Integer;
  mRefl: RefType;
  mColor: Vec3;
  polyN: Vec3;
  poly: PolygonClass;
begin
  if Not(Assigned(Shapes) ) then writeln('Shapes is not assigned!!');
  vCount := 0; nCount := 0; mRefl := DIFF; mColor.new(0.8, 0.8, 0.8);
  mtlFile := ChangeFileExt(FN, '.mtl');
  
  if FileExists(mtlFile) then begin
    AssignFile(f, mtlFile); Reset(f);
    while not Eof(f) do begin
      Readln(f, line); line := Trim(line);
      if line = '' then Continue;
      token := Copy(line, 1, Pos(' ', line + ' ') - 1);
      if token = 'Kd' then begin
        line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
        x := StrToFloat(Copy(line, 1, Pos(' ', line + ' ') - 1));
        line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
        y := StrToFloat(Copy(line, 1, Pos(' ', line + ' ') - 1));
        z := StrToFloat(Trim(Copy(line, Pos(' ', line) + 1, MaxInt)));
        mColor.New(x, y, z);
      end
      else if token = 'illum' then begin
        dummy := StrToIntDef(Trim(Copy(line, Pos(' ', line) + 1, MaxInt)), 0);
        if dummy >= 3 then mRefl := SPEC;
      end;
    end;
    CloseFile(f);
  end;

  if not FileExists(FN) then Exit;
  
  AssignFile(f, FN); Reset(f);
  while not Eof(f) do begin
    Readln(f, line); line := Trim(line);
    if line = '' then Continue;
    token := Copy(line, 1, Pos(' ', line + ' ') - 1);
    
    // 頂点座標の読み込み
    if token = 'v' then begin
      line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
      x := StrToFloat(Copy(line, 1, Pos(' ', line + ' ') - 1));
      line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
      y := StrToFloat(Copy(line, 1, Pos(' ', line + ' ') - 1));
      z := StrToFloat(Trim(Copy(line, Pos(' ', line) + 1, MaxInt)));
      
      Inc(vCount); SetLength(vertices, vCount);
      vertices[vCount - 1].new(x, y, z);
    end
    // 法線ベクトル (vn) の読み込み対応
    else if token = 'vn' then begin
      line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
      x := StrToFloat(Copy(line, 1, Pos(' ', line + ' ') - 1));
      line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
      y := StrToFloat(Copy(line, 1, Pos(' ', line + ' ') - 1));
      z := StrToFloat(Trim(Copy(line, Pos(' ', line) + 1, MaxInt)));
      
      Inc(nCount); SetLength(normals, nCount);
      normals[nCount - 1].New(x, y, z);
    end
    // 面情報の読み込み
    else if token = 'f' then begin
      line := Trim(Copy(line, Pos(' ', line) + 1, MaxInt));
      t1 := Copy(line, 1, Pos(' ', line + ' ') - 1);
      line := Trim(Copy(line, Pos(' ', line + ' ') + 1, MaxInt));
      t2 := Copy(line, 1, Pos(' ', line + ' ') - 1);
      t3 := Trim(Copy(line, Pos(' ', line + ' ') + 1, MaxInt));
      
      ParseFaceToken(t1, p1, n1);
      ParseFaceToken(t2, p2, n2);
      ParseFaceToken(t3, p3, n3);
      
      // 法線(vn)データが存在する場合はそのインデックスから割り当て(代表して1番目の頂点の法線を採用)
      if (n1 > 0) and (n1 <= nCount) then
        polyN := normals[n1 - 1]
      else
        polyN.New(0, 0, 0); // Create内で自動的に計算させる
        
      poly := PolygonClass.Create(vertices[p1 - 1],
                                  vertices[p2 - 1],
                                  vertices[p3 - 1],
                                  polyN, ZeroVec, mColor, mRefl);
      Shapes.Add(poly);
      Poly.dump;
    end;
  end;
  CloseFile(f);
   Writeln(Format('Loaded OBJ: %d vertices, %d normals.', [vCount, nCount]));
end;

begin
end.

