function [coeffs, info] = wsa_puvcoeffs(eta, u, v)



DoF = 16;
ventana = "hann";    
K = DoF/2;
Nfft = 2^nextpow2(5*(2*length(eta)/(K+1)));

[Spp, W, info_psdwb] = wsa_psdwb(eta, ventana, 'K', K, 'Nfft', Nfft);
Suu = wsa_psdwb(u, ventana, 'K', K, 'Nfft', Nfft);
Svv = wsa_psdwb(v, ventana, 'K', K, 'Nfft', Nfft);
Spu = wsa_psdwb(eta, ventana,'Y',u, 'K', K, 'Nfft', Nfft);
Spv = wsa_psdwb(eta, ventana,'Y',v, 'K', K, 'Nfft', Nfft);
Suv = wsa_psdwb(u, ventana,'Y',v, 'K', K, 'Nfft', Nfft);

C11 = real(Spp);
C22 = real(Suu);
C33 = real(Svv);
C23 = real(Suv);
Q12 = imag(Spu);
Q13 = imag(Spv);

a1 = Q12./sqrt(C11.*(C22+C33));
a2 = Q13./sqrt(C11.*(C22+C33));
b1 = (C22-C33)./(C22+C33);
b2 = 2*C23./(C22+C33);