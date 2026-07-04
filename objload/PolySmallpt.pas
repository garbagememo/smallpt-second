program CornellBoxPathTracer;

{$mode objfpc}{$H+}{$INLINE ON}

uses
  SysUtils, Math;

const
  WIDTH = 320;
  HEIGHT = 240;
  // 💡 綺麗にするにはこのサンプリング数を 100〜1000 以上に増やしてください。
  // 数値を上げると比例して計算時間が長くなります。
  SAMPLES = 64; 

type
  Vec3 = record
    x, y, z: real;
  end;

  RayRecord = record
    x, r: Vec3; // x: 位置(Origin), r: 方向(Direction)
  end;

  Refl_t = (DIFF, SPEC, REFR); // 反射タイプ：拡散反射、鏡面反射、ガラス屈折

  Triangle = record
    v0, v1, v2: Vec3;
    c: Vec3;    // 色（拡散反射率 / 鏡面反射率）
    e: Vec3;    // 発光輝度（Emission）
    refl: Refl_t;
  end;

var
  Image: array[0..WIDTH-1, 0..HEIGHT-1] of Vec3;
  Polygons: array of Triangle;

// --- 演算子オーバーロード ---
operator + (const a, b: Vec3) r: Vec3; inline;
begin r.x := a.x + b.x; r.y := a.y + b.y; r.z := a.z + b.z; end;

operator - (const a, b: Vec3) r: Vec3; inline;
begin r.x := a.x - b.x; r.y := a.y - b.y; r.z := a.z - b.z; end;

operator * (const a, b: Vec3) r: real; inline; // 内積
begin r := a.x * b.x + a.y * b.y + a.z * b.z; end;

operator * (const a: Vec3; const b: real) r: Vec3; inline; // ベクトル * スカラー
begin r.x := a.x * b; r.y := a.y * b; r.z := a.z * b; end;

operator * (const a: real; const b: Vec3) r: Vec3; inline; // スカラー * ベクトル
begin r.x := a * b.x; r.y := a * b.y; r.z := a * b.z; end;

// --- ヘルパー関数 ---
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

function CrossProduct(const a, b: Vec3): Vec3; inline;
begin
  result.x := a.y * b.z - a.z * b.y;
  result.y := a.z * b.x - a.x * b.z;
  result.z := a.x * b.y - a.y * b.x;
end;

function Normalize(const v: Vec3): Vec3; inline;
var len: real;
begin
  len := Sqrt(v * v);
  if len > 0.0 then result := v * (1.0 / len) else result := v;
end;

// --- シーン構築 ---
procedure AddTriangle(v0, v1, v2, c, e: Vec3; refl: Refl_t);
var idx: Integer;
begin
  idx := Length(Polygons);
  SetLength(Polygons, idx + 1);
  Polygons[idx].v0 := v0;
  Polygons[idx].v1 := v1;
  Polygons[idx].v2 := v2;
  Polygons[idx].c := c;
  Polygons[idx].e := e;
  Polygons[idx].refl := refl;
end;

procedure AddQuad(v0, v1, v2, v3, c, e: Vec3; refl: Refl_t);
begin
  AddTriangle(v0, v1, v2, c, e, refl);
  AddTriangle(v0, v2, v3, c, e, refl);
end;

