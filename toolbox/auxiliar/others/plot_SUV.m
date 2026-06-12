function  plot_SUV(t, S, U, V)
    f = figure; 
    subplot(3, 1, 1);
    plot(t, S, 'LineWidth', 1.2, 'Color', 'red');
    yl = ylabel('\eta (m)'); yl.FontSize = 12;
    %legend('\eta')
    
    subplot(3, 1, 2);
    plot(t, U, 'LineWidth', 1.5, 'Color', 'blue');
    %legend('U')
    yl = ylabel('U (m/s)');
    yl.FontSize = 12;
    
    subplot(3, 1, 3);
    plot(t, V, 'LineWidth', 1.5, 'Color', 'green');
    yl = ylabel('V (m/s)');
    %legend('V')
    xl = xlabel('t (s)');
    yl.FontSize = 12;
    xl.FontSize = 12;
    f.Position = [100 100 1200 400];
end