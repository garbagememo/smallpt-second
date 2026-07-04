program CornellRaytracer;

{$mode objfpc}{$H+}{$COPERATORS ON}

uses
  SysUtils, Classes, Math;

type
  Vec3 = record
    x, y, z: real;
  end;

  refl = (DIFF, SPEC, REFR);

  RayRecord = record 
    r: Vec3; (*視点の方向*)
    x: Vec3; (*視点の座標*)
  end;

// --- 演算子オーバーロードの定義 ---

operator + (const a, b: Vec3): Vec3; inline;
begin
  result.x := a.x + b.x; result.y := a.y + b.y; result.z := a.z + b.z;
end;

operator - (const a, b: Vec3): Vec3; inline;
begin
  result.x := a.x - b.x; result.y := a.y - b.y; result.z := a.z - b.z;
end;

// Vec3 * Vec3 は内積
operator * (const a, b: Vec3): real; inline;
begin
  result := a.x * b.x + a.y * b.y + a.z * b.z;
end;

// Vec3 / Vec3 は外積
operator / (const a, b: Vec3): Vec3; inline;
begin
  result.x := a.y * b.z - a.z * b.y;
  result.y := a.z * b.x - a.x * b.z;
  result.z := a.x * b.y - a.y * b.x;
end;

// 補助演算子（スカラー倍）
operator * (const a: Vec3; const b: real): Vec3; inline;
begin
  result.x := a.x * b; result.y := a.y * b; result.z := a.z * b;
end;

operator * (const a: real; const b: Vec3): Vec3; inline;
begin
  result.x := a * b.x; result.y := a * b.y; result.z := a * b.z;
end;

function NewVec3(cx, cy, cz: real): Vec3; inline;
begin
  result.x := cx; result.y := cy; result.z := cz;
end;

function ColorMul(const a, b: Vec3): Vec3; inline;
begin
  result.x := a.x * b.x;
  result.y := a.y * b.y;
  result.z := a.z * b.z;
end;

type
  PolygonClass = class
    v: array[0..2] of Vec3;    (*頂点座標*)
    vn: array[0..2] of Vec3;   (*頂点の法線座標*)
    c: Vec3;                   (*ポリゴンの色*)
    e: Vec3;                   (*発光の強度*)
    ref: refl;                 (*ポリゴンのマテリアルタイプ*)
    constructor create(v_, vn_: array of Vec3; c_, e_: Vec3; ref_: refl);
    function intersect(r: RayRecord): real;    (*Rayを与えた時の交点を返す*)
    function GetNorm(pt: Vec3): Vec3;          (*交点を与えてその法線を得る*)
  end;

// --- PolygonClass の実装 ---

constructor PolygonClass.create(v_, vn_: array of Vec3; c_, e_: Vec3; ref_: refl);
var
  i: Integer;
begin
  for i := 0 to 2 do begin
    v[i] := v_[i];
    vn[i] := vn_[i];
  end;
  c := c_;
  e := e_;
  ref := ref_;
end;

function PolygonClass.intersect(r: RayRecord): real;
var
  e1, e2, pvec, tvec, qvec: Vec3;
  det, inv_det, u, val_v, t: real;
const
  EPS = 1e-6;
begin
  result := 1e20; // 交差しない場合は十分に大きな値を返す
  e1 := v[1] - v[0];
  e2 := v[2] - v[0];
  
  pvec := r.r / e2;  // 外積演算子を使用
  det := e1 * pvec;  // 内積演算子を使用
  
  if (det > -EPS) and (det < EPS) then exit;
  inv_det := 1.0 / det;
  
  tvec := r.x - v[0];
  u := (tvec * pvec) * inv_det;
  if (u < 0.0) or (u > 1.0) then exit;
  
  qvec := tvec / e1; // 外積演算子を使用
  val_v := (r.r * qvec) * inv_det;
  if (val_v < 0.0) or (u + val_v > 1.0) then exit;
  
  t := (e2 * qvec) * inv_det;
  if t > EPS then result := t;
end;

function PolygonClass.GetNorm(pt: Vec3): Vec3;
var
  v0, v1, v2: Vec3;
  d00, d01, d11, d20, d21, denom, u, val_v, w, len: real;
  n: Vec3;
