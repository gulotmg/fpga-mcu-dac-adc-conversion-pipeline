clc; clearvars; clear

% Configuration: 8-bit resolution and sample count
bits = 8;
maxval = 2^bits - 1;    
samples = 2^bits;        

% Sample indices and normalized time over one period [0,1)
n = 0:(samples-1);
t = n / samples;

% TRIANGLE
tri_unit = zeros(size(t));
rising = t < 0.5;
tri_unit(rising) = 2 * t(rising);          % 0..1
tri_unit(~rising) = 2 * (1 - t(~rising));  % 1..0
y = round(tri_unit * maxval);
y = min(max(double(y), 0), maxval);
figure;
plot(n,y);
title('Triangle Wave Sampled Values');
xlabel('Sample Index');
ylabel('Amplitude');
fid = fopen('coefficients_trig.txt','w');
fprintf(fid,'memory_initialization_radix = 10;\nmemory_initialization_vector =\n(');
for i = 1:samples
    if i == samples
        fprintf(fid,'%d);', y(i));
    else
        fprintf(fid,'%d, ', y(i));
    end
    if mod(i,16)==0, fprintf(fid,'\n'); end
end
fclose(fid);

% SINE
sine_unit = 0.5 * (1 + sin(2*pi*n/samples));  % periodic on the sampled grid
y = round(sine_unit * maxval);
y = min(max(double(y), 0), maxval);
figure;
plot(n,y);
title('Sine Wave Sampled Values');
xlabel('Sample Index');
ylabel('Amplitude');
fid = fopen('coefficients_sin.txt','w');
fprintf(fid,'memory_initialization_radix = 10;\nmemory_initialization_vector =\n('); 

for i = 1:samples
    if i == samples
        fprintf(fid,'%d);', y(i));
    else
        fprintf(fid,'%d, ', y(i));
    end
    if mod(i,16)==0, fprintf(fid,'\n'); end
end
fclose(fid);

% SAWTOOTH
saw_vals = linspace(0, maxval, samples + 1); % includes both endpoints
saw_vals(end) = [];                           % drop duplicated endpoint
y = round(saw_vals);                          
y = min(max(double(y), 0), maxval);
y(end) = 0; % wrap
figure;
plot(n,y);
title('Sawtooth Wave Sampled Values');
xlabel('Sample Index');
ylabel('Amplitude');
fid = fopen('coefficients_saw.txt','w');
fprintf(fid,'memory_initialization_radix = 10;\nmemory_initialization_vector =\n(');
for i = 1:samples
    if i == samples
        fprintf(fid,'%d);', y(i));
    else
        fprintf(fid,'%d, ', y(i));
    end
    if mod(i,16)==0, fprintf(fid,'\n'); end
end
fclose(fid);

disp("DONE");
