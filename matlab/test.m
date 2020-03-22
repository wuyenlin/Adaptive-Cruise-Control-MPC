%clc;
clear all;

T_eng = 0.460;
K_eng = 0.732;
A_f = -1/T_eng;
B_f = -K_eng/T_eng;
C_f = [1 0 0; 0 1 0; 0 0 1];
T_hw = 1.6;
Ts = 0.05;

At = [0 1 -T_hw; 0 0 -1; 0 0 A_f];
Bt = [0; 0; B_f];
sys1 = ss(At,Bt,C_f,0);
sys2 = c2d(sys1,Ts,'zoh');

% ctrbty = ctrb(sys2.A,sys2.B);
% rankctrbty = rank(ctrbty);
% obsrank = rank(obsv(sys2.A,sys2.C));

for i = 1:2:1000
        
    disp(i);
    
    % tweak Q, R with i
    Q = diag([0.0001*i 0.0001*i 0.0001*i]);
    R = 10;
    %
    
    [P,K,L] = idare(sys2.A,sys2.B,Q,R);
    Ad = sys2.A-K*sys2.C;
    sys3 = ss(Ad,sys2.B,K*C_f,0);
    sys3 = c2d(sys3,0.05,'zoh');

    % check if system is observable
    % and if P is SPD (symmetric and positive definite)
    if rank(obsv(sys3)) && issymmetric(P)
        eigenvalue = eig(P);
        if all(eigenvalue > 0)
            fprintf("\nR= \n");
            disp(R);
            fprintf("\nK= \n");
            disp(K);
            fprintf("\nP= \n");
            disp(P);
        end
    end


    % Model definition

    % Define model, cost function, and bounds.
    A = sys3.A;
    B = sys3.B;
    N = 20;

    % Bounds.
    xlb = [0; 0; 15];
    xub = [2; 2.5; 40];
    ulb = -3;
    uub = 5;

    % Find LQR.

    [K, P] = dlqr(A, B, Q, R);
    K = -K; % Sign convention.


    % test
    Nx = size(A, 1);
    [Az, bz] = hyperrectangle([xlb; ulb], [xub; uub]);
    Z = struct('G', Az(:,1:Nx), 'H', Az(:,(Nx + 1):end), 'psi', bz);


    [A_U, b_U] = hyperrectangle(ulb, uub);
    A_lqr = A_U*K;
    b_lqr = b_U;

    % State input
    [A_X, b_X] = hyperrectangle(xlb, xub);
    Acon = [A_lqr; A_X];
    bcon = [b_lqr; b_X];

    % Use LQR-invariant set.
    Xf = struct();
    ApBK = A + B*K; % LQR evolution matrix.
    [Xf.A, Xf.b] = calcOinf(ApBK, Acon, bcon);

    if all(Xf.b>0)
        disp("Found it!")
        break
    end
end
