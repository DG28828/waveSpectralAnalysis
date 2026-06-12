function plot_DirSpec(f, theta, E, xdir_out, DirMethod)

[X, Y] = meshgrid(theta, f);
surf(X, Y, E);
shading interp
xl = xlabel('\theta (°)');
yl = ylabel('f (Hz)');
zl = zlabel('S(f, \theta) (m^2/Hz/°)');
xlim([0, 360])
view(90, 90)
colorbar
xticks([0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 360]);
xticklabels({'0', '30', '60', '90', '120', '150', '180', '210', '240', '270', '300', '330', '360'});
set(gca, 'XDir', xdir_out)
tit = title(['S(f, \theta);   ', DirMethod]);
tit.FontSize = 14;
xl.FontSize = 12; yl.FontSize = 12; zl.FontSize = 12;

end