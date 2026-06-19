program SmallPT_BVH;

{$MODE OBJFPC}
{$COPERATORS ON}

uses
  SysUtils, Math, Classes;

type
  Refl_t = (DIFF, SPEC, REFR);

  Vec = record
    x, y, z: Double;
    constructor Create(x_: Double = 0; y_: Double = 0; z_: Double = 0);
    function Plus(const b: Vec): Vec; inline;
    function Minus(const b: Vec): Vec; inline;
    function Mul(b: Double): Vec; inline;
    function Mult(const b: Vec): Vec; inline;
    function Norm: Vec; inline;
    function Dot(const b: Vec): Double; inline;
    function Cross(const b: Vec): Vec; inline;
  end;

  operator + (const a, b: Vec) r: Vec; inline; begin r := a.Plus(b); end;
  operator - (const a, b: Vec) r: Vec; inline; begin r := a.Minus(b); end;
  operator * (const a: Vec; b: Double) r: Vec; inline; begin r := a.Mul(b); end;
  operator * (b: Double; const a: Vec) r: Vec; inline; begin r := a.Mul(b); end;

constructor Vec.Create(x_: Double; y_: Double; z_: Double); begin x := x_; y := y_; z := z_; end;
function Vec.Plus(const b: Vec): Vec; begin Result.x := x + b.x; Result.y := y + b.y; Result.z := z + b.z; end;
function Vec.Minus(const b: Vec): Vec; begin Result.x := x - b.x; Result.y := y - b.y; Result.z := z - b.z; end;
function Vec.Mul(b: Double): Vec; begin Result.x := x * b; Result.y := y * b; Result.z := z * b; end;
function Vec.Mult(const b: Vec): Vec; begin Result.x := x * b.x; Result.y := y * b.y; Result.z := z * b.z; end;
function Vec.Norm: Vec; var invLen: Double; begin invLen := 1.0 / Sqrt(x*x + y*y + z*z); Result.x := x * invLen; Result.y := y * invLen; Result.z := z * invLen; end;
function Vec.Dot(const b: Vec): Double; begin Result := x * b.x + y * b.y + z * b.z; end;
function Vec.Cross(const b: Vec): Vec; begin Result.x := y * b.z - z * b.y; Result.y := z * b.x - x * b.z; Result.z := x * b.y - y * b.x; end;

type
  Ray = record
    o, d: Vec;
    constructor Create(o_, d_: Vec);
  end;

constructor Ray.Create(o_, d_: Vec); begin o := o_; d := d_; end;

// AABB (軸並行境界ボックス)
  AABB = record
    min, max: Vec;
    procedure Fit(const p: Vec);
    function Intersect(const r: Ray; tMax: Double): Boolean; inline;
  end;

procedure AABB.Fit(const p: Vec);
begin
  if p.x < min.x then min.x := p.x; if p.y < min.y then min.y := p.y; if p.z < min.z then min.z := p.z;
  if p.x > max.x then max.x := p.x; if p.y > max.y then max.y := p.y; if p.z > max.z then max.z := p.z;
end;

function AABB.Intersect(const r: Ray; tMax: Double): Boolean;
var
  t0x, t1x, t0y, t1y, t0z, t1z, tMin, tEnd: Double;
  invDirX, invDirY, invDirZ: Double;
begin
  invDirX := 1.0 / r.d.x; invDirY := 1.0 / r.d.y; invDirZ := 1.0 / r.d.z;
  if invDirX >= 0 then begin t0x := (min.x - r.o.x) * invDirX; t1x := (max.x - r.o.x) * invDirX; end
  else begin t0x := (max.x - r.o.x) * invDirX; t1x := (min.x - r.o.x) * invDirX; end;
  if invDirY >= 0 then begin t0y := (min.y - r.o.y) * invDirY; t1y := (max.y - r.o.y) * invDirY; end
  else begin t0y := (max.y - r.o.y) * invDirY; t1y := (min.y - r.o.y) * invDirY; end;
  if invDirZ >= 0 then begin t0z := (min.z - r.o.z) * invDirZ; t1z := (max.z - r.o.z) * invDirZ; end
  else begin t0z := (max.z - r.o.z) * invDirZ; t1z := (min.z - r.o.z) * invDirZ; end;
  tMin := Max(t0x, Max(t0y, t0z));
  tEnd := Min(t1x, Min(t1y, t1z));
  Result := (tMin <= tEnd) and (tEnd >= 0.0) and (tMin < tMax);
