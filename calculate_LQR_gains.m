%% ME561_Final_Project.m

%% Hovering Rocket Linearization Model
% Initialize 
clear; clc; close all;
% Constants
g = 9.81;
l = 70;
L = l;
r = 3.66/2;
o = 0.01; % offset
m0 = 34284; % [kg]
mf = 549054; % [kg]
I_sp = 2770;
Fp_max = 7607*10^3;
x0 = [o, o, o, 0, o, o, 90, 15, -90, ((m0+mf)/2), o];
u0 = [mf*g, 0, 0];
phi_u = -g*sind(x0(7))*sind(x0(8))*cosd(x0(9)) + g*cosd(x0(7))*sind(x0(9));
theta_u = g*cosd(x0(7))*cosd(x0(8))*cosd(x0(9));
psi_u = -g*cosd(x0(7))*sind(x0(8))*sind(x0(9)) + g*sind(x0(7))*cosd(x0(9));
phi_v = -g*(sind(x0(7))*sind(x0(8))*cosd(x0(9)) + cosd(x0(7))*cosd(x0(9)));
theta_v = g*cosd(x0(7))*cosd(x0(8))*cosd(x0(9));
psi_v = g*sind(x0(9))*(sind(x0(7))-cosd(x0(7))*sind(x0(8)));
Izy_x = 0;
Ixz_y = 6*(r/l)^2 - 1;
Iyx_z = 1 - 6*(r/l)^2;

A = [0,      x0(6), -x0(5), 0,           -x0(3),                    x0(2),                    phi_u,                                            theta_u,                                                       psi_u, -u0(1)/((x0(10))^2),     0;... % u_dot
    -x0(6),  0,      x0(4), x0(3),        0,                       -x0(1),                    phi_v,                                            theta_v,                                                       psi_v, -u0(2)/((x0(10))^2),     0;...  % v_dot
     x0(5), -x0(4),  0,    -x0(2),        x0(1),                    0,                       -g*sind(x0(7))*cosd(x0(8)),                       -g*cosd(x0(7))*sind(x0(8)),                                     0,     -u0(3)/((x0(10))^2),     0;...  % w_dot % done
     0,      0,      0,     0,           -x0(6)*Izy_x,             -x0(5)*Izy_x,              0,                                                0,                                                             0,      0,                      0;...  % p_dot
     0,      0,      0,    -x0(6)*Ixz_y,  0,                       -x0(4)*Ixz_y,              0,                                                0,                                                             0,     -6*u0(3)/(l*(x0(10)^2)), 0;...  % q_dot
     0,      0,      0,    -x0(5)*Iyx_z, -x0(4)*Iyx_z,              0,                        0,                                                0,                                                             0,     -6*u0(2)/(l*(x0(10)^2)), 0;...  % r_dot
     0,      0,      0,     1,            sind(x0(7))*tand(x0(8)),  cosd(x0(7))*tand(x0(8)), (x0(5)*cosd(x0(7))-x0(6)*sind(x0(7)))*tand(x0(8)), secd(x0(8))^2*(x0(5)*sind(x0(7))+x0(6)*cosd(x0(7))),           0,      0,                      0;...  % phi_dot
     0,      0,      0,     0,            cosd(x0(7)),             -sind(x0(7)),             -x0(6)*cosd(x0(7))-x0(5)*sind(x0(7)),              0,                                                             0,      0,                      0;...  % theta_dot
     0,      0,      0,     0,            sind(x0(7))/cosd(x0(8)),  cosd(x0(7))/cosd(x0(8)), (x0(5)*cosd(x0(7))-x0(6)*sind(x0(7)))/cosd(x0(8)), (x0(5)*sind(x0(7))+x0(6)*cosd(x0(7)))*secd(x0(8))*tand(x0(8)), 0,      0,                      0;...  % psi_dot
     0,      0,      0,     0,            0,                        0,                        0,                                                0,                                                             0,      0,                      0;...  % m_dot
    -1,      0,      0,     0,            0,                        0,                        0,                                                0,                                                             0,      0,                      0];  % z_dot