procedure InitScene;
begin
  SetLength(Polygons, 0);
  
  // コーネルボックスの壁 (サイズ 50x50x50)
  // 床 (白)
  AddQuad(NewVec3(0,0,0), NewVec3(50,0,0), NewVec3(50,0,50), NewVec3(0,0,50), NewVec3(0.75,0.75,0.75), NewVec3(0,0,0), DIFF);
  // 天井 (白)
  AddQuad(NewVec3(0,50,0), NewVec3(0,50,50), NewVec3(50,50,50), NewVec3(50,50,0), NewVec3(0.75,0.75,0.75), NewVec3(0,0,0), DIFF);
  // 奥の壁 (白)
  AddQuad(NewVec3(0,0,50), NewVec3(50,0,50), NewVec3(50,50,50), NewVec3(0,50,50), NewVec3(0.75,0.75,0.75), NewVec3(0,0,0), DIFF);
  // 左の壁 (赤)
  AddQuad(NewVec3(0,0,0), NewVec3(0,0,50), NewVec3(0,50,50), NewVec3(0,50,0), NewVec3(0.75,0.25,0.25), NewVec3(0,0,0), DIFF);
  // 右の壁 (青)
  AddQuad(NewVec3(50,0,0), NewVec3(50,50,0), NewVec3(50,50,50), NewVec3(50,0,50), NewVec3(0.25,0.25,0.75), NewVec3(0,0,0), DIFF);
  
  // 天井の大きな面光源 (smallpt同様、高輝度な発光を設定して柔らかい光を作る)
  AddQuad(NewVec3(15,49.9,15), NewVec3(15,49.9,35), NewVec3(35,49.9,35), NewVec3(35,49.9,15), NewVec3(0,0,0), NewVec3(12,12,12), DIFF);

  // 内部オブジェクト1：右側の低いガラスブロック (REFR)
  AddQuad(NewVec3(27,0,12), NewVec3(42,0,12), NewVec3(42,15,12), NewVec3(27,15,12), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), REFR); // 前
  AddQuad(NewVec3(42,0,12), NewVec3(42,0,27), NewVec3(42,15,27), NewVec3(42,15,12), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), REFR); // 右
  AddQuad(NewVec3(42,0,27), NewVec3(27,0,27), NewVec3(27,15,27), NewVec3(42,15,27), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), REFR); // 奥
  AddQuad(NewVec3(27,0,27), NewVec3(27,0,12), NewVec3(27,15,12), NewVec3(27,15,27), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), REFR); // 左
  AddQuad(NewVec3(27,15,12), NewVec3(42,15,12), NewVec3(42,15,27), NewVec3(27,15,27), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), REFR); // 上

  // 内部オブジェクト2：左側の高い鏡面ブロック (SPEC)
  AddQuad(NewVec3(10,0,25), NewVec3(22,0,25), NewVec3(22,30,25), NewVec3(10,30,25), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), SPEC); // 前
  AddQuad(NewVec3(22,0,25), NewVec3(22,0,37), NewVec3(22,30,37), NewVec3(22,30,25), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), SPEC); // 右
  AddQuad(NewVec3(22,0,37), NewVec3(10,0,37), NewVec3(10,30,37), NewVec3(22,30,37), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), SPEC); // 奥
  AddQuad(NewVec3(10,0,37), NewVec3(10,0,25), NewVec3(10,30,25), NewVec3(10,30,37), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), SPEC); // 左
  AddQuad(NewVec3(10,30,25), NewVec3(22,30,25), NewVec3(22,30,37), NewVec3(10,30,37), NewVec3(0.999,0.999,0.999), NewVec3(0,0,0), SPEC); // 上
end;

// --- 交差判定 (Möller-Trumbore アルゴリズム) ---
function IntersectTriangle(const ray: RayRecord; const t: Triangle; out t_out: real): boolean;
const EPSILON = 0.000001;
var
  edge1, edge2, h, s, q: Vec3;
  a, f, u, v: real;
begin
  result := false;
  edge1 := t.v1 - t.v0;
  edge2 := t.v2 - t.v0;
  h := CrossProduct(ray.r, edge2);
  a := edge1 * h;
  if (a > -EPSILON) and (a < EPSILON) then Exit;
  
  f := 1.0 / a;
  s := ray.x - t.v0;
  u := f * (s * h);
  if (u < 0.0) or (u > 1.0) then Exit;
  
  q := CrossProduct(s, edge1);
  v := f * (ray.r * q);
  if (v < 0.0) or (u + v > 1.0) then Exit;
  
  t_out := f * (edge2 * q);
  if t_out > EPSILON then result := true;
end;

function SceneIntersect(const ray: RayRecord; out hitId: Integer; out t_min: real): boolean;
var
  i: Integer;
  t_val: real;
begin
  result := false;
  hitId := -1;
  t_min := 1e20;
  for i := 0 to Length(Polygons) - 1 do begin
    if IntersectTriangle(ray, Polygons[i], t_val) then begin
      if t_val < t_min then begin
        t_min := t_val;
        hitId := i;
        result := true;
      end;
    end;
  end;
end;

// --- パストレーシング・コア (Trace 関数) ---
function Trace(const ray: RayRecord; depth: Integer): Vec3;
var
  hitId: Integer;
  t, r1, r2, r2s: real;
  hitPoly: Triangle;
  hitPos, n, nl, w, u, v, randomDir: Vec3;
  refRay, refrRay: RayRecord;
  into: boolean;
  nc, nt, nnt, ddn, cos2t, b, c, a, R0, Re, Tr, P: real;
  tDir: Vec3;
