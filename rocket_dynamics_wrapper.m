% rocket_dynamicsのラッパー
function dx = rocket_dynamics_wrapper(t, x)
global ROCKET;
Ft = thrust(t, [ROCKET.Tend], [ROCKET.FT]);
deltaY = 0;
deltaP = 0;
Tr = 0;
%VWH = [0; 0; 0];
global VWH;
u = [Ft; deltaY; deltaP; Tr; VWH];
dx = rocket_dynamics(t, x, u);
end
