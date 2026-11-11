classdef ClassChannel < handle
    properties (SetAccess = private)
        isTransparent;
        LogLanguage;
        Es; % —редн€€ энерги€ модул€ционного символа
    end
    methods
        function obj = ClassChannel(Params, Objs, LogLanguage)
            obj.isTransparent = Params.Channel.isTransparent;
            obj.LogLanguage   = LogLanguage;
            Const  = Objs.Mapper.Constellation;
            obj.Es = mean(abs(Const).^2); % ƒл€ созвездий DVB-S2 равна 1
        end

        function [OutData, InstChannelParams] = Step(obj, InData, EsN0dB)
            if obj.isTransparent
                OutData = InData;
                InstChannelParams.Variance = 1e-10;
                return;
            end
            % —пектральна€ плотность мощности комплексного шума N0 = Es * 10^(-EsN0dB/10)
            N0 = obj.Es * 10^(-EsN0dB / 10);
            Sigma = sqrt(N0 / 2);
            InstChannelParams.Variance = N0;
            Noise = Sigma * (randn(size(InData)) + 1i * randn(size(InData)));
            OutData = InData + Noise;
        end
    end
end