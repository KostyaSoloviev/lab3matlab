classdef ClassSig < handle
    properties (SetAccess = private)
        isTransparent;
        HasPilots;
        MODCOD;
        ModulationOrder;
        RollOff;
        FilterSpan;
        sps;
        ScramblerIndex;
        LogLanguage;

        SOFBits;         % 26 бит SOF (0x18D2E82)
        PLSScrambleSeq;  % 64 бита скремблирования PLS
        RM32_6_Codebook; % Таблица всех 64 кодовых слов кода RM(32,6)
        PLHeaderSymbols; % 90 символов заголовка PLHEADER
        GoldSeq;         % Комплексная последовательность Голда c_k
        RRCFilter;       % Коэффициенты фильтра корень из приподнятого косинуса
        NumSlots;        % Количество слотов данных S в XFECFRAME
        NumPilotBlocks;  % Количество пилотных блоков
        PLFrameLength;   % Полная длина PLFRAME в символах
    end
    methods
        function obj = ClassSig(Params, LogLanguage)
            S = Params.Sig;
            obj.isTransparent   = S.isTransparent;
            obj.HasPilots       = S.HasPilots;
            obj.MODCOD          = S.MODCOD;
            obj.ModulationOrder = S.ModulationOrder;
            obj.RollOff         = S.RollOff;
            obj.FilterSpan      = S.FilterSpanInSymbols;
            obj.sps             = S.SamplesPerSymbol;
            obj.ScramblerIndex  = S.ScramblerIndex;
            obj.LogLanguage     = LogLanguage;

            % 1. SOF (26 бит: 0x18D2E82) и скремблирующая последовательность PLS (64 бита)
            obj.SOFBits = de2bi(hex2dec('18D2E82'), 26, 'left-msb').';
            plsScrStr = '0111000110011101100000111100100101010011010000100010110111111010';
            obj.PLSScrambleSeq = (plsScrStr.' - '0');

            % 2. Порождающая матрица G (6x32) кода RM(32,6) и таблица 64 кодовых слов
            G = [repmat([0 1], 1, 16);
                 repmat([0 0 1 1], 1, 8);
                 repmat([zeros(1,4) ones(1,4)], 1, 4);
                 repmat([zeros(1,8) ones(1,8)], 1, 2);
                 [zeros(1,16) ones(1,16)];
                 ones(1, 32)];
            info6 = de2bi(0:63, 6, 'left-msb');
            obj.RM32_6_Codebook = mod(info6 * G, 2); % [64 x 32]

            % 3. Формирование 90 символов PLHEADER для текущего MODCOD и TYPE
            % TYPE (2 бита): b6 = 0 (normal frame 64800), b7 = HasPilots
            b1_5 = de2bi(obj.MODCOD, 5, 'left-msb');
            b6   = 0;
            b7   = double(obj.HasPilots);
            y32  = mod([b1_5, b6] * G, 2);
            plsUnscrambled = reshape([y32; xor(y32, b7)], 64, 1);
            plsBits = double(xor(plsUnscrambled, obj.PLSScrambleSeq));
            headerBits = [obj.SOFBits; plsBits]; % 90 бит

            % Модуляция pi/2-BPSK
            obj.PLHeaderSymbols = zeros(90, 1);
            for i = 1:45
                % Нечётные индексы (2i-1): (1/sqrt(2))*(1-2y) * (1 + j)
                b_odd = headerBits(2*i - 1);
                obj.PLHeaderSymbols(2*i - 1) = (1 - 2*b_odd)/sqrt(2) * (1 + 1i);
                % Чётные индексы (2i): (1/sqrt(2))*(1-2y) * (-1 + j)
                b_even = headerBits(2*i);
                obj.PLHeaderSymbols(2*i) = (1 - 2*b_even)/sqrt(2) * (-1 + 1i);
            end

            % 4. Расчёт структуры слотов и пилотов для normal FECFRAME
            numXFECSymbols = 64800 / log2(obj.ModulationOrder);
            obj.NumSlots = numXFECSymbols / 90;
            if obj.HasPilots
                obj.NumPilotBlocks = floor((obj.NumSlots - 1) / 16);
            else
                obj.NumPilotBlocks = 0;
            end
            obj.PLFrameLength = 90 + numXFECSymbols + 36 * obj.NumPilotBlocks;

            % 5. Генерация комплексной скремблирующей последовательности Голда
            obj.GoldSeq = obj.generateGoldSequence(obj.PLFrameLength - 90, obj.ScramblerIndex);

            % 6. Импульсная характеристика корневого фильтра Найквиста (RRC)
            obj.RRCFilter = rcosdesign(obj.RollOff, obj.FilterSpan, obj.sps, 'sqrt');
        end

        function TxSignal = StepTx(obj, XFECFrame)
            if obj.isTransparent
                TxSignal = XFECFrame;
                return;
            end

            % 1. Вставка пилотных блоков (по 36 символов (1+1i)/sqrt(2) через каждые 16 слотов)
            if obj.HasPilots
                pilotBlock = ones(36, 1) * (1 + 1i) / sqrt(2);
                payloadWithPilots = zeros(obj.PLFrameLength - 90, 1);
                srcIdx = 1;
                dstIdx = 1;
                for blk = 1:obj.NumPilotBlocks
                    chunk = 16 * 90;
                    payloadWithPilots(dstIdx : dstIdx + chunk - 1) = XFECFrame(srcIdx : srcIdx + chunk - 1);
                    dstIdx = dstIdx + chunk;
                    srcIdx = srcIdx + chunk;
                    payloadWithPilots(dstIdx : dstIdx + 35) = pilotBlock;
                    dstIdx = dstIdx + 36;
                end
                remSyms = length(XFECFrame) - srcIdx + 1;
                payloadWithPilots(dstIdx : end) = XFECFrame(srcIdx : srcIdx + remSyms - 1);
            else
                payloadWithPilots = XFECFrame;
            end

            % 2. PL-скремблирование всех символов после PLHEADER
            scrambledPayload = payloadWithPilots .* obj.GoldSeq;
            PLFrame = [obj.PLHeaderSymbols; scrambledPayload];

            % 3. Формирующая фильтрация RRC с повышением частоты дискретизации в sps раз
            % Дописываем нули в конец для проталкивания групповой задержки фильтра
            delay = obj.FilterSpan * obj.sps;
            TxSignal = upfirdn([PLFrame; zeros(obj.FilterSpan, 1)], obj.RRCFilter, obj.sps, 1);
            TxSignal = TxSignal(1 : obj.PLFrameLength * obj.sps + delay);
        end

        function [RxXFECFrame, DecodedPLS] = StepRx(obj, RxSignal)
            if obj.isTransparent
                RxXFECFrame = RxSignal;
                DecodedPLS = struct('MODCOD', obj.MODCOD, 'HasPilots', obj.HasPilots);
                return;
            end

            % 1. Согласованная фильтрация RRC и децимация в sps раз
            rxFiltered = upfirdn(RxSignal, obj.RRCFilter, 1, obj.sps);
            % Снятие отсчётов с учётом суммарной задержки приёмопередающего RRC тракта (FilterSpan символов)
            startSym = obj.FilterSpan + 1;
            RxPLFrame = rxFiltered(startSym : startSym + obj.PLFrameLength - 1);

            % 2. Выделение и декодирование PLHEADER (первые 90 символов)
            rxHeaderSyms = RxPLFrame(1:90);
            rxPLSSyms    = rxHeaderSyms(27:90); % 64 символа PLS

            % Демодуляция pi/2-BPSK: чётные (в 0-индексации: 1,3,5.. в MATLAB) и нечётные
            L_pls = zeros(64, 1);
            L_pls(1:2:63) =  real(rxPLSSyms(1:2:63) * exp(-1i*pi/4));
            L_pls(2:2:64) = -real(rxPLSSyms(2:2:64) * exp( 1i*pi/4));

            % Дескремблирование мягких оценок PLS
            L_tilde = (1 - 2*obj.PLSScrambleSeq) .* L_pls;

            % Определение младшего бита b7 (наличие пилотов)
            L_even = L_tilde(1:2:63);
            L_odd  = L_tilde(2:2:64);
            S_val  = sum(L_even .* L_odd);
            b7_hat = double(S_val < 0);

            % Объединение пар мягких оценок (32 оценки для декодера RM(32,6))
            if b7_hat == 0
                L_prime = L_even + L_odd;
            else
                L_prime = L_even - L_odd;
            end

            % Корреляционное декодирование RM(32,6) перебором 64 кодовых слов
            metrics = (1 - 2*obj.RM32_6_Codebook) * L_prime;
            [~, bestIdx] = max(metrics);
            b1_6_hat = de2bi(bestIdx - 1, 6, 'left-msb');
            DecodedPLS.MODCOD    = bi2de(b1_6_hat(1:5), 'left-msb');
            DecodedPLS.FrameType = b1_6_hat(6);
            DecodedPLS.HasPilots = logical(b7_hat);

            % 3. PL-дескремблирование (умножение на комплексно-сопряжённую последовательность Голда)
            rxPayload = RxPLFrame(91:end) .* conj(obj.GoldSeq);

            % 4. Удаление пилотных блоков (по 36 символов после каждых 16 слотов = 1440 символов)
            if obj.HasPilots
                numXFECSyms = obj.NumSlots * 90;
                RxXFECFrame = zeros(numXFECSyms, 1);
                srcIdx = 1;
                dstIdx = 1;
                for blk = 1:obj.NumPilotBlocks
                    chunk = 16 * 90;
                    RxXFECFrame(dstIdx : dstIdx + chunk - 1) = rxPayload(srcIdx : srcIdx + chunk - 1);
                    dstIdx = dstIdx + chunk;
                    srcIdx = srcIdx + chunk + 36; % Пропускаем 36 пилотных символов
                end
                remSyms = numXFECSyms - dstIdx + 1;
                RxXFECFrame(dstIdx : end) = rxPayload(srcIdx : srcIdx + remSyms - 1);
            else
                RxXFECFrame = rxPayload;
            end
        end
    end

    methods (Static)
        function c = generateGoldSequence(len, nShift)
            % Генерация комплексной скремблирующей последовательности Голда по стандарту DVB-S2
            N = 2^18 - 1;
            x = zeros(N, 1); x(1) = 1;
            y = ones(N, 1);
            for i = 1:(N - 18)
                x(i + 18) = xor(x(i + 7), x(i));
                y(i + 18) = xor(xor(y(i + 10), y(i + 7)), xor(y(i + 5), y(i)));
            end
            idx0 = (0 : len - 1).';
            zn1 = xor(x(mod(idx0 + nShift, N) + 1), y(idx0 + 1));
            zn2 = xor(x(mod(idx0 + nShift + 131072, N) + 1), y(mod(idx0 + 131072, N) + 1));
            Rn  = 2 * double(zn2) + double(zn1);
            c   = exp(1i * (pi/2) * Rn);
        end
    end
end