begin
  v0 := v[1] - v[0];
  v1 := v[2] - v[0];
  v2 := pt - v[0];
  
  d00 := v0 * v0;
  d01 := v0 * v1;
  d11 := v1 * v1;
  d20 := v2 * v0;
  d21 := v2 * v1;
  
  denom := d00 * d11 - d01 * d01;
  if Abs(denom) < 1e-8 then begin
    // 三角形が潰れているなどの例外時は幾何法線を返す
    n := v0 / v1;
    len := Sqrt(n * n);
    if len > 0 then result := n * (1.0 / len) else result := n;
    exit;
  end;
  
  val_v := (d11 * d20 - d01 * d21) / denom;
  w := (d00 * d21 - d01 * d20) / denom;
  u := 1.0 - val_v - w;
  
  // 頂点法線を重心座標で補間
  n := (vn[0] * u) + (vn[1] * val_v) + (vn[2] * w);
  len := Sqrt(n * n);
  if len > 0 then result := n * (1.0 / len) else result := n;
end;

// --- グローバル変数とデータ管理 ---

const
  WIDTH = 320;
  HEIGHT = 240;

var
  Vertices: array of Vec3;
  Normals: array of Vec3;
  Polygons: array of PolygonClass;
  Image: array[0..WIDTH-1, 0..HEIGHT-1] of Vec3;

// 連続する空白に対応した文字列分割ヘルパー
function SplitSpace(const s: string): TStringList;
var
  i: Integer;
  w: string;
begin
  result := TStringList.Create;
  w := '';
  for i := 1 to Length(s) do begin
    if s[i] = ' ' then begin
      if w <> '' then begin
        result.Add(w);
        w := '';
      end;
    end else begin
      w := w + s[i];
    end;
  end;
  if w <> '' then result.Add(w);
end;

// コーネルボックスのObjファイル内部生成
procedure CreateCornellObjFile(const filename: string);
var
  f: TextFile;
begin
  AssignFile(f, filename);
  Rewrite(f);
  // 部屋の全体外殻頂点 (1..8)
  Writeln(f, 'v 0 0 0');     Writeln(f, 'v 50 0 0');
  Writeln(f, 'v 50 50 0');   Writeln(f, 'v 0 50 0');
  Writeln(f, 'v 0 0 50');    Writeln(f, 'v 50 0 50');
  Writeln(f, 'v 50 50 50');  Writeln(f, 'v 0 50 50');
  // 天井のライト頂点 (9..12)
  Writeln(f, 'v 20 49.9 20'); Writeln(f, 'v 30 49.9 20');
  Writeln(f, 'v 30 49.9 30'); Writeln(f, 'v 20 49.9 30');
  // 手前左のトールボックス (SPEC: 鏡面構造) 頂点 (13..20)
  Writeln(f, 'v 12 0 12');    Writeln(f, 'v 26 0 12');
  Writeln(f, 'v 26 0 26');    Writeln(f, 'v 12 0 26');
  Writeln(f, 'v 12 30 12');   Writeln(f, 'v 26 30 12');
  Writeln(f, 'v 26 30 26');   Writeln(f, 'v 12 30 26');
  // 奥右のショートボックス (REFR: 透明ガラス構造) 頂点 (21..28)
  Writeln(f, 'v 24 0 24');    Writeln(f, 'v 38 0 24');
  Writeln(f, 'v 38 0 38');    Writeln(f, 'v 24 0 38');
  Writeln(f, 'v 24 16 24');   Writeln(f, 'v 38 16 24');
  Writeln(f, 'v 38 16 38');   Writeln(f, 'v 24 16 38');

  // 代表法線（壁面パース用）
  Writeln(f, 'vn 0 0 1');   Writeln(f, 'vn 1 0 0');
  Writeln(f, 'vn -1 0 0');  Writeln(f, 'vn 0 1 0');
  Writeln(f, 'vn 0 -1 0');

  // オブジェクト名（'o '）を利用して擬似的にマテリアルを切り替える
  Writeln(f, 'o left');     Writeln(f, 'f 1//2 5//2 8//2'); Writeln(f, 'f 1//2 8//2 4//2');
  Writeln(f, 'o right');    Writeln(f, 'f 6//3 2//3 3//3'); Writeln(f, 'f 6//3 3//3 7//3');
  Writeln(f, 'o light');    Writeln(f, 'f 9//5 10//5 11//5'); Writeln(f, 'f 9//5 11//5 12//5');
  Writeln(f, 'o white');    Writeln(f, 'f 1//4 2//4 6//4'); Writeln(f, 'f 1//4 6//4 5//4'); // 床
  Writeln(f, 'o white');    Writeln(f, 'f 4//5 7//5 3//5'); Writeln(f, 'f 4//5 8//5 7//5'); // 天井
  Writeln(f, 'o white');    Writeln(f, 'f 5//1 6//1 7//1'); Writeln(f, 'f 5//1 7//1 8//1'); // 奥壁

  Writeln(f, 'o mirror');   // SPEC
  Writeln(f, 'f 13 14 18'); Writeln(f, 'f 13 18 17'); Writeln(f, 'f 14 15 19'); Writeln(f, 'f 14 19 18');
  Writeln(f, 'f 15 16 20'); Writeln(f, 'f 15 20 19'); Writeln(f, 'f 16 13 17'); Writeln(f, 'f 16 17 20');
  Writeln(f, 'f 17 18 19'); Writeln(f, 'f 17 19 20');

  Writeln(f, 'o glass');    // REFR
  Writeln(f, 'f 21 22 26'); Writeln(f, 'f 21 26 25'); Writeln(f, 'f 22 23 27'); Writeln(f, 'f 22 27 26');
  Writeln(f, 'f 23 24 28'); Writeln(f, 'f 23 28 27'); Writeln(f, 'f 24 21 25'); Writeln(f, 'f 24 25 28');
  Writeln(f, 'f 25 26 27'); Writeln(f, 'f 25 27 28');
  CloseFile(f);
