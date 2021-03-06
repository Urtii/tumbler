%% System Model

g = 9.807; %m/s^2 earth gravitional acceleration

%pendulum lenght variables
l_b = 0.207; %m pendulum lenght
l_m = l_b; %motor distance to origin
l_R = l_b; %center off mass distance of wheel to origin

%pendulum mass calculation
b_p = 0.020; %m pendulum arm depth
a_p = 0.030; %m pendulum arm width
d_p = 940; %kg/m^3 UHMW density (pendulum material)
M_b = a_p * b_p * l_b * d_p; %kg pendulum weight

%reaction wheel mass calculation
R_r = 0.105; %m wheel radius
a_r = 0.010; %m wheel support width
b = 0.005; %m wheel thickness
t_r = 0.019; %m wheel inner radius
d_r = 7870; %kg/m^3 steel wheel density
M_R = ((pi * (R_r^2 - t_r^2)) + 3*(t_r * a_r))* b * d_r; %kg wheel weight

%motor parameters
k_e = 0.4105; %Vs motor velocity constant
k_t = 0.3568; %Nm/A motor torque constant
R = 2.5; %ohm motor resistance
M_m = 0.205; %kg 24V pololu motor with encoder

%inertia calculations
I_bo = M_b*l_b^2; %kg*m^2 pendulum inertia wrt origin
I_ro = M_R*l_R^2; %kg*m^2 wheel inertia wrt origin
I_mo = M_m*l_m^2; %kg*m^2 motor inertia wrt origin
I_R = 1/2*M_R*(R_r^2+t_r^2); %kg*m^2 wheel inertia wrt motor shaft

%other variables
k_mgl = (M_b*l_b + M_m*l_m + M_R*l_R)*g; %kg*m^2/s^2 mass-gravity-length constant
I_so = I_bo + I_ro + I_mo;  %kg*m^2 total inertia wrt origin
b_R = 7.74*10^-4; %N*m*s motor friction
b_b = b_R/10; %no data given so motor friction used instead

%State Matrices
% x = [theta, d_theta, w_R]'
A_cont = [0,             1,              0;
     k_mgl/I_so,    -b_b/I_so,      (k_t*k_e)/(R*I_so)+b_R/I_so;
     -k_mgl/I_so,   b_b/I_so,       (I_so+I_R)*(b_R+((k_t*k_e)/(R)))/(I_so*I_R)];

B_cont = [0; -k_t/(R*I_so); ((I_so+I_R)*k_t)/(I_so*I_R*R)];

C_cont = [1, 0.01, 0];

D_cont = [0];

%system declarations
sys = ss(A_cont,B_cont,C_cont,D_cont);
Ts = 0.01;
sys_disc = c2d(sys,Ts);
[A,B,C,D] = ssdata(sys_disc);

start_angle = -20 * 2*pi / 360; %start from 5 degrees
x0 = [start_angle;0;0];
% Optimal control solution for N = 8
G = [zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1);
     B          zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1);
     A*B        B          zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1);
     A^2*B      A*B        B          zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1);
     A^3*B      A^2*B      A*B        B          zeros(3,1) zeros(3,1) zeros(3,1) zeros(3,1);
     A^4*B      A^3*B      A^2*B      A*B        B          zeros(3,1) zeros(3,1) zeros(3,1);
     A^5*B      A^4*B      A^3*B      A^2*B      A*B        B          zeros(3,1) zeros(3,1);
     A^6*B      A^5*B      A^4*B      A^3*B      A^2*B      A*B        B          zeros(3,1);
     A^7*B      A^6*B      A^5*B      A^4*B      A^3*B      A^2*B      A*B        B];
H = [eye(3); A; A^2; A^3; A^4; A^5; A^6; A^7; A^8];
Q = C'*C;
R = [0.01];
%Q = eye(3);
Pinf = idare(A,B,Q,R,zeros(3,1),eye(3) );
Kinf = inv(R+B'*Pinf*B)*B'*Pinf*A;
% A*X*A' - X + Q = 0;  X = dlyap(A,Q)
P = dlyap( (A-B*Kinf)',Q+Kinf'*R*Kinf);
Qf = P;
Qbar = blkdiag(Q,Q,Q,Q,Q,Q,Q,Q,Qf);
Rbar = blkdiag(R,R,R,R,R,R,R,R);
M = G'*Qbar*G + Rbar;
% input bound: umin <= u <= umax
u1min = -24;
u1max = 24;
lb = [u1min;u1min;u1min;u1min;u1min;u1min;u1min;u1min];
ub = [u1max;u1max;u1max;u1max;u1max;u1max;u1max;u1max];
% Apply MPC steps
xVec(:,1) = x0;
yVec(1) = C*x0;
uVec = [0];
for kk = 1:250
    alpha = G'*Qbar'*H*xVec(:,kk);
    Usol = quadprog(M,alpha',[],[],[],[],lb,ub);
    uVec(:,kk) = [Usol(1)];
    xVec(:,kk+1) = A*xVec(:,kk) + B*uVec(:,kk);
    yVec(kk+1) = C*xVec(:,kk+1);
    Xsol(:,1) = xVec(:,kk);
    Xsol(:,2) = A*Xsol(:,1) + B*[Usol(1)];
    Xsol(:,3) = A*Xsol(:,2) + B*[Usol(1)];
    Xsol(:,4) = A*Xsol(:,3) + B*[Usol(1)];
    Ysol(1) = C*Xsol(:,1);
    Ysol(2) = C*Xsol(:,2);
    Ysol(3) = C*Xsol(:,3);
    Ysol(4) = C*Xsol(:,4);
end


uVec = [uVec uVec(:,end)];
tVec = [0:Ts:250*Ts];
% figure;
figure, subplot(3,1,1)
stairs(tVec,uVec(1,:),'LineWidth',2);
hold all;
xlabel('time [sec]')
grid
ylabel('u0')
title('Input u0')
subplot(3,1,2)
stairs(tVec,uVec(1,:),'LineWidth',2)
hold all;
grid
xlabel('time [sec]')
ylabel('u1')
title('Input u1')
subplot(3,1,3)
stairs(tVec,C*xVec,'LineWidth',2)
hold all;
grid
xlabel('time [sec]')
ylabel('y')
title('Output y')


figure, subplot(3,1,1)
stairs(tVec,[1 0 0]*xVec,'LineWidth',2)
hold all;
grid
xlabel('time [sec]')
ylabel('x')
title('Pendulum Angle (Rad)')
subplot(3,1,2)
stairs(tVec,[0 1 0]*xVec,'LineWidth',2)
hold all;
grid
xlabel('time [sec]')
ylabel('theta')
title('Pendulum Angular Velocity (Rad/s)')
subplot(3,1,3)
stairs(tVec,[0 0 1]*xVec,'LineWidth',2)
hold all;
grid
xlabel('time [sec]')
ylabel('alpha')
title('Reaction Wheel Velocity (Rad/s)')
set(findall(gcf,'Type','line'),'LineWidth',2)
set(findall(gcf,'-property','FontSize'),'FontSize',14);
% legend('$u_{max} = 1.5$','$u_{max} = 2.5$','$u_{max} = 4$')
