classdef ClassInterleaver < handle
    properties (SetAccess = private)
        isTransparent;
        NumCols;
        ColOrder;
        InvColOrder;
        LogLanguage;
    end
    methods
        function obj = ClassInterleaver(Params, LogLanguage)
            I = Params.Interleaver;
            obj.isTransparent = I.isTransparent;
            obj.LogLanguage   = LogLanguage;
            obj.NumCols       = log2(I.ModulationOrder);

            % Для 8PSK со скоростью 3/5 MSB считывается 3-м: порядок столбцов [3, 1, 2]
            if I.ModulationOrder == 8 && strcmp(I.CodeRate, '3/5')
                obj.ColOrder    = [3, 1, 2];
                obj.InvColOrder = [2, 3, 1];
            else
                obj.ColOrder    = 1:obj.NumCols;
                obj.InvColOrder = 1:obj.NumCols;
            end
        end

        function OutData = StepTx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            numRows = length(InData) / obj.NumCols;
            % Запись по столбцам
            mat = reshape(InData, numRows, obj.NumCols);
            % Перестановка столбцов (если 8PSK 3/5) и чтение по строкам
            mat = mat(:, obj.ColOrder).';
            OutData = mat(:);
        end

        function OutData = StepRx(obj, InData)
            if obj.isTransparent
                OutData = InData;
                return;
            end
            numRows = length(InData) / obj.NumCols;
            % Запись принятых LLR по строкам
            mat = reshape(InData, obj.NumCols, numRows).';
            % Восстановление порядка столбцов и чтение по столбцам
            mat = mat(:, obj.InvColOrder);
            OutData = mat(:);
        end
    end
end