end;

type
  // 三角形ポリゴンクラス
  Triangle = record
    v0, v1, v2: Vec;
    n: Vec; // 法線
    e, c: Vec; // 放射、色
    refl: Refl_t;
    function Intersect(const r: Ray; out t: Double): Boolean;
    function GetCenter: Vec; inline;
  end;

function Triangle.Intersect(const r: Ray; out t: Double): Boolean;
var
  edge1, edge2, pvec, tvec, qvec: Vec;
  det, invDet, u, v: Double;
begin
  t := 0;
  edge1 := v1 - v0; edge2 := v2 - v0;
  pvec := r.d.Cross(edge2);
  det := edge1.Dot(pvec);
  if Abs(det) < 1e-6 then Exit(False);
  invDet := 1.0 / det;
  tvec := r.o - v0;
  u := tvec.Dot(pvec) * invDet;
  if (u < 0.0) or (u > 1.0) then Exit(False);
  qvec := tvec.Cross(edge1);
  v := r.d.Dot(qvec) * invDet;
  if (v < 0.0) or (u + v > 1.0) then Exit(False);
  t := edge2.Dot(qvec) * invDet;
  Result := t > 1e-4;
end;

function Triangle.GetCenter: Vec;
begin
  Result := (v0 + v1 + v2) * (1.0 / 3.0);
end;

type
  PBVHNode = ^TBVHNode;
  TBVHNode = record
    box: AABB;
    left, right: PBVHNode;
    triIndex: Integer; // 子が葉の場合の三角形インデックス、内部ノードなら -1
  end;

var
  triangles: array of Triangle;
  bvhRoot: PBVHNode = nil;

// 空間分割用インデックス配列
var
  triIndices: array of Integer;

function BuildBVH(startIdx, endIdx: Integer): PBVHNode;
var
  node: PBVHNode;
  i, axis, count, mid: Integer;
  centroidBounds: AABB;
  center: Vec;
  pivot: Double;
  tmp: Integer;
begin
  New(node);
  node^.left := nil; node^.right := nil; node^.triIndex := -1;

  // 1. 境界ボックスのフィッティング
  node^.box.min := Vec.Create(1e20, 1e20, 1e20);
  node^.box.max := Vec.Create(-1e20, -1e20, -1e20);
  centroidBounds.min := Vec.Create(1e20, 1e20, 1e20);
  centroidBounds.max := Vec.Create(-1e20, -1e20, -1e20);

  count := endIdx - startIdx;
  for i := startIdx to endIdx - 1 do
  begin
    var idx := triIndices[i];
    node^.box.Fit(triangles[idx].v0);
    node^.box.Fit(triangles[idx].v1);
    node^.box.Fit(triangles[idx].v2);
    centroidBounds.Fit(triangles[idx].GetCenter);
  end;

  // 要素が1つの場合は葉とする
  if count = 1 then
  begin
    node^.triIndex := triIndices[startIdx];
    Exit(node);
  end;

  // 2. 最も長い軸を選択
  var extents := centroidBounds.max - centroidBounds.min;
  if (extents.x > extents.y) and (extents.x > extents.z) then axis := 0
  else if extents.y > extents.z then axis := 1
  else axis := 2;

  // 3. 中間点(Midpoint)でソート/分割
  case axis of
    0: pivot := (centroidBounds.min.x + centroidBounds.max.x) * 0.5;
    1: pivot := (centroidBounds.min.y + centroidBounds.max.y) * 0.5;
    2: pivot := (centroidBounds.min.z + centroidBounds.max.z) * 0.5;
  end;

  // 簡易的なパーティショニング（クイックソートのピボット分割の変形）
  mid := startIdx;
  for i := startIdx to endIdx - 1 do
  begin
    center := triangles[triIndices[i]].GetCenter;
    var val: Double;
    if axis = 0 then val := center.x else if axis = 1 then val := center.y else val := center.z;
    if val < pivot then
    begin
      tmp := triIndices[i];
      triIndices[i] := triIndices[mid];
      triIndices[mid] := tmp;
      Inc(mid);
    end;
  end;

  // 完全に片方に偏ってしまった場合のフォールバック（半分で分ける）
  if (mid = startIdx) or (mid = endIdx) then
    mid := startIdx + count div 2;

  // 4. 再帰的に構築
  node^.left := BuildBVH(startIdx, mid);
  node^.right := BuildBVH(mid, endIdx);
  Result := node;
