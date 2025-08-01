function main
    % Main program entry point
    disp('Starting CIC filter visualization...');
    cic_filter_with_sliders();
end

function cic_filter_with_sliders
    % Initial parameters
    fs = 1000; % Sampling frequency in Hz
    R = 2; % Initial Length of the moving average filter
    N = 4; % Initial Stages
    M = 1;
    L = 110; % Initial FIR filter order
    fc = fs / (4 * R); % Pass band edge in Hz       
    B = 16;  % Number of bits for fixed-point coefficients
    impulse = [1, zeros(1, 1023)]; % Impulse signal (length 1024)

    % Frequency axis for FFT (normalized to fs)
    f_fft = linspace(-0.5, 0.5, 1024);

    % Create figure
    fig = figure('Name', 'CIC Filter Visualization', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 600]);

    % Add a panel for sliders on the far right
    sliderPanel = uipanel('Parent', fig, 'Title', 'Parameters', 'Position', [0.82, 0.1, 0.16, 0.8]);

    % Slider for R
    uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 280, 100, 20], ...
        'String', 'R (Rate Change)', 'HorizontalAlignment', 'left');
    slider_R = uicontrol('Parent', sliderPanel, 'Style', 'slider', 'Min', 2, 'Max', 128, 'Value', R, ...
        'Position', [10, 260, 140, 20], 'Callback', @updatePlot);
    value_R = uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 240, 140, 20], ...
        'String', sprintf('R = %d', R), 'HorizontalAlignment', 'center');

    % Slider for N
    uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 200, 100, 20], ...
        'String', 'N (CIC Stages)', 'HorizontalAlignment', 'left');
    slider_N = uicontrol('Parent', sliderPanel, 'Style', 'slider', 'Min', 1, 'Max', 10, 'Value', N, ...
        'Position', [10, 180, 140, 20], 'Callback', @updatePlot);
    value_N = uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 160, 140, 20], ...
        'String', sprintf('N = %d', N), 'HorizontalAlignment', 'center');

    % Slider for L
    uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 120, 100, 20], ...
        'String', 'L (FIR Filter Order)', 'HorizontalAlignment', 'left');
    slider_L = uicontrol('Parent', sliderPanel, 'Style', 'slider', 'Min', 10, 'Max', 200, 'Value', L, ...
        'Position', [10, 100, 140, 20], 'Callback', @updatePlot);
    value_L = uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 80, 140, 20], ...
        'String', sprintf('L = %d', L), 'HorizontalAlignment', 'center');

    % Initial plot
    updatePlot();

    function updatePlot(~, ~)
        % Get slider values
        R = round(get(slider_R, 'Value'));
        N = round(get(slider_N, 'Value'));
        L = round(get(slider_L, 'Value'));

        % Update text displays
        set(value_R, 'String', sprintf('R = %d', R));
        set(value_N, 'String', sprintf('N = %d', N));
        set(value_L, 'String', sprintf('L = %d', L));

        % FIR2 parameters
        fc = fs / (4 * R);
        Fo = fc / fs;
        p = 2e3;
        s = 0.25 / p;
        fpass = 0:s:Fo;
        fstop = (Fo + s):s:0.5;
        f = [fpass fstop] * 2;
        Mp = ones(1, length(fpass));
        Mp(2:end) = (abs(M * R * sin(pi * fpass(2:end) / R) ./ sin(pi * M * fpass(2:end))).^(N));
        Mf = [Mp zeros(1, length(fstop))];
        f(end) = 1;

        % Design FIR compensator
        h = fir2(L, f, Mf);
        output_fir = filter(h, 1, impulse);
        
        % Frequency response
        H = fft(output_fir, 1024);
        H = fftshift(H);

        % CIC filter coefficients
        cic = ones(1, R) / R;

        % Output of moving average filter N times
        output_cic = filter(cic, 1, impulse);
        for i = 1:N - 1
            output_cic = filter(cic, 1, output_cic);
        end

        % FFT of CIC filter
        fft_cic = fft(output_cic, 1024);
        fft_cic = fftshift(fft_cic);
        
        % Total filter Response
        total = filter(cic, 1, impulse);
        total = filter(h, 1, total);
        total_fft = fft(total, 1024);
        total_fft = fftshift(total_fft);

        % Convert magnitude response to dB
        magnitude_fft_cic_dB = 20 * log10(abs(fft_cic));
        magnitude_H_dB = 20 * log10(abs(H));
        magnitude_total_dB = 20*log10(abs(total_fft));

        % Prevent -Inf for zero values by setting a minimum value
        lim_dB = -150;
        magnitude_fft_cic_dB(magnitude_fft_cic_dB < lim_dB) = lim_dB;
        magnitude_H_dB(magnitude_H_dB < lim_dB) = lim_dB;
        magnitude_total_dB(magnitude_total_dB < lim_dB) = lim_dB;

        % Clear figure and plot results
        subplot(2, 1, 1, 'Parent', fig, 'Position', [0.1, 0.55, 0.7, 0.4]);
        plot(f_fft, (magnitude_fft_cic_dB), 'b', 'LineWidth', 1.5, 'DisplayName', 'CIC Averaging Filter');
        hold on;
        plot(f_fft, (magnitude_H_dB), 'r', 'LineWidth', 1.5, 'DisplayName', 'FIR Compensation Filter');
        hold on;
        plot(f_fft, (magnitude_total_dB), 'g', 'LineWidth', 1.5, 'DisplayName', 'Total Filter Response');
        xline(1 / R, 'ko', 'LineWidth', 1.5, 'DisplayName', 'New Sampling Rate');
        xline(0.5 / R, 'k--', 'LineWidth', 1.5, 'DisplayName', 'New Nyquist Rate');
        hold off;
        legend('show');
        title('Magnitude Response');
        xlabel('Normalized Frequency (f/fs)');
        ylabel('Magnitude [dB]');
        grid on;

        subplot(2, 1, 2, 'Parent', fig, 'Position', [0.1, 0.1, 0.7, 0.35]);
        plot(f_fft, unwrap(angle(fft_cic)), 'b', 'LineWidth', 1.5, 'DisplayName', 'CIC Phase');
        hold on;
        plot(f_fft, unwrap(angle(H)), 'r', 'LineWidth', 1.5, 'DisplayName', 'FIR Phase');
        hold off;
        legend('show');
        title('Phase Response');
        xlabel('Normalized Frequency (f/fs)');
        ylabel('Phase [radians]');
        grid on;

      % Display for additional calculated values
        newSampleRate = uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 440, 140, 20], ...
            'String', sprintf('New sample rate: %.3f*fs', 1 / R), 'HorizontalAlignment', 'left');
        newNyquistRate = uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 420, 140, 20], ...
            'String', sprintf('New Nyquist rate: %.3f*fs', 1 / (2 * R)), 'HorizontalAlignment', 'left');
        firCutoff = uicontrol('Parent', sliderPanel, 'Style', 'text', 'Position', [10, 400, 140, 20], ...
            'String', sprintf('FIR Cutoff: %.3f*fs', fc/fs), 'HorizontalAlignment', 'left');

        h = h/max(h); %% Floating point coefficients

        % Normalize the coefficients to fit within fixed-point representation
        coefficients_fixed = round(h * 2^(B-1)); % Scale to Q15 format

        % Create the COE file
        coe_filename = 'comp_FIR_for_CIC.coe';
        fid = fopen(coe_filename, 'w');
        
        % Write header information
        fprintf(fid, '; FIR Lowpass Filter Coefficients\n');
        fprintf(fid, '; Generated by MATLAB\n\n');
        fprintf(fid, 'Radix = 10;\n'); % Radix for coefficients (decimal)
        fprintf(fid, 'Coefficient_Depth = %d;\n', length(coefficients_fixed));
        fprintf(fid, 'Coefficient_Width = 16;\n\n'); % 16-bit coefficients
        fprintf(fid, 'CoefData = \n');
        
        % Write coefficients
        for i = 1:length(coefficients_fixed)
            if i == length(coefficients_fixed)
                fprintf(fid, '%d;\n', coefficients_fixed(i)); % Last coefficient
            else
                fprintf(fid, '%d,\n', coefficients_fixed(i)); % Other coefficients
            end
        end
        
        % Close the file
        fclose(fid);
    end
end