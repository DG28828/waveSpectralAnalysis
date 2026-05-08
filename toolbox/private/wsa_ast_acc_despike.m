function [ast_despike, acceleration, acc_idx] = wsa_ast_acc_despike(ast, fs, g)   

dt = 1/fs;

%Estimación de la aceleración de la señal (segunda derivada)
acc = diff(ast, 2)/dt^2;
acceleration = NaN(size(ast));
acceleration(2:end-1, :) = acc;            %Centrar la señal de aceleración

%Marcar datos con aceleración mayor a g = 9.81m/s^2
acc_idx = abs(acceleration) > g;
ast_despike(acc_idx) = NaN;

end
