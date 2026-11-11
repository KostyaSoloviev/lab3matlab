function DrawBERAndFER(DirName)
% Функция прорисовки кривых BER и PER (Packet Error Rate) для Варианта 2 (QPSK 3/4)

    if nargin == 0
        DirName = 'Results';
    end

    Listing = dir(DirName);
    Names = cell(0);
    for k = 1:length(Listing)
        if ~Listing(k).isdir
            FName = Listing(k).name;
            if length(FName) > 4 && isequal(FName(end-3:end), '.mat')
                Names{end+1} = FName(1:end-4); %#ok<AGROW>
            end
        end
    end

    if isempty(Names)
        error('Не найдены файлы с результатами!');
    end

    f  = cell(2, 1);
    ax = cell(2, 1);
    for k = 1:2
        f{k} = figure('Color', 'w');
        ax{k} = axes;
    end

    for k = 1:length(Names)
        load(fullfile(DirName, [Names{k}, '.mat']), 'Res');
        figure(f{1});
            hold on;
            plot(Res.h2dBs, Res.NumErBits ./ Res.NumTrBits, ...
                '-o', 'LineWidth', 1.5, 'MarkerSize', 6);
        figure(f{2});
            hold on;
            plot(Res.h2dBs, Res.NumErFrames ./ Res.NumTrFrames, ...
                '-o', 'LineWidth', 1.5, 'MarkerSize', 6);
    end

    % Референсная кривая DVB-S2 для Варианта 2: QPSK, R_LDPC = 3/4 (слайд 21)
    refEsN0_QPSK_3_4 = [3.75,  3.85,   3.91,   3.95,    4.00,   4.03];
    refPER_QPSK_3_4  = [1e-1,  2.5e-2, 2.8e-3, 4.2e-5,  3.0e-6, 3.0e-7];

    figure(f{1});
        grid on;
        set(ax{1}, 'YScale', 'log');
        title('BER (QPSK, R_{LDPC} = 3/4, \beta = 0.20, pilots = on)');
        xlabel('{\itE_s}/{\itN}_0 (dB)');
        ylabel('Bit Error Rate (BER)');
        legend(Names, 'Interpreter', 'none', 'Location', 'southwest');

    figure(f{2});
        hold on;
        plot(refEsN0_QPSK_3_4, refPER_QPSK_3_4, '--ks', ...
            'LineWidth', 1.5, 'MarkerFaceColor', 'k', 'MarkerSize', 6);
        grid on;
        set(ax{2}, 'YScale', 'log');
        ylim([1e-7, 1]);
        xlim([3.0, 4.5]);
        title('PER (Вариант 2: QPSK, R_{LDPC} = 3/4, \beta = 0.20, pilots = on)');
        xlabel('{\itE_s}/{\itN}_0 (dB)');
        ylabel('Packet Error Rate (PER)');
        legend([Names, {'Референс DVB-S2 (QPSK 3/4)'}], ...
            'Interpreter', 'none', 'Location', 'southwest');
end