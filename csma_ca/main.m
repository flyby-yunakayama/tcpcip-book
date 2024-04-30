% clear; 
plot_init;

OfferedLoad = [6 9 12 14 16 18 20 22 24 26 28 30]*1e6;

fprintf('\n');
parfor ni = 1:numel(OfferedLoad)

  [Load, TP, Loss, Retry, NRx] = csma_ca_sim(OfferedLoad(ni), 10);
 
  x(ni,1) = Load;
  y(ni,1) = TP;
  z(ni,1) = Loss;

  fprintf('/');
end
fprintf('\n');

figure(1);
hold on;
plot(x/1e6, y/1e6, 'Color', mycolor('b'), 'Marker', 'o', 'LineWidth', 1.5);
grid on;
xlabel('Offered load [Mbps]');
ylabel('System throughput [Mbps]');

figure(2);
hold on;
plot(x/1e6, z, 'Color', mycolor('b'), 'Marker', 'o', 'LineWidth', 1.5);
grid on;
xlabel('Offered load [Mbps]');
ylabel('Packet loss rate [%]');


fprintf('\n');
parfor ni = 1:numel(OfferedLoad)

  [Load, TP, Loss, Retry, NRx] = csma_ca_sim(OfferedLoad(ni), 70);
 
  x(ni,1) = Load;
  y(ni,1) = TP;
  z(ni,1) = Loss;

  fprintf('/');
end
fprintf('\n');

figure(1);
plot(x/1e6, y/1e6, 'Color', mycolor('r'), 'Marker', 'd', 'LineWidth', 1.5);

figure(2);
plot(x/1e6, z, 'Color', mycolor('r'), 'Marker', 'd', 'LineWidth', 1.5);



