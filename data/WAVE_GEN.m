clc; clearvars; clear

% Configuration: 12-bit resolution and sample count
bits = 8;
maxval = 2^bits - 1;    % 4095
samples = 2^bits;         % 4096 samples (one period)

% Sample indices and normalized time over one period [0,1)
n = 0:(samples-1);
t = n / samples;

% Choose waveform: 'tri' (triangular), 'sin' (sinusoidal), or 'saw' (sawtooth)
waveformType = 'tri'; % options: 'tri', 'sin', 'saw'

switch lower(waveformType)
    case 'tri'
        % Symmetric triangular wave spanning 0..maxval.
        % Use a piecewise linear construction to produce exact 0..1 triangle.
        % For t in [0,0.5) rises from 0 to 1; for t in [0.5,1) falls from 1 to 0.
        tri_unit = zeros(size(t));
        rising = t < 0.5;
        tri_unit(rising) = 2 * t(rising);          % 0..1
        tri_unit(~rising) = 2 * (1 - t(~rising));  % 1..0
        y = round(tri_unit * maxval);
        fid = fopen('coefficients_trig.coe','w');
    case 'sin'
        % Sinusoidal wave mapped from [-1,1] to [0,1], then to integer range.
        sine_unit = 0.5 * (1 + sin(2*pi*n/samples));  % periodic on the sampled grid
        y = round(sine_unit * maxval);
        fid = fopen('coefficients_sin.coe','w');
    case 'saw'
        % Sawtooth wave that rises linearly from 0 to maxval and wraps to 0 at the end.
        % Create samples that span 0..maxval exactly once, with the last sample = 0.
        % Use linspace to generate samples including maxval then wrap the final value to 0.
        saw_vals = linspace(0, maxval, samples + 1); % includes both endpoints
        saw_vals(end) = [];                           % drop the duplicated endpoint so we have 'samples' values 0..maxval-1..maxval
        y = round(saw_vals);                          % integer values, 0..maxval
        % Ensure no value exceeds maxval and cast to double
        y = min(max(double(y), 0), maxval);
        % Force wrap: set final sample to 0 to create the jump back to zero at period boundary
        y(end) = 0;
        fid = fopen('coefficients_saw.coe','w');
    otherwise
        error('Unsupported waveformType. Use ''tri'', ''sine'', or ''saw''.');
end

% Ensure values are integers within 0..maxval and of double type for downstream usage
y = min(max(double(y), 0), maxval);

plot(n,y);
title('Wave Sampled Values');
xlabel('Sample Index');
ylabel('Amplitude');

fprintf(fid,'memory_initialization_radix = 10;\nmemory_initialization_vector =\n');

for i = 1:samples
    if i == samples
        fprintf(fid,'%d;', y(i));
    else
        fprintf(fid,'%d,', y(i));
    end
    if mod(i,8)==0, fprintf(fid,'\n'); end
end

fclose(fid);

disp("DONE");