begin
  // 最大バウンス数に達したか、何にも当たらなければ黒を返す
  if (depth > 5) or (not SceneIntersect(ray, hitId, t)) then begin
    Result := NewVec3(0,0,0);
    Exit;
  end;

  hitPoly := Polygons[hitId];
  hitPos := ray.x + ray.r * t;
  
  // 法線ベクトルの計算と裏表反転の考慮
  n := Normalize(CrossProduct(hitPoly.v1 - hitPoly.v0, hitPoly.v2 - hitPoly.v0));
  if (n * ray.r) < 0.0 then nl := n else nl := n * -1.0;

  case hitPoly.refl of
    DIFF: begin // 拡散反射 (モンテカルロ半球コサインサンプリング)
      w := nl;
      if Abs(w.x) > 0.1 then u := NewVec3(0, 1, 0) else u := NewVec3(1, 0, 0);
      u := Normalize(CrossProduct(u, w));
      v := CrossProduct(w, u);

      r1 := 2.0 * Pi * Random;
      r2 := Random;
      r2s := Sqrt(r2);
      
      randomDir := (u * (Cos(r1) * r2s)) + (v * (Sin(r1) * r2s)) + (w * Sqrt(1.0 - r2));
      randomDir := Normalize(randomDir);

      refRay.x := hitPos + nl * 0.001; // 自己衝突防止
      refRay.r := randomDir;
      
      Result := hitPoly.e + ColorMul(hitPoly.c, Trace(refRay, depth + 1));
    end;
    
    SPEC: begin // 完全鏡面反射
      refRay.x := hitPos + nl * 0.001;
      refRay.r := ray.r - n * 2.0 * (n * ray.r);
      Result := hitPoly.e + ColorMul(hitPoly.c, Trace(refRay, depth + 1));
    end;
    
    REFR: begin // ガラスの屈折・反射 (スネルの法則とフレネルの式)
      refRay.x := hitPos + nl * 0.001;
      refRay.r := ray.r - n * 2.0 * (n * ray.r);
      
      into := (n * nl > 0.0);
      nc := 1.0;  // 空気の屈折率
      nt := 1.5;  // ガラスの屈折率
      if into then nnt := nc / nt else nnt := nt / nc;
      ddn := ray.r * nl;
      cos2t := 1.0 - nnt * nnt * (1.0 - ddn * ddn);
      
      if cos2t < 0.0 then begin // 全反射のケース
        Result := hitPoly.e + ColorMul(hitPoly.c, Trace(refRay, depth + 1));
        Exit;
      end;
      
      if into then b := 1.0 else b := -1.0;
      tDir := Normalize(ray.r * nnt - n * (b * (ddn * nnt + Sqrt(cos2t))));
      refrRay.x := hitPos - nl * 0.001;
      refrRay.r := tDir;
      
      if into then c := 1.0 + ddn else c := 1.0 - (tDir * n);
      a := nt - nc;
      b := nt + nc;
      R0 := (a * a) / (b * b);
      Re := R0 + (1.0 - R0) * c * c * c * c * c; // 反射率
      Tr := 1.0 - Re;                            // 透過率
      
      // ロシアルーレットによる計算の効率化 (深くなったら確率的にどちらか片方だけ追う)
      if depth > 2 then begin
        P := 0.25 + 0.5 * Re;
        if Random < P then
          Result := hitPoly.e + ColorMul(hitPoly.c, Trace(refRay, depth + 1) * (Re / P))
        else
          Result := hitPoly.e + ColorMul(hitPoly.c, Trace(refrRay, depth + 1) * (Tr / (1.0 - P)));
      end else begin
        // 浅い階層では両方を追って正確にブレンド
        Result := hitPoly.e + ColorMul(hitPoly.c, (Trace(refRay, depth + 1) * Re + Trace(refrRay, depth + 1) * Tr));
      end;
    end;
  end;
end;

// --- レンダリングループ (マルチサンプリング対応) ---
procedure Render;
var
  x, y, s: Integer;
  fx, fy: real;
  dir, accumulatedColor: Vec3;
  ray: RayRecord;
  len: real;
begin
  Randomize;
  Write('Rendering...');
  for y := 0 to HEIGHT - 1 do begin
    for x := 0 to WIDTH - 1 do begin
      accumulatedColor := NewVec3(0, 0, 0);
      
      for s := 0 to SAMPLES - 1 do begin
        // ピクセル内にわずかなランダム性を与えてアンチエイリアス処理
        fx := ((x + Random) - WIDTH / 2.0) / (WIDTH / 2.0) * 0.22;
        fy := -((y + Random) - HEIGHT / 2.0) / (HEIGHT / 2.0) * 0.22;

        dir.x := fx; dir.y := fy; dir.z := 1.0;
        len := Sqrt(dir * dir);
        dir := dir * (1.0 / len);

        // カメラ位置を Z=-65 に引き、手前から奥へとレイを飛ばす
        ray.x := NewVec3(25.0, 25.0, -65.0);
        ray.r := dir;

        accumulatedColor := accumulatedColor + Trace(ray, 0);
      end;
      
      // 平均化して画像配列に格納
      Image[x, y] := accumulatedColor * (1.0 / SAMPLES);
    end;
    if y mod 10 = 0 then Write('.');
  end;
  Writeln(' Done.');
end;

// --- PPM形式でのファイル保存 (ガンマ補正・クランプ処理) ---
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
      // Math.EnsureRange と Math.Power を用いて確実に 0-255 にクランプ
      r := EnsureRange(Round(Power(EnsureRange(c.x, 0.0, 1.0), 1.0 / 2.2) * 255), 0, 255);
      g := EnsureRange(Round(Power(EnsureRange(c.y, 0.0, 1.0), 1.0 / 2.2) * 255), 0, 255);
      b := EnsureRange(Round(Power(EnsureRange(c.z, 0.0, 1.0), 1.0 / 2.2) * 255), 0, 255);
      Writeln(f, r, ' ', g, ' ', b);
    end;
  end;
  CloseFile(f);
  Writeln('Saved to ', filename);
end;

// --- メイン処理 ---
begin
  InitScene;
  Render;
  SavePPM('render.ppm');
end.
