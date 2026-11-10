classdef ClassMapper < handle
    properties (SetAccess = private)
        isTransparent;
        Type;
        ModulationOrder;
        CodeRate;
        DecisionMethod;
        LogLanguage;
        Constellation;
        Bits;
        log2M;
    end
    methods
        function obj = ClassMapper(Params, LogLanguage)
            M = Params.Mapper;
            obj.isTransparent   = M.isTransparent;
            obj.Type            = M.Type;
            obj.ModulationOrder = M.ModulationOrder;
            obj.CodeRate        = M.CodeRate;
            obj.DecisionMethod  = M.DecisionMethod;
            obj.LogLanguage     = LogLanguage;
            obj.log2M           = log2(M.ModulationOrder);

            % Формирование эталонного созвездия DVB-S2 для всех 2^m комбинаций бит
            obj.Bits = de2bi(0:obj.ModulationOrder-1, obj.log2M, 'left-msb').';
            obj.Constellation = obj.StepTx(obj.Bits(:));
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            switch obj.Type
                case 'QPSK'
                    % Разметка DVB-S2 QPSK: 00->exp(j*pi/4), 01->exp(-j*pi/4), 10->exp(j*3pi/4), 11->exp(-j*3pi/4)
                    b = reshape(InData, 2, []);
                    I = (1 - 2*b(1,:)) / sqrt(2);
                    Q = (1 - 2*b(2,:)) / sqrt(2);
                    OutData = (I + 1i*Q).';
                case '8PSK'
                    % Разметка DVB-S2 8PSK по созвездию стандарта
                     lut = exp(1i * pi/4 * [1; 0; 4; 5; 2; 7; 3; 6]);
                    b = reshape(InData, 3, []).';
                    idx = bi2de(b, 'left-msb') + 1;
                    OutData = lut(idx);
                case {'16APSK', '32APSK'}
                    OutData = dvbsapskmod(InData, obj.ModulationOrder, 's2', ...
                        obj.CodeRate, 'InputType', 'bit', 'UnitAveragePower', true);
            end
        end

        function OutData = StepRx(obj, InData, InstChannelParams)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            N0 = max(InstChannelParams.Variance, 1e-10);
            if strcmp(obj.Type, '16APSK') || strcmp(obj.Type, '32APSK')
                OutData = dvbsapskdemod(InData, obj.ModulationOrder, 's2', ...
                    obj.CodeRate, 'OutputType', 'approxllr', ...
                    'NoiseVariance', N0, 'UnitAveragePower', true);
            else
                % Max-Log-MAP (Approximate LLR) демодулятор для произвольного созвездия (QPSK / 8PSK):
                % L(b_m) = (min_{s: b_m=1} |r - s|^2 - min_{s: b_m=0} |r - s|^2) / N0
                numSym = length(InData);
                distSq = abs(InData(:) - obj.Constellation(:).').^2; % [numSym x M]
                LLR = zeros(obj.log2M, numSym);
                for m = 1:obj.log2M
                    mask0 = (obj.Bits(m, :) == 0);
                    mask1 = ~mask0;
                    d0 = min(distSq(:, mask0), [], 2);
                    d1 = min(distSq(:, mask1), [], 2);
                    LLR(m, :) = ((d1 - d0) / N0).';
                end
                OutData = LLR(:);
            end
        end
    end
end