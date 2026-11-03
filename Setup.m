% Вариант 2 (Команда 2): QPSK, R_LDPC = 3/4, beta = 0.20, pilots = on
Mapper.Type = 'QPSK';
Mapper.ModulationOrder = 4;
Encoder.isTransparent = false;
Encoder.CodeRate = '3/4';
Interleaver.isTransparent = true; % Для QPSK перемежение отключено
Sig.isTransparent = false;
Sig.RollOff = 0.20;
Sig.HasPilots = true;
Sig.FilterSpanInSymbols = 10;
Sig.SamplesPerSymbol = 4;
Channel.isTransparent = false;

% Настройка сетки Es/N0 (дБ) для кривой PER Варианта 2 (водопад 3.6 ... 4.1 дБ)
BER.h2Precision = 2;
BER.h2dBInit = 3.50;
BER.h2dBInitStep = 0.10;
BER.h2dBMaxStep = 0.20;
BER.h2dBMinStep = 0.05;
BER.h2dBMax = 4.20;
BER.MinBER = 1e-6;
BER.MinFER = 1e-4;        % Остановка при достижении PER <= 10^-4
BER.MinNumErBits = 100;
BER.MinNumErFrames = 32;  % Минимум 32 ошибочных MPEG-TS пакета на точку
BER.MinNumTrFrames = 640; % Минимум 20 кадров BBFRAME (640 пакетов MPEG-TS)
BER.MaxNumTrBits = 5e7;