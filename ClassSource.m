classdef ClassSource < handle
    properties (SetAccess = private)
        UPL;
        NumPackets;
        DFL;
        Kbch;
        RollOff;
        LogLanguage;
        PRBSSeq;      % Последовательность BB-скремблирования длины Kbch
        BBHeaderBits; % Заголовок BBHEADER (80 бит)
    end
    methods
        function obj = ClassSource(Params, LogLanguage)
            S = Params.Source;
            obj.UPL         = S.UPL;
            obj.NumPackets  = S.NumPackets;
            obj.DFL         = S.DFL;
            obj.Kbch        = S.Kbch;
            obj.RollOff     = S.RollOff;
            obj.LogLanguage = LogLanguage;

            % Предварительный расчёт последовательности BB-скремблера (1 + X^14 + X^15)
            reg = [1 0 0 1 0 1 0 1 0 0 0 0 0 0 0];
            obj.PRBSSeq = zeros(obj.Kbch, 1);
            for k = 1:obj.Kbch
                p = xor(reg(14), reg(15));
                obj.PRBSSeq(k) = p;
                reg = [p, reg(1:14)];
            end

            % Формирование фиксированного BBHEADER (80 бит) для TS, SIS, CCM
            % MATYPE-1: TS/GS=11, SIS/MIS=1, CCM/ACM=1, ISSYI=0, NPD=0, RO (2 бита)
            if abs(obj.RollOff - 0.35) < 1e-3
                roBits = [0; 0];
            elseif abs(obj.RollOff - 0.25) < 1e-3
                roBits = [0; 1];
            else
                roBits = [1; 0]; % 0.20
            end
            matype1 = [1; 1; 1; 1; 0; 0; roBits];
            matype2 = zeros(8, 1);
            uplBits = de2bi(obj.UPL, 16, 'left-msb').';
            dflBits = de2bi(obj.DFL, 16, 'left-msb').';
            syncBits = de2bi(hex2dec('47'), 8, 'left-msb').'; % 0x47
            syncdBits = zeros(16, 1); % Начало с целого пакета: SYNCD = 0
            header72 = [matype1; matype2; uplBits; dflBits; syncBits; syncdBits];
            crcHeader = obj.calcCRC8(header72);
            obj.BBHeaderBits = [header72; crcHeader];
        end

        function [ScrambledBBFrame, RawTSBits] = StepTx(obj)
            % Генерация NumPackets пакетов MPEG-TS по 188 байт (1504 бита)
             syncByte = de2bi(hex2dec('47'), 8, 'left-msb').';
            RawTSMatrix = zeros(obj.UPL, obj.NumPackets);
            DataFieldMatrix = zeros(obj.UPL, obj.NumPackets);

            for p = 1:obj.NumPackets
                payload = randi([0 1], obj.UPL - 8, 1); % 1496 информационных бит
                RawTSMatrix(:, p) = [syncByte; payload];
                crcPkt = obj.calcCRC8(payload);
                % В адаптированном потоке CRC-8 предыдущего пакета заменяет синхробайт,
                % а при SYNCD = 0 в конце каждого пакета из 1496 бит записывается его CRC-8:
                DataFieldMatrix(:, p) = [payload; crcPkt];
            end
            RawTSBits = RawTSMatrix(:);
            DataField = DataFieldMatrix(:);

            % Дополнение нулями (Padding) до длины Kbch
            Padding = zeros(obj.Kbch - 80 - obj.DFL, 1);
            BBFrame = [obj.BBHeaderBits; DataField; Padding];

            % BB-скремблирование (побитовое XOR)
            ScrambledBBFrame = double(xor(BBFrame, obj.PRBSSeq));
        end

        function [RxTSBits, PacketErrFlags] = StepRx(obj, RxScrambledBBFrame)
            % 1. BB-дескремблирование
            BBFrame = double(xor(RxScrambledBBFrame(1:obj.Kbch), obj.PRBSSeq));

            % 2. Проверка BBHEADER (первые 80 бит)
            rxHeader = BBFrame(1:80);
            headerCRC = obj.calcCRC8(rxHeader(1:72));
            isHeaderValid = isequal(headerCRC, rxHeader(73:80));

            % Считываем DFL, UPL, SYNC из заголовка (или используем ожидаемые при сбое заголовка)
            if isHeaderValid
                rxUPL  = bi2de(rxHeader(17:32).', 'left-msb');
                rxDFL  = bi2de(rxHeader(33:48).', 'left-msb');
                rxSYNC = rxHeader(49:56);
                if rxDFL > obj.Kbch - 80 || rxUPL ~= 1504
                    isHeaderValid = false;
                end
            end
            
            if ~isHeaderValid
                % Если заголовок повреждён, все пакеты кадра считаются потерянными (ошибочными)
                PacketErrFlags = ones(obj.NumPackets, 1);
                RxTSBits = zeros(obj.UPL * obj.NumPackets, 1);
                return;
            end

            % 3. Выделение DATA FIELD и проверка CRC-8 каждого пакета MPEG-TS
            DataField = BBFrame(81 : 80 + rxDFL);
            numPkts = floor(rxDFL / rxUPL);
            PacketErrFlags = zeros(obj.NumPackets, 1);
            RxTSMatrix = zeros(obj.UPL, obj.NumPackets);

            for p = 1:min(numPkts, obj.NumPackets)
                pktBits = DataField((p-1)*rxUPL + 1 : p*rxUPL);
                payload = pktBits(1 : rxUPL - 8);
                rxCRC   = pktBits(rxUPL - 7 : rxUPL);
                calcCRC = obj.calcCRC8(payload);
                if ~isequal(rxCRC, calcCRC)
                    PacketErrFlags(p) = 1;
                end
                % Восстанавливаем синхробайт 0x47 в начале пакета
                RxTSMatrix(:, p) = [rxSYNC; payload];
            end
            RxTSBits = RxTSMatrix(:);
        end
    end

    methods (Static)
        function crc = calcCRC8(bits)
            % Регистр сдвига с полиномом g(X) = X^8 + X^7 + X^6 + X^4 + X^2 + 1
            r = zeros(8, 1);
            for k = 1:length(bits)
                f = xor(bits(k), r(8));
                r(8) = xor(r(7), f);
                r(7) = xor(r(6), f);
                r(6) = r(5);
                r(5) = xor(r(4), f);
                r(4) = r(3);
                r(3) = xor(r(2), f);
                r(2) = r(1);
                r(1) = f;
            end
            crc = r;
        end
    end
end