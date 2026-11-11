classdef ClassStat < handle
    properties (SetAccess = private)
        NumTrBits;
        NumTrFrames; % Число переданных MPEG-TS пакетов
        NumErBits;
        NumErFrames; % Число ошибочных MPEG-TS пакетов (для расчёта PER)
        LogLanguage;
    end
    methods
        function obj = ClassStat(LogLanguage)
            obj.NumTrBits   = 0;
            obj.NumTrFrames = 0;
            obj.NumErBits   = 0;
            obj.NumErFrames = 0;
            obj.LogLanguage = LogLanguage;
        end
        function Step(obj, Frame)
            obj.NumTrBits = obj.NumTrBits + length(Frame.TxData);
            obj.NumErBits = obj.NumErBits + sum(Frame.TxData ~= Frame.RxData);
            if isfield(Frame, 'PacketErrFlags')
                obj.NumTrFrames = obj.NumTrFrames + length(Frame.PacketErrFlags);
                obj.NumErFrames = obj.NumErFrames + sum(Frame.PacketErrFlags);
            else
                obj.NumTrFrames = obj.NumTrFrames + 1;
                obj.NumErFrames = obj.NumErFrames + sign(sum(Frame.TxData ~= Frame.RxData));
            end
        end
        function Reset(obj)
            obj.NumTrBits   = 0;
            obj.NumTrFrames = 0;
            obj.NumErBits   = 0;
            obj.NumErFrames = 0;
        end
    end
end