end;

// Objファイルのロード処理
procedure LoadObjFile(const filename: string);
var
  f: TextFile;
  line: string;
  tokens: TStringList;
  cC, cE: Vec3;
  cRef: refl;

  procedure ProcessFace(const t1, t2, t3: string);
  var
    vIdx, nIdx: array[0..2] of Integer;
    i, p: Integer;
    s: string;
    fV, fVN: array[0..2] of Vec3;
    geomN: Vec3;
    len: real;
  begin
    for i := 0 to 2 do begin
      if i = 0 then s := t1 else if i = 1 then s := t2 else s := t3;
      p := Pos('/', s);
      if p > 0 then begin
        vIdx[i] := StrToInt(Copy(s, 1, p - 1));
        nIdx[i] := StrToInt(Copy(s, p + 2, MaxInt)); // 「//」を跨ぐ簡易処理
      end else begin
        vIdx[i] := StrToInt(s);
        nIdx[i] := 0;
      end;
    end;

    for i := 0 to 2 do begin
      fV[i] := Vertices[vIdx[i] - 1];
      if nIdx[i] > 0 then fVN[i] := Normals[nIdx[i] - 1] else fVN[i] := NewVec3(0, 0, 0);
    end;

    // 法線がない場合は面法線を自動割当
    if nIdx[0] = 0 then begin
      geomN := (fV[1] - fV[0]) / (fV[2] - fV[0]);
      len := Sqrt(geomN * geomN);
      if len > 0 then geomN := geomN * (1.0 / len);
      fVN[0] := geomN; fVN[1] := geomN; fVN[2] := geomN;
    end;

    SetLength(Polygons, Length(Polygons) + 1);
    Polygons[Length(Polygons) - 1] := PolygonClass.create(fV, fVN, cC, cE, cRef);
  end;