end;

function IntersectBVH(node: PBVHNode; const r: Ray; var tNearest: Double; var id: Integer): Boolean;
var
  tTri: Double;
  hitLeft, hitRight: Boolean;
begin
  Result := False;
  if (node = nil) or not node^.box.Intersect(r, tNearest) then Exit;

  // 葉ノードの場合
  if node^.triIndex <> -1 then
  begin
    if triangles[node^.triIndex].Intersect(r, tTri) then
    begin
      if tTri < tNearest then
      begin
        tNearest := tTri;
        id := node^.triIndex;
        Result := True;
      end;
    end;
    Exit;
  end;

  // 内部ノードの場合、左右を探索
  hitLeft := IntersectBVH(node^.left, r, tNearest, id);
  hitRight := IntersectBVH(node^.right, r, tNearest, id);
  Result := hitLeft or hitRight;
end;

// 簡単な .obj ファイルリーダ
procedure LoadOBJ(const filename: string; defaultColor, defaultEmit: Vec; defaultRefl: Refl_t);
var
  lines: TStringList;
  vertices: array of Vec;
  vCount, fCount: Integer;
  i: Integer;
  line: string;
  parts: TStringList;
begin
  if not FileExists(filename) then
  begin
    Writeln('Error: File not found: ', filename);
    Halt(1);
  end;

  lines := TStringList.Create;
  parts := TStringList.Create;
  parts.Delimiter := ' ';
  parts.StrictDelimiter := True;
  
  vCount := 0; fCount := 0;
  lines.LoadFromFile(filename);
  
  // カウントパス
  for i := 0 to lines.Count - 1 do
  begin
    line := Trim(lines[i]);
    if line.StartsWith('v ') then Inc(vCount)
    else if line.StartsWith('f ') then Inc(fCount);
  end;

  SetLength(vertices, vCount);
  SetLength(triangles, fCount);
  SetLength(triIndices, fCount);

  var vIdx: Integer = 0;
  var fIdx: Integer = 0;

  // 読み込みパス
  for i := 0 to lines.Count - 1 do
  begin
    line := Trim(lines[i]);
    if line.StartsWith('v ') then
    begin
      parts.DelimitedText := line;
      // フォーマット: v x y z
      vertices[vIdx] := Vec.Create(
        StrToFloatDef(parts[1], 0.0),
        StrToFloatDef(parts[2], 0.0),
        StrToFloatDef(parts[3], 0.0)
      );
      Inc(vIdx);
    end
    else if line.StartsWith('f ') then
    begin
      parts.DelimitedText := line;
      // 簡易実装のため三角ポリゴン(f v1 v2 v3)のみ対応。テクスチャ/法線インデックス(v/t/n)はパースで除去
      var fParts: array[0..2] of string;
      var p: Integer;
      for p := 0 to 2 do
      begin
        var subParts := TStringList.Create;
        subParts.Delimiter := '/';
        subParts.StrictDelimiter := True;
        subParts.DelimitedText := parts[p+1];
        fParts[p] := subParts[0];
        subParts.Free;
      end;

      var idx0 := StrToInt(fParts[0]) - 1;
      var idx1 := StrToInt(fParts[1]) - 1;
      var idx2 := StrToInt(fParts[2]) - 1;

      triangles[fIdx].v0 := vertices[idx0];
      triangles[fIdx].v1 := vertices[idx1];
      triangles[fIdx].v2 := vertices[idx2];
      
      // 法線の事前計算
      triangles[fIdx].n := (vertices[idx1] - vertices[idx0]).Cross(vertices[idx2] - vertices[idx0]).Norm;
      triangles[fIdx].c := defaultColor;
      triangles[fIdx].e := defaultEmit;
      triangles[fIdx].refl := defaultRefl;
      
      triIndices[fIdx] := fIdx;
      Inc(fIdx);
    end;
  end;

  parts.Free;
  lines.Free;
  Writeln(Format('Loaded %d vertices, %d triangles.', [vCount, fCount]));
end;