B = [1/x0(10), 0, 0;...
     0, 1/x0(10), 0;...
     0, 0, 1/x0(10);...
     0, 0, 0;...
     0, 0, 6/(x0(10)*l);...
     0, 6/(x0(10)*l), 0;...
     0, 0, 0;...
     0, 0, 0;... 
     0, 0, 0;...
     -u0(1)/(I_sp*sqrt(u0(1)^2 + u0(2)^2 + u0(3)^2)), -u0(2)/(I_sp*sqrt(u0(1)^2 + u0(2)^2 + u0(3)^2)), -u0(3)/(I_sp*sqrt(u0(1)^2 + u0(2)^2 + u0(3)^2));...
     0, 0, 0]
 
A_fix = A; A_fix(11,:) = [], A_fix(:,11) =[]; A_fix(4,:) = [], A_fix(:,4) =[];
B_fix = B; B_fix(11,:) = []; B_fix(4,:) = []
C = [1, zeros(1,8)]; D = [0,0,0];

Co = ctrb(A_fix,B_fix); % controllability matrix
unco = length(A_fix) - rank(Co) % # of uncontrollable states
if unco == 0; fprintf('The pair (A, B) is controllable \n'); end
Ob = obsv(A_fix, C);
unob = length(A_fix) - rank(Ob)
if unob == 0; fprintf('The pair (A, B) is observable \n'); end

Q = eye(9); R = eye(3);

R(1,1) = .001;     % Fpx
R(2,2) = 100000;   % Fpy
R(3,3) = 100000;   % Fpz

Q(1,1) = 1/.000000000001;     % u
Q(2,2) = 1/.000000000001;       % v
Q(3,3) = 1/.000000001;       % w
Q(4,4) = 1/1000;       % q pitch angular vel (rocket)
Q(5,5) = 1/1000;       % r yaw angular vel
Q(6,6) = 1/100000000;    % phi
Q(7,7) = 1/.1;       % theta
Q(8,8) = 1/.01;       % psi
Q(9,9) = 1/1000000;    % mass

[K] = lqr(A_fix,B_fix,Q,R)

%%
close all
plot(simout.time,simout.signals.values(:,1))
hold on
plot(simout.time,simout.signals.values(:,2))
hold on
plot(simout.time,simout.signals.values(:,3))

plot(simout3.time,simout3.signals.values(:,1))
hold on
plot(simout3.time,simout3.signals.values(:,2))
hold on
plot(simout3.time,simout3.signals.values(:,3))

title('Analog and FPGA Linear Velocities')
legend('axial velocity', 'side y-velocity', 'side z-velocity')
xlabel('time (s)')
ylabel('velocity (m/s)')

% title('Rocket-Frame Linear Velocities')
% legend('axial velocity', 'side y-velocity', 'side z-velocity')
% xlabel('time (s)')
% ylabel('velocity (m/s)')

figure
subplot(3,1,1)
plot(simout.time,simout.signals.values(:,6))
title('Earth-Frame Absolute Orientation-Angles')
ylabel('\phi (\circ)')
xlabel('time (s)')
subplot(3,1,2)
plot(simout.time,simout.signals.values(:,7))
ylabel('\theta (\circ)')
xlabel('time (s)')
subplot(3,1,3)
plot(simout.time,simout.signals.values(:,8))
ylabel('\psi (\circ)')
xlabel('time (s)')

figure
subplot(3,1,1)
plot(simout2.time,simout2.signals.values(:,1))
title('Input Propulsion Forces')
ylabel('Fp_x (N)')
xlabel('time (s)')
subplot(3,1,2)
plot(simout2.time,simout2.signals.values(:,2))
ylabel('Fp_y (N)')
xlabel('time (s)')
subplot(3,1,3)
plot(simout2.time,simout2.signals.values(:,3))
ylabel('Fp_z (N)')
xlabel('time (s)')