begin
  cC := NewVec3(0.75, 0.75, 0.75); cE := NewVec3(0, 0, 0); cRef := DIFF;
  AssignFile(f, filename);
  Reset(f);
  while not Eof(f) do begin
    Readln(f, line);
    line := Trim(line);
    if (line = '') or (line[1] = '#') then continue;
    tokens := SplitSpace(line);
    if tokens.Count = 0 then begin tokens.Free; continue; end;

    if tokens[0] = 'v' then begin
      SetLength(Vertices, Length(Vertices) + 1);
      Vertices[Length(Vertices) - 1] := NewVec3(StrToFloat(tokens[1]),
                                                StrToFloat(tokens[2]),
                                                StrToFloat(tokens[3]));
    end else if tokens[0] = 'vn' then begin
      SetLength(Normals, Length(Normals) + 1);
      Normals[Length(Normals) - 1] := NewVec3(StrToFloat(tokens[1]),
                                              StrToFloat(tokens[2]),
                                              StrToFloat(tokens[3]));
    end else if tokens[0] = 'o' then begin
      if tokens[1] = 'left' then begin
        cC := NewVec3(0.75, 0.25, 0.25); cE := NewVec3(0, 0, 0); cRef := DIFF;
      end else if tokens[1] = 'right' then begin
        cC := NewVec3(0.25, 0.25, 0.75); cE := NewVec3(0, 0, 0); cRef := DIFF;
      end else if tokens[1] = 'light' then begin
        cC := NewVec3(0, 0, 0); cE := NewVec3(12, 12, 12); cRef := DIFF;
      end else if tokens[1] = 'white' then begin
        cC := NewVec3(0.75, 0.75, 0.75); cE := NewVec3(0, 0, 0); cRef := DIFF;
      end else if tokens[1] = 'mirror' then begin
        cC := NewVec3(0.99, 0.99, 0.99); cE := NewVec3(0, 0, 0); cRef := SPEC;
      end else if tokens[1] = 'glass' then begin
        cC := NewVec3(0.99, 0.99, 0.99); cE := NewVec3(0, 0, 0); cRef := REFR;
      end;
    end else if tokens[0] = 'f' then begin
      ProcessFace(tokens[1], tokens[2], tokens[3]);
    end;
    tokens.Free;
  end;
  CloseFile(f);
end;

// --- レイトレーシング中核処理 ---

function Trace(const ray: RayRecord; depth: Integer): Vec3;
var
  t, tNear: real;
  hitPoly: PolygonClass;
  i: Integer;
  P, N, color, L, LightPos, R, tDir: Vec3;
  distToLight, dot, nnt, dd, cos2t, nc, nt, a, b, r0, c_val, Re, Tr: real;
  shadowRay, refRay, refrRay: RayRecord;
  inShadow: Boolean;
begin
  result := NewVec3(0, 0, 0);
  if depth > 5 then exit;

  tNear := 1e19;
  hitPoly := nil;

  // 最短交差ポリゴン探索
  for i := 0 to Length(Polygons) - 1 do begin
    t := Polygons[i].intersect(ray);
    if (t > 1e-4) and (t < tNear) then begin
      tNear := t;
      hitPoly := Polygons[i];
    end;
  end;

  if hitPoly = nil then exit;

  P := ray.x + (ray.r * tNear);
  N := hitPoly.GetNorm(P);
  
  // 法線のインサイド・アウトサイド制御
  if (N * ray.r) > 0 then N := N * -1.0;

  color := hitPoly.e; // 自己発光成分

  case hitPoly.ref of
    DIFF: begin
      // 天井ライトの中心を仮想の点光源とする直接光計算
      LightPos := NewVec3(25.0, 49.8, 25.0);
      L := LightPos - P;
      distToLight := Sqrt(L * L);
      L := L * (1.0 / distToLight);

      shadowRay.x := P + (N * 1e-3);
      shadowRay.r := L;
      inShadow := false;

      for i := 0 to Length(Polygons) - 1 do begin
        if Polygons[i].e * Polygons[i].e > 1e-3 then continue; // ライト自身は遮蔽から除外
        t := Polygons[i].intersect(shadowRay);
        if (t > 1e-3) and (t < distToLight - 1e-3) then begin
          inShadow := true;
          break;
        end;
      end;

      dot := N * L;
      if dot < 0 then dot := 0;
      
      // 直接光 + 簡易環境光
      if not inShadow then
        color := color + (hitPoly.c * dot * 2.0) + (hitPoly.c * 0.05)
      else
        color := color + (hitPoly.c * 0.05);
    end;

    SPEC: begin
      R := ray.r - (N * (2.0 * (N * ray.r)));
      refRay.x := P + (N * 1e-3);
      refRay.r := R;
      color := color + ColorMul(hitPoly.c , Trace(refRay, depth + 1));
    end;

    REFR: begin
      R := ray.r - (N * (2.0 * (N * ray.r)));
      refRay.x := P + (N * 1e-3);
      refRay.r := R;

      nc := 1.0; nt := 1.5; // 空気からガラス
      if (N * ray.r) < 0 then nnt := nc / nt else nnt := nt / nc;
      dd := ray.r * N;
      cos2t := 1.0 - nnt * nnt * (1.0 - dd * dd);

      if cos2t < 0 then begin // 全反射
        color := color + Trace(refRay, depth + 1);
      end else begin
        if (ray.r * N) < 0 then
          tDir := (ray.r * nnt) - (N * (dd * nnt + Sqrt(cos2t)))
        else
          tDir := (ray.r * nnt) + (N * (dd * nnt - Sqrt(cos2t)));
        
        tDir := tDir * (1.0 / Sqrt(tDir * tDir));
        refrRay.x := P - (N * 1e-3);
        refrRay.r := tDir;

        // Schlick近似によるフレネル反射率計算
        a := nt - nc; b := nt + nc; r0 := (a * a) / (b * b);
        if (ray.r * N) < 0 then c_val := 1.0 + dd else c_val := 1.0 - (tDir * N);
        Re := r0 + (1.0 - r0) * c_val * c_val * c_val * c_val * c_val;
        Tr := 1.0 - Re;