function Clamp(x: Double): Double; inline; begin if x < 0 then Exit(0); if x > 1 then Exit(1); Result := x; end;
function ToInt(x: Double): Integer; inline; begin Result := Trunc(Power(Clamp(x), 1.0 / 2.2) * 255.0 + 0.5); end;

type TXiState = array[0..2] of Word;
function Erand48(var Xi: TXiState): Double;
var acc: UInt64;
const a: array[0..2] of Word = ($e66d, $deec, $0005); c: Word = $000b;
begin
  acc := UInt64(Xi[0]) * a[0] + c; Xi[0] := acc and $FFFF;
  acc := (acc shr 16) + UInt64(Xi[1]) * a[0] + UInt64(Xi[0]) * a[1]; Xi[1] := acc and $FFFF;
  acc := (acc shr 16) + UInt64(Xi[2]) * a[0] + UInt64(Xi[1]) * a[1] + UInt64(Xi[0]) * a[2]; Xi[2] := acc and $FFFF;
  Result := (Double(Xi[0]) / 65536.0 + Double(Xi[1])) / 65536.0; Result := (Result + Double(Xi[2])) / 65536.0;
end;

function Radiance(const r: Ray; depth: Integer; var Xi: TXiState): Vec;
var
  t: Double;
  id: Integer;
  obj: Triangle;
  x, n, nl, f: Vec;
  p: Double;
  r1, r2, r2s: Double;
  w, u, v, dDir: Vec;
  reflRay: Ray;
  into: Boolean;
  nc, nt, nnt, ddn, cos2t: Double;
  tdir: Vec;
  a, b, R0, c, Re, Tr, P_prob, RP, TP: Double;
begin
  t := 1e20;
  id := -1;
  if not IntersectBVH(bvhRoot, r, t, id) then Exit(Vec.Create()); // 外は黒

  obj := triangles[id];
  x := r.o + r.d * t;
  n := obj.n;
  if n.Dot(r.d) < 0 then nl := n else nl := n * -1.0;
  f := obj.c;

  p := Max(f.x, Max(f.y, f.z));
  depth += 1;
  if depth > 5 then
  begin
    if Erand48(Xi) < p then f := f * (1.0 / p) else Exit(obj.e);
  end;

  if obj.refl = DIFF then
  begin
    r1 := 2.0 * pi * Erand48(Xi); r2 := Erand48(Xi); r2s := Sqrt(r2);
    w := nl;
    if Abs(w.x) > 0.1 then u := Vec.Create(0, 1, 0) else u := Vec.Create(1, 0, 0);
    u := u.Cross(w).Norm; v := w.Cross(u);
    dDir := (u * Cos(r1) * r2s + v * Sin(r1) * r2s + w * Sqrt(1.0 - r2)).Norm;
    Exit(obj.e + f.Mult(Radiance(Ray.Create(x, dDir), depth, Xi)));
  end
  else if obj.refl = SPEC then
  begin
    Exit(obj.e + f.Mult(Radiance(Ray.Create(x, r.d - n * 2.0 * n.Dot(r.d)), depth, Xi)));
  end;

  // REFR
  reflRay := Ray.Create(x, r.d - n * 2.0 * n.Dot(r.d));
  into := n.Dot(nl) > 0.0;
  nc := 1.0; nt := 1.5;
  if into then nnt := nc / nt else nnt := nt / nc;
  ddn := r.d.Dot(nl);
  cos2t := 1.0 - nnt * nnt * (1.0 - ddn * ddn);

  if cos2t < 0 then Exit(obj.e + f.Mult(Radiance(reflRay, depth, Xi)));

  if into then tdir := (r.d * nnt - n * (ddn * nnt + Sqrt(cos2t))).Norm
  else tdir := (r.d * nnt - n * (-ddn * nnt + Sqrt(cos2t))).Norm;

  a := nt - nc; b := nt + nc; R0 := (a * a) / (b * b);
  if into then c := 1.0 - (-ddn) else c := 1.0 - tdir.Dot(n);
  Re := R0 + (1.0 - R0) * c * c * c * c * c; Tr := 1.0 - Re;

  if depth > 2 then
  begin
    P_prob := 0.25 + 0.5 * Re; RP := Re / P_prob; TP := Tr / (1.0 - P_prob);
    if Erand48(Xi) < P_prob then Result := obj.e + f.Mult(Radiance(reflRay, depth, Xi) * RP)
    else Result := obj.e + f.Mult(Radiance(Ray.Create(x, tdir), depth, Xi) * TP);
  end
  else begin
    Result := obj.e + f.Mult(Radiance(reflRay, depth, Xi) * Re + Radiance(Ray.Create(x, tdir), depth, Xi) * Tr);
  end;
