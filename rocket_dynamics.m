% ----
% odeのためのロケット飛翔の常微分方程式
% 位置と姿勢を求めるために、「位置、速度、姿勢、角速度」を状態量に。
%
% やってること
% 機体にかかる推力、空気力、重力の算出
% -> 機体にかかるモーメントの算出
% -> 位置の運動方程式、速度の運動方程式、姿勢の運動方程式、角速度の運動方程式
%
% 水平座標系の取り方はxyzの順番にUp-East-North
% ----
function [ dx ] = rocket_dynamics( t, x )
% t: time 時刻[s]
% x(1): mass 質量[kg]
% x(2): X_H 射点座標位置[m]
% x(3): Y_H 射点座標位置[m]
% x(4): Z_H 射点座標位置[m]
% x(5): VX_H 射点座標対地速度[m/s]
% x(6): VY_H 射点座標対地速度[m/s]
% x(7): VZ_H 射点座標対地速度[m/s]
% x(8): q0 quaternion Body to Horizon[-]
% x(9): q1 quaternion Body to Horizon[-]
% x(10): q2 quaternion Body to Horizon[-]
% x(11): q3 quaternion Body to Horizon[-]
% x(12): omegaX 機体座標系の角速度[rad/s]
% x(13): omegaY 機体座標系の角速度[rad/s]
% x(14): omegaZ 機体座標系の角速度[rad/s]
% ----

% 機体パラメータ読み込み
constants = params_rocket();
m0 = constants.m0;
Isp = constants.Isp;
g0 = constants.g0;
FT = constants.FT;
Tend = constants.Tend;
At = constants.At;
CLa = constants.CLa;
Area = constants.Area;
length_GCM = constants.length_GCM;
length_A = constants.length_A;
IXX = constants.Ijj(1);
IYY = constants.Ijj(2);
IZZ = constants.Ijj(3);
azimth = constants.azimth;
elevation = constants.elevation;

IXXdot = 0;
IYYdot = 0;
IZZdot = 0;

% ---- 推力 ----
% ジンバル角度 delta_Y, delta_P[rad]
deltaY = 0;
deltaP = 0;

% 大気圧 P[Pa] 大気密度 rho[kg/m3]
% P = 101325;
% rho = 1.2;
[~, a, P, rho] = atmosphere_Rocket(x(2));

% 定格推力 FT[N] その時刻における推力 Ft[N]
% 推進剤の質量流量 delta_m[kg/s]
Ft = thrust(t, [Tend], [FT]);
delta_m = -Ft / Isp / g0;

% ジンバル角を考慮した機体座標系における推力 FTB[N]
FTB = Ft * [cos(deltaY)*cos(deltaP); -sin(deltaY); -cos(deltaY)*sin(deltaP)];

% ---- 空気力 ----
% 水平座標系における風ベクトルVWH[m/s]（高度方向の分布は無いものとする）
% 水平座標系における機体の対気速度ベクトルVA[m/s]
VWH = [0; 0; 0];
VA = [x(5); x(6); x(7)] - VWH; % 対気速度

% 機体座標系から水平座標系への座標変換を表すクォータニオン quat (quat_B2H)
quat = [x(8); x(9); x(10); x(11)]; % q_B2H

% 機体座標系からみた速度ベクトルVABを求めて速度座標系の定義から
% 機体座標系からみた速度座標系の基底ベクトル[xAB yAB zAB]をもとめて
% 速度座標系から機体座標系への方向余弦行列DCM_A2Bを求めている。
% 機体座標系における空気力 FAB[N]
if norm(VA) == 0.0
  xAB = [1; 0; 0]; % 機体座標系速度方向単位ベクトル
  VAB = [0; 0; 0];
else
  qVAB = quatmultiply(quat, quatmultiply([0; VA], quatinv(quat)));
  VAB = qVAB(2:4);
  xAB = VAB / norm(VAB);
end
yABsintheta = cross(xAB, [1; 0; 0]);
sintheta = norm(yABsintheta);
if sintheta == 0.0
  yAB = [0; 1; 0];
else
  yAB = yABsintheta / sintheta;
end
theta = asin(sintheta);
zAB = cross(xAB, yAB);

% 速度座標系からみた空気力 FAA[N]
CD = cd_Rocket(norm(VAB) / a);
FAA = -0.5*rho*norm(VA)^2*Area*[CD; 0; CLa * theta];

DCM_A2B = [xAB yAB zAB];
FAB = DCM_A2B * FAA;

% ---- 重力 ----
% 水平座標系における機体にかかる重力 FHG[N]
[gc, gnorth] = gravity(x(2), 35*pi/180);
FGH = x(1) * [gc; 0; gnorth];

% ---- モーメント ----
% 推力によるモーメント MT[Nm]
% 空気力によるモーメント MA[Nm]
MT = -cross(FTB, length_GCM);
MA = -cross(FAB, length_A);
M = MT + MA;

% ---- 速度運動方程式 ----
qFTAH = quatmultiply(quatinv(quat),quatmultiply([0; (FTB+FAB)], quat));
FTAH = qFTAH(2:4);
delta_V = 1/x(1)*(FTAH + FGH);

% ---- 姿勢の運動方程式----
delta_quat = -0.5 * quatmultiply([0; x(12:14)], x(8:11));

% ---- 角速度の運動方程式----
delta_omega(1) = 1/IXX * (M(1) - IXXdot * x(12) - (IZZ - IYY) * x(13) * x(14));
delta_omega(2) = 1/IYY * (M(2) - IYYdot * x(13) - (IXX - IZZ) * x(14) * x(12));
delta_omega(3) = 1/IXX * (M(3) - IZZdot * x(14) - (IYY - IXX) * x(12) * x(13));

dx = [ delta_m;
x(5);
x(6);
x(7);
delta_V(1);
delta_V(2);
delta_V(3);
delta_quat(1);
delta_quat(2);
delta_quat(3);
delta_quat(4);
delta_omega(1);
delta_omega(2);
delta_omega(3)];

end