// カッコ内の「Trace(...) * Re」などは「ベクトル * スカラー」なので元の演算子でOKですが、
// hitPoly.c との掛け算は色同士の積なので ColorMul を使います
        color := color + ColorMul(hitPoly.c, (Trace(refRay, depth + 1) * Re + Trace(refrRay, depth + 1) * Tr));
      end;
    end;
  end;

  result := color;
end;

// レンダリングループ
procedure Render;
var
  x, y: Integer;
  fx, fy: real;
  dir: Vec3;
  ray: RayRecord;
  len: real;
begin
  Write('Rendering...');
  for y := 0 to HEIGHT - 1 do begin
    for x := 0 to WIDTH - 1 do begin
      // スクリーン座標をカメラ空間へ 
      // (箱が画面に綺麗に収まるよう、画角の係数を 0.35 から 0.22 に調整)
      fx := (x - WIDTH / 2.0) / (WIDTH / 2.0) * 0.22;
      fy := -(y - HEIGHT / 2.0) / (HEIGHT / 2.0) * 0.22; // 上下反転
      
      // Zの向きを 1.0 (奥向き) に変更
      dir.x := fx; dir.y := fy; dir.z := 1.0;
      len := Sqrt(dir * dir);
      dir := dir * (1.0 / len);

      // カメラ位置を Z=-65.0 (手前) に変更し、開口部(Z=0)から中を覗き込む
      ray.x := NewVec3(25.0, 25.0, -65.0); 
      ray.r := dir;

      Image[x, y] := Trace(ray, 0);
    end;
    if y mod 20 = 0 then Write('.');
  end;
  Writeln(' Done.');
end;

// PPM画像ファイルとして保存
procedure SavePPM(const filename: string);
var
  f: TextFile;
  x, y, r, g, b: Integer;
  c: Vec3;
begin
  AssignFile(f, filename);
  Rewrite(f);
  Writeln(f, 'P3');
  Writeln(f, WIDTH, ' ', HEIGHT);
  Writeln(f, '255');
  for y := 0 to HEIGHT - 1 do begin
    for x := 0 to WIDTH - 1 do begin
      c := Image[x, y];
      // AnsiClamp を EnsureRange に変更して 0.0 〜 1.0 に収める
      r := EnsureRange(Round(Power(EnsureRange(c.x, 0.0, 1.0), 1.0 / 2.2) * 255), 0, 255);
      g := EnsureRange(Round(Power(EnsureRange(c.y, 0.0, 1.0), 1.0 / 2.2) * 255), 0, 255);
      b := EnsureRange(Round(Power(EnsureRange(c.z, 0.0, 1.0), 1.0 / 2.2) * 255), 0, 255);
      Writeln(f, r, ' ', g, ' ', b);
    end;
  end;
  CloseFile(f);
  Writeln('Saved to ', filename);
end;

var
  i: Integer;
begin
  Writeln('--- FreePascal Obj Raytracer ---');
  CreateCornellObjFile('cornell.obj');
  Writeln('Generated "cornell.obj".');
  
  LoadObjFile('cornell.obj');
  Writeln('Loaded Obj file. Polygons: ', Length(Polygons));

  Render;
  SavePPM('render.ppm');

  // メモリ解放
  for i := 0 to Length(Polygons) - 1 do
    Polygons[i].Free;
end.