end;

var
  w, h, samps: Integer;
  cam: Ray;
  cx, cy: Vec;
  c_arr: array of Vec;
  y: Integer;

begin
  if ParamCount < 1 then
  begin
    Writeln('Usage: ./smallpt_bvh <model.obj> [samps]');
    Halt(1);
  end;

  var objFile := ParamStr(1);
  if ParamCount >= 2 then samps := StrToIntDef(ParamStr(2), 4) div 4 else samps := 1;

  // 1. OBJファイルをロード（デフォルトで白いディフューズ面として読み込み）
  Writeln('Loading OBJ file...');
  LoadOBJ(objFile, Vec.Create(0.75, 0.75, 0.75), Vec.Create(0,0,0), DIFF);

  if Length(triangles) = 0 then
  begin
    Writeln('Error: No triangles loaded.');
    Halt(1);
  end;

  // 2. BVHの構築
  Writeln('Building BVH...');
  bvhRoot := BuildBVH(0, Length(triangles));
  Writeln('BVH built successfully.');

  w := 1024; h := 768;
  // カメラ位置の調整：読み込むモデルに応じて適宜変更してください
  cam := Ray.Create(Vec.Create(0, 5, 15), Vec.Create(0, -0.2, -1).Norm);
  cx := Vec.Create(w * 0.5135 / h);
  cy := cx.Cross(cam.d).Norm * 0.5135;
  SetLength(c_arr, w * h);

  // 3. レンダリングループ
  for y := 0 to h - 1 do
  begin
    Write(Format(#13'Rendering (%d spp) %5.2f%%', [samps * 4, 100.0 * y / (h - 1)]));
    var x: Integer;
    for x := 0 to w - 1 do
    begin
      var Xi: TXiState;
      Xi[0] := 0; Xi[1] := 0; Xi[2] := y * y * y;
      var sy: Integer;
      for sy := 0 to 1 do
      begin
        var i: Integer = (h - y - 1) * w + x;
        var sx: Integer;
        for sx := 0 to 1 do
        begin
          var r_accum: Vec = Vec.Create(0,0,0);
          var s: Integer;
          for s := 0 to samps - 1 do
          begin
            var r1, r2, dx, dy: Double;
            r1 := 2.0 * Erand48(Xi); if r1 < 1.0 then dx := Sqrt(r1) - 1.0 else dx := 1.0 - Sqrt(2.0 - r1);
            r2 := 2.0 * Erand48(Xi); if r2 < 1.0 then dy := Sqrt(r2) - 1.0 else dy := 1.0 - Sqrt(2.0 - r2);
            var dDir: Vec = cx * (((sx + 0.5 + dx) / 2.0 + x) / w - 0.5) +
                            cy * (((sy + 0.5 + dy) / 2.0 + y) / h - 0.5) + cam.d;
            // 注意: 元のコードの「+dDir*140」は球体内からカメラを出すハックなので、ポリゴン用に通常の「cam.o」から開始
            r_accum := r_accum + Radiance(Ray.Create(cam.o, dDir.Norm), 0, Xi) * (1.0 / samps);
          end;
          c_arr[i] := c_arr[i] + Vec.Create(Clamp(r_accum.x), Clamp(r_accum.y), Clamp(r_accum.z)) * 0.25;
        end;
      end;
    end;
  end;
  Writeln;

  // 4. PPM書き出し
  var fOut: TextFile;
  AssignFile(fOut, 'image.ppm'); Rewrite(fOut);
  try
    Writeln(fOut, 'P3'); Writeln(fOut, Format('%d %d', [w, h])); Writeln(fOut, '255');
    var i: Integer;
    for i := 0 to w * h - 1 do
      Write(fOut, Format('%d %d %d ', [ToInt(c_arr[i].x), ToInt(c_arr[i].y), ToInt(c_arr[i].z)]));
  finally
    CloseFile(fOut);
  end;
  Writeln('Done.');